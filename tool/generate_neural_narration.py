#!/usr/bin/env python3
"""Generate bundled neural narration MP3s for Kidz Planets.

The script reads the narration copy directly from the Flutter planet catalog so
there is one source of truth for spoken content. It writes MP3 assets into
assets/audio/narration/planets and assets/audio/narration/hotspots.

Required environment variables:
  ELEVENLABS_API_KEY
  ELEVENLABS_VOICE_ID

Optional:
  ELEVENLABS_MODEL (default: eleven_multilingual_v2)

Example:
  ELEVENLABS_API_KEY=... ELEVENLABS_VOICE_ID=... \
    python3 tool/generate_neural_narration.py

Generate only Saturn:
  ... python3 tool/generate_neural_narration.py --only saturn

Preview what would be generated:
  ... python3 tool/generate_neural_narration.py --dry-run
"""

from __future__ import annotations

import argparse
import ast
import os
from pathlib import Path
import re
import sys
from urllib import error, request
import json


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "lib/data/datasources/planet_catalog.dart"
PLANET_OUTPUT = ROOT / "assets/audio/narration/planets"
HOTSPOT_OUTPUT = ROOT / "assets/audio/narration/hotspots"

STRING = r"'(?:\\.|[^'\\])*'"
STRING_GROUP = rf"((?:{STRING}\s*)+)"


def decode_dart_strings(group: str) -> str:
    fragments = re.findall(STRING, group)
    return "".join(ast.literal_eval(fragment) for fragment in fragments)


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")


def extract_narration(block: str, start: int = 0) -> str | None:
    match = re.search(rf"narration:\s*{STRING_GROUP}\s*,", block[start:], re.DOTALL)
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
            title_match = re.search(rf"title:\s*({STRING})", hotspot, re.DOTALL)
            if not title_match:
                continue

            title = ast.literal_eval(title_match.group(1))
            narration = extract_narration(hotspot)
            if narration:
                items.append(("hotspot", slugify(title), narration))

    return items


def generate_audio(
    *,
    api_key: str,
    voice_id: str,
    model_id: str,
    text: str,
) -> bytes:
    url = (
        f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
        "?output_format=mp3_44100_128"
    )

    payload = json.dumps(
        {
            "text": text,
            "model_id": model_id,
            "voice_settings": {
                "stability": 0.45,
                "similarity_boost": 0.75,
                "style": 0.15,
                "use_speaker_boost": True,
                "speed": 0.96,
            },
        }
    ).encode("utf-8")

    req = request.Request(
        url,
        data=payload,
        method="POST",
        headers={
            "xi-api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
    )

    try:
        with request.urlopen(req, timeout=120) as response:
            return response.read()
    except error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"ElevenLabs returned HTTP {exc.code}: {details}"
        ) from exc


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
        help="List generated files without calling ElevenLabs.",
    )
    args = parser.parse_args()

    if not CATALOG.exists():
        print(f"Catalog not found: {CATALOG}", file=sys.stderr)
        return 1

    items = extract_catalog()
    if not items:
        print("No narration entries were found in the planet catalog.", file=sys.stderr)
        return 1

    selected = set(args.only or [])
    if selected:
        items = [item for item in items if item[1] in selected]

    if not args.dry_run:
        api_key = os.getenv("ELEVENLABS_API_KEY")
        voice_id = os.getenv("ELEVENLABS_VOICE_ID")
        if not api_key or not voice_id:
            print(
                "Set ELEVENLABS_API_KEY and ELEVENLABS_VOICE_ID before generating audio.",
                file=sys.stderr,
            )
            return 2
    else:
        api_key = voice_id = None

    model_id = os.getenv("ELEVENLABS_MODEL", "eleven_multilingual_v2")

    for kind, key, narration in items:
        output_dir = PLANET_OUTPUT if kind == "planet" else HOTSPOT_OUTPUT
        output_path = output_dir / f"{key}.mp3"

        if output_path.exists() and not args.force:
            print(f"skip   {output_path.relative_to(ROOT)}")
            continue

        print(f"create {output_path.relative_to(ROOT)}")
        if args.dry_run:
            continue

        output_dir.mkdir(parents=True, exist_ok=True)
        audio = generate_audio(
            api_key=api_key,
            voice_id=voice_id,
            model_id=model_id,
            text=narration,
        )
        output_path.write_bytes(audio)

    print(f"Processed {len(items)} narration entries.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
