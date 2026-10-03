#!/usr/bin/env python3
"""Rewrite a GLB that uses EXT_texture_webp so it uses core glTF JPEG/PNG.

The flutter_scene importer refuses any file whose `extensionsRequired` names an
extension it cannot parse, and EXT_texture_webp is not one of them. Exporter
chains such as trimesh emit WebP textures by default, so a perfectly good model
is rejected at build time with:

    FormatException: glTF requires unsupported extension(s): EXT_texture_webp

Dropping the extension without transcoding the payload would leave textures
pointing at bytes nothing can decode, so this script transcodes each WebP image
to a core glTF image instead. Alpha survives as PNG only where it can change the
render: a base color texture sampled by a material whose alphaMode is not OPAQUE
(glTF ignores base color alpha for OPAQUE materials). Every other image becomes
4:4:4 JPEG, which is both smaller and closer to the original lossy WebP. Pass
--keep-alpha to always preserve alpha, --max-size to downscale oversized maps.
Geometry, UVs and materials are never touched.

Usage:
  tool/convert_glb_webp_textures.py <input.glb> <output.glb>
  tool/convert_glb_webp_textures.py --in-place <model.glb>

Requires ImageMagick (`magick`) on PATH. Idempotent: a GLB without WebP images
is copied through unchanged.
"""

from __future__ import annotations

import argparse
import base64
import json
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

WEBP_EXTENSION = "EXT_texture_webp"
GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
ALIGN = 4


class ConversionError(RuntimeError):
    pass


def _run(*args: str) -> None:
    subprocess.run(args, check=True, capture_output=True)


