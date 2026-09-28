#!/usr/bin/env python3
"""Generate lightweight, kid-friendly planetary ambience locally.

These are stylized educational sound-design beds, not literal recordings of
sound traveling through space. NASA uses sonification to translate otherwise
inaudible space data into sound.

Usage:
  python3 tool/generate_planet_sfx.py
  python3 tool/generate_planet_sfx.py --only earth
  python3 tool/generate_planet_sfx.py --only sun --force
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/audio/sfx/planets"
SAMPLE_RATE = 24_000
DURATION = 4.0
COUNT = int(SAMPLE_RATE * DURATION)

# Base frequency, harmonic, noise level, pulse/modulation character.
PROFILES = {
    "sun": (52, 0.38, 0.12, 0.18),
    "mercury": (150, 0.18, 0.05, 0.10),
    "venus": (68, 0.32, 0.10, 0.12),
    "earth": (108, 0.20, 0.08, 0.22),
    "mars": (76, 0.28, 0.12, 0.14),
    "jupiter": (42, 0.48, 0.16, 0.10),
    "saturn": (72, 0.25, 0.06, 0.30),
    "uranus": (118, 0.18, 0.08, 0.24),
    "neptune": (48, 0.34, 0.15, 0.16),
    "moon": (92, 0.16, 0.04, 0.10),
    "phobos": (130, 0.14, 0.08, 0.08),
    "deimos": (118, 0.13, 0.07, 0.08),
    "io": (82, 0.40, 0.14, 0.28),
    "europa": (164, 0.16, 0.05, 0.34),
    "ganymede": (64, 0.30, 0.06, 0.18),
    "callisto": (55, 0.24, 0.12, 0.08),
    "titan": (61, 0.34, 0.13, 0.12),
    "enceladus": (190, 0.12, 0.04, 0.38),
    "mimas": (145, 0.13, 0.05, 0.16),
    "tethys": (125, 0.14, 0.04, 0.25),
    "iapetus": (58, 0.22, 0.09, 0.06),
    "miranda": (172, 0.12, 0.06, 0.30),
    "ariel": (142, 0.14, 0.05, 0.26),
    "umbriel": (70, 0.22, 0.08, 0.07),
    "titania": (105, 0.17, 0.06, 0.18),
    "oberon": (62, 0.20, 0.08, 0.07),
    "triton": (88, 0.24, 0.09, 0.20),
}


def sample(body: str, t: float) -> float:
    base, harmonic, noise, motion = PROFILES[body]
    phase = 2.0 * math.pi * base * t

    # Low harmonic bed.
    value = math.sin(phase) * 0.55
    value += math.sin(phase * 2.01 + 0.7) * harmonic
    value += math.sin(phase * 3.97 + 1.9) * harmonic * 0.35

    # Slow movement makes the loop feel alive without sounding like music.
    lfo = 0.65 + 0.35 * math.sin(2.0 * math.pi * motion * t + 1.1)
    value *= lfo

    # Deterministic pseudo-noise made from incommensurate tones, so the loop
    # remains seamless and does not require random sample discontinuities.
    noise_wave = (
        math.sin(2.0 * math.pi * 37.0 * t + 0.3)
        + math.sin(2.0 * math.pi * 53.0 * t + 2.0)
        + math.sin(2.0 * math.pi * 71.0 * t + 4.1)
    ) / 3.0
    value += noise_wave * noise

    # Sun/Io get a little extra turbulent shimmer.
    if body in {"sun", "io"}:
        burst = max(0.0, math.sin(2.0 * math.pi * 0.8 * t))
        value += math.sin(2.0 * math.pi * (base * 5.2) * t) * 0.06 * burst

    # Fade only the first/last 80 ms to make asset looping click-free.
    edge = min(t / 0.08, (DURATION - t) / 0.08, 1.0)
    return max(-1.0, min(1.0, value * 0.42 * edge))


def write_wav(body: str, force: bool) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / f"{body}.wav"
    if path.exists() and not force:
        print(f"skip   {path.relative_to(ROOT)}")
        return

    with wave.open(str(path), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(SAMPLE_RATE)

        frames = bytearray()
        for i in range(COUNT):
            t = i / SAMPLE_RATE
            value = int(sample(body, t) * 32767)
            frames.extend(struct.pack("<h", value))

        audio.writeframes(frames)

    print(f"create {path.relative_to(ROOT)}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", action="append", help="Body id; repeatable.")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    selected = args.only or list(PROFILES)
    unknown = sorted(set(selected) - PROFILES.keys())
    if unknown:
        parser.error("Unknown body id(s): " + ", ".join(unknown))

    for body in selected:
        write_wav(body, args.force)

    print(f"Processed {len(selected)} planetary sound assets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
