#!/usr/bin/env python3
"""Generate bundled neural narration with Kokoro, entirely locally.

No cloud TTS API or API key is required. The script reads narration copy from
the Flutter planet catalog and generates MP3 assets for the app.

Setup on macOS:
  brew install espeak-ng ffmpeg
  python3 -m venv .venv-kokoro
  source .venv-kokoro/bin/activate
  pip install "kokoro>=0.9.4" soundfile

Apple Silicon:
  export PYTORCH_ENABLE_MPS_FALLBACK=1

Then:
  python3 tool/generate_neural_narration.py --only saturn
  python3 tool/generate_neural_narration.py

The default voice is Kokoro's American English "af_heart".
Override it with KOKORO_VOICE, for example af_sarah or am_michael.
"""

from __future__ import annotations

import argparse
import ast
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
# The runnable app is the only package that bundles assets; the catalogue
# belongs to the planets package.
ASSETS = ROOT / "apps/kidz_planets/assets"
CATALOG_SRC = ROOT / "packages/planets/lib/src/data/planet_catalog.dart"
CATALOG = CATALOG_SRC
PLANET_OUTPUT = ASSETS / "audio/narration/planets"
HOTSPOT_OUTPUT = ASSETS / "audio/narration/hotspots"

STRING = r"'(?:\\.|[^'\\])*'"
STRING_GROUP = rf"((?:{STRING}\s*)+)"


def decode_dart_strings(group: str) -> str:
    fragments = re.findall(STRING, group)
    return "".join(ast.literal_eval(fragment) for fragment in fragments)


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")


def extract_narration(block: str) -> str | None:
    # A planet's narration is followed by a comma because `hotspots:` comes next,
    # while a hotspot's narration is the last argument and is closed by `)`.
    match = re.search(
        rf"narration:\s*{STRING_GROUP}\s*[,)]",
        block,
        re.DOTALL,
    )
    if not match:
        return None
    return decode_dart_strings(match.group(1)).strip()


def extract_catalog() -> list[tuple[str, str, str]]:
    source = CATALOG.read_text(encoding="utf-8")
    blocks = re.split(r"\n    Planet\(", source)[1:]

    items: list[tuple[str, str, str]] = []
    for block in blocks:
        id_match = re.search(r"id:\s*'([^']+)'", block)
        if not id_match:
            continue

        planet_id = id_match.group(1)
        planet_narration = extract_narration(block)
        if planet_narration:
            items.append(("planet", planet_id, planet_narration))

        for hotspot in re.split(r"Hotspot\(", block)[1:]:
            title_match = re.search(rf"title:\s*({STRING})", hotspot)
            if not title_match:
                continue

            title = ast.literal_eval(title_match.group(1))
            narration = extract_narration(hotspot)
            if narration:
                items.append(("hotspot", slugify(title), narration))

    return items


def generate_audio(pipeline, text: str, voice: str, output_path: Path) -> None:
    import soundfile as sf

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="kidz-planets-tts-") as temp_dir:
        wav_path = Path(temp_dir) / "narration.wav"

        chunks = []
        for _, _, audio in pipeline(text, voice=voice):
            chunks.append(audio)

        if not chunks:
            raise RuntimeError("Kokoro produced no audio.")

        import numpy as np

        audio = np.concatenate(chunks)
        sf.write(wav_path, audio, 24000)

        ffmpeg = shutil.which("ffmpeg")
        if ffmpeg is None:
            raise RuntimeError(
                "ffmpeg is required to create MP3 assets. "
                "Install it with: brew install ffmpeg"
            )

        subprocess.run(
            [
                ffmpeg,
                "-y",
                "-loglevel",
                "error",
                "-i",
                str(wav_path),
                "-codec:a",
                "libmp3lame",
                "-q:a",
                "4",
                str(output_path),
            ],
            check=True,
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--only",
        action="append",
        help="Generate only this planet id or hotspot slug. Repeat the option.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerate files that already exist.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List files without loading Kokoro or generating audio.",
    )
    parser.add_argument(
        "--voice",
        default=None,
        help="Kokoro voice. Defaults to KOKORO_VOICE or af_heart.",
    )
    args = parser.parse_args()

    if not CATALOG.exists():
        print(f"Catalog not found: {CATALOG}", file=sys.stderr)
        return 1

    items = extract_catalog()
    selected = set(args.only or [])
    if selected:
        items = [item for item in items if item[1] in selected]

    if not items:
        print("No narration entries selected.", file=sys.stderr)
        return 1

    voice = args.voice or __import__("os").environ.get("KOKORO_VOICE", "af_heart")

    if args.dry_run:
        for kind, key, _ in items:
            folder = PLANET_OUTPUT if kind == "planet" else HOTSPOT_OUTPUT
            print(folder.joinpath(f"{key}.mp3").relative_to(ROOT))
        return 0

    try:
        from kokoro import KPipeline
    except ImportError:
        print(
            'Kokoro is not installed. Run: pip install "kokoro>=0.9.4" soundfile',
            file=sys.stderr,
        )
        return 2

    language = voice[0]
    if language not in {"a", "b"}:
        raise SystemExit(
            f"Unsupported English voice '{voice}'. Use an American 'af_*' or "
            "British 'bf_*' voice."
        )

    print(f"Loading Kokoro voice: {voice}")
    pipeline = KPipeline(lang_code=language)

    for kind, key, narration in items:
        output_dir = PLANET_OUTPUT if kind == "planet" else HOTSPOT_OUTPUT
        output_path = output_dir / f"{key}.mp3"

        if output_path.exists() and not args.force:
            print(f"skip   {output_path.relative_to(ROOT)}")
            continue

        print(f"create {output_path.relative_to(ROOT)}")
        generate_audio(pipeline, narration, voice, output_path)

    print(f"Processed {len(items)} narration entries with Kokoro.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