def _has_alpha(path: Path) -> bool:
    result = subprocess.run(
        ["magick", "identify", "-format", "%[channels]", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return "a" in result.stdout.strip().lower().replace("srgb", "")


def _transcode(
    src: Path, *, keep_alpha: bool, max_size: int | None
) -> tuple[str, bytes]:
    """Transcode a WebP payload to a core glTF image, returning (mime, bytes)."""
    dst = src.with_suffix(".png" if keep_alpha else ".jpg")
    command = ["magick", str(src)]
    if max_size is not None:
        # Filters that keep a downscaled atlas readable rather than point-sampled.
        command += ["-filter", "Lanczos", "-resize", f"{max_size}x{max_size}>"]
    if keep_alpha:
        # -define png:compression-level=9 keeps the file small without the
        # palette quantization that would band smooth gradients.
        command += ["-strip", "-define", "png:compression-level=9", str(dst)]
        mime = "image/png"
    else:
        # 4:4:4 sampling keeps chroma detail in packed metallic-roughness maps,
        # which JPEG would otherwise smear at 2x2 subsampling.
        command += [
            "-strip",
            "-quality",
            "95",
            "-sampling-factor",
            "1x1",
            "-define",
            "jpeg:dct-method=float",
            str(dst),
        ]
        mime = "image/jpeg"
    _run(*command)
    return mime, dst.read_bytes()


def _alpha_matters(document: dict) -> set[int]:
    """Image indices whose alpha can change the rendered result.

    glTF ignores the base color alpha channel when a material's alphaMode is
    OPAQUE, so for such a material an alpha-carrying WebP can safely become an
    RGB JPEG. BLEND and MASK materials do read that alpha, and no other texture
    slot uses it, so anything they sample has to stay a PNG.
    """
    indices: set[int] = set()
    textures = document.get("textures", [])
    for material in document.get("materials", []):
        if material.get("alphaMode", "OPAQUE") == "OPAQUE":
            continue
        info = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if info is None:
            continue
        texture = textures[info["index"]]
        source = texture.get("source")
        if source is None:
            source = texture.get("extensions", {}).get(WEBP_EXTENSION, {}).get("source")
        if source is not None:
            indices.add(source)
    return indices



def _image_payload(image: dict, base_dir: Path) -> bytes:
    if "bufferView" in image:
        return image.pop("_bytes")
    uri = image.get("uri")
    if uri is None:
        raise ConversionError("image has neither bufferView nor uri")
    if uri.startswith("data:"):
        _, _, data = uri.partition(",")
        return base64.b64decode(data)
    return (base_dir / uri).read_bytes()


def convert(
    src: Path,
    dst: Path,
    *,
    in_place: bool,
    keep_alpha: bool = False,
    max_size: int | None = None,
) -> bool:
    raw = src.read_bytes()
    magic, version, total = struct.unpack_from("<III", raw, 0)
    if magic != GLB_MAGIC or version != 2:
        raise ConversionError(f"{src} is not a glTF 2.0 binary")

    chunks: list[tuple[int, bytes]] = []
    offset = 12
    while offset < total:
        length, kind = struct.unpack_from("<II", raw, offset)
        chunks.append((kind, raw[offset + 8 : offset + 8 + length]))
        offset += 8 + length

    document = json.loads(chunks[0][1].decode("utf-8"))
    bin_data = chunks[1][1] if len(chunks) > 1 else b""

    views = document.get("bufferViews", [])
    for image in document.get("images", []):
        view_index = image.get("bufferView")
        if view_index is None:
            continue
        view = views[view_index]
        image["_bytes"] = bin_data[
            view.get("byteOffset", 0) : view.get("byteOffset", 0) + view["byteLength"]
        ]

    webp_images = {
        index
        for index, image in enumerate(document.get("images", []))
        if image.get("mimeType") == "image/webp"
    }
    if not webp_images:
        shutil.copyfile(src, src if in_place else dst)
        print(f"{src}: no WebP images, copied unchanged")
        return False

    # Only bufferView-backed WebP payloads occupy space in the BIN chunk that has
    # to be released; URI-backed ones are appended as new views below.
    webp_views = {
        image["bufferView"]
        for image in (document["images"][index] for index in webp_images)
        if "bufferView" in image
    }

    alpha_required = _alpha_matters(document)

    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = Path(tmp)
        transcoded: dict[int, tuple[str, bytes]] = {}
        for index in sorted(webp_images):
            image = document["images"][index]
            webp_path = tmp_dir / f"image-{index}.webp"
            webp_path.write_bytes(_image_payload(image, src.parent))
            needed = index in alpha_required or (keep_alpha and _has_alpha(webp_path))
            transcoded[index] = _transcode(
                webp_path, keep_alpha=needed, max_size=max_size
            )

    # Point each texture at the transcoded image through the core `source`
    # field, then drop the now-empty extension objects.
    for texture in document.get("textures", []):
        extensions = texture.get("extensions")
        if not extensions or WEBP_EXTENSION not in extensions:
            continue
        source = extensions[WEBP_EXTENSION]["source"]
        texture.clear()
        texture["source"] = source
        for key, value in extensions.items():
            if key != WEBP_EXTENSION:
                texture[key] = value

    # Repack the BIN chunk: every surviving bufferView keeps its bytes (with
    # fresh 4-byte aligned offsets) and the transcoded images are appended, so
    # the dropped WebP payloads stop costing file size.
    remap: dict[int, int] = {}
    new_views: list[dict] = []
    new_bin = bytearray()
    for index, view in enumerate(views):
        if index in webp_views:
            continue
        view_bytes = bin_data[
            view.get("byteOffset", 0) : view.get("byteOffset", 0) + view["byteLength"]
        ]
        remap[index] = len(new_views)
        while len(new_bin) % ALIGN != 0:
            new_bin.append(0)
        new_views.append(
            {
                **{k: v for k, v in view.items() if k not in ("byteOffset", "byteLength")},
                "byteOffset": len(new_bin),
                "byteLength": len(view_bytes),
            }
        )
        new_bin.extend(view_bytes)

    for index in sorted(webp_images):
        mime, payload = transcoded[index]
        image = document["images"][index]
        while len(new_bin) % ALIGN != 0:
            new_bin.append(0)
        remap_index = len(new_views)
        new_views.append({"buffer": 0, "byteOffset": len(new_bin), "byteLength": len(payload)})
        new_bin.extend(payload)
        image.pop("_bytes", None)
        image.pop("uri", None)
        image["mimeType"] = mime
        image["bufferView"] = remap_index

    for accessor in document.get("accessors", []):
        if "bufferView" in accessor:
            accessor["bufferView"] = remap[accessor["bufferView"]]

    for key in ("extensionsUsed", "extensionsRequired"):
        if key in document:
            remaining = [name for name in document[key] if name != WEBP_EXTENSION]
            if remaining:
                document[key] = remaining
            else:
                del document[key]

    while len(new_bin) % ALIGN != 0:
        new_bin.append(0)
    for buffer in document.get("buffers", []):
        buffer["byteLength"] = len(new_bin)
    document["bufferViews"] = new_views

    json_bytes = json.dumps(document, separators=(",", ":")).encode("utf-8")
    while len(json_bytes) % ALIGN != 0:
        json_bytes += b" "

    glb = bytearray()
    glb.extend(struct.pack("<III", GLB_MAGIC, 2, 12 + 8 + len(json_bytes) + 8 + len(new_bin)))
    glb.extend(struct.pack("<II", len(json_bytes), JSON_CHUNK))
    glb.extend(json_bytes)
    glb.extend(struct.pack("<II", len(new_bin), BIN_CHUNK))
    glb.extend(new_bin)

    target = src if in_place else dst
    target.write_bytes(glb)
    saved = len(raw) - len(glb)
    print(
        f"{src}: transcoded {len(transcoded)} WebP image(s) "
        f"({', '.join(mime for mime, _ in transcoded.values())}) -> {target} "
        f"({len(glb)} bytes, {saved:+d})"
    )
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="GLB file to convert")
    parser.add_argument("output", type=Path, nargs="?", help="GLB file to write")
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="overwrite the input file instead of writing a separate output",
    )
    parser.add_argument(
        "--keep-alpha",
        action="store_true",
        help="always keep alpha (PNG), even for materials that ignore it",
    )
    parser.add_argument(
        "--max-size",
        type=int,
        default=None,
        metavar="PIXELS",
        help="downscale textures wider or taller than PIXELS (e.g. 1024)",
    )
    args = parser.parse_args()

    if not args.in_place and args.output is None:
        parser.error("give an output path or pass --in-place")

    convert(
        args.input,
        args.output,
        in_place=args.in_place,
        keep_alpha=args.keep_alpha,
        max_size=args.max_size,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
