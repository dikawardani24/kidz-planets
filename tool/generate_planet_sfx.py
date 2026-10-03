#!/usr/bin/env python3
"""Generate lightweight, kid-friendly planetary ambience locally.

These are stylized educational sound-design beds, not literal recordings of
sound traveling through space. NASA uses sonification to translate otherwise
inaudible space data into sound.

Usage:
  python3 tool/generate_planet_sfx.py   # needs ffmpeg on PATH
  python3 tool/generate_planet_sfx.py --only earth
  python3 tool/generate_planet_sfx.py --only sun --force
"""

from __future__ import annotations

import argparse
import math
import random
import shutil
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# The runnable app is the only package that bundles assets.
ASSETS = ROOT / "apps/kidz_planets/assets"
OUTPUT = ASSETS / "audio/sfx/planets"
SAMPLE_RATE = 24_000
DURATION = 4.0
COUNT = int(SAMPLE_RATE * DURATION)
# A bed is a smooth loop, so the encoder only has to preserve its shape. The
# whole 27-bed set lands near 1 MB at this rate instead of the ~5 MB the same
# beds take as WAV.
BITRATE_KBPS = 40

# Base frequency, harmonic, noise level, pulse/modulation character.
# Frequencies are spread wide on purpose: phone/laptop speakers barely
# reproduce anything under ~150 Hz, so bodies that all rumble at 40-90 Hz
# sound identical. Giants keep the low rumble; small/icy bodies sit an
# octave or more higher with their own shimmer so switching detail is
# clearly audible.
PROFILES = {
    "sun": (55, 0.42, 0.14, 0.18),
    "mercury": (220, 0.15, 0.05, 0.12),
    "venus": (110, 0.30, 0.10, 0.12),
    "earth": (147, 0.22, 0.08, 0.22),
    "mars": (98, 0.28, 0.12, 0.14),
    "jupiter": (65, 0.45, 0.16, 0.10),
    "saturn": (130, 0.25, 0.06, 0.30),
    "uranus": (175, 0.18, 0.08, 0.24),
    "neptune": (82, 0.32, 0.15, 0.16),
    "moon": (196, 0.14, 0.05, 0.10),
    "phobos": (262, 0.12, 0.08, 0.08),
    "deimos": (233, 0.12, 0.07, 0.08),
    "io": (124, 0.38, 0.14, 0.28),
    "europa": (294, 0.16, 0.05, 0.34),
    "ganymede": (104, 0.28, 0.06, 0.18),
    "callisto": (87, 0.24, 0.12, 0.08),
    "titan": (92, 0.32, 0.13, 0.12),
    "enceladus": (330, 0.12, 0.04, 0.38),
    "mimas": (247, 0.13, 0.05, 0.16),
    "tethys": (208, 0.14, 0.04, 0.25),
    "iapetus": (73, 0.22, 0.09, 0.06),
    "miranda": (311, 0.12, 0.06, 0.30),
    "ariel": (233, 0.14, 0.05, 0.26),
    "umbriel": (110, 0.22, 0.08, 0.07),
    "titania": (165, 0.17, 0.06, 0.18),
    "oberon": (98, 0.20, 0.08, 0.07),
    "triton": (140, 0.24, 0.09, 0.20),
}

# Bright icy shimmer an octave-plus up, so ice worlds read clearly
# different from rocky rumbles on small speakers.
ICY_SHIMMER = {"europa", "enceladus", "miranda", "ariel", "tethys", "triton"}

# Master level for the generated bed.
#
# The narration in `assets/audio/narration` averages about -25 dBFS RMS and the
# app plays it at 0.92 while it plays a bed at 0.42, so the voice arrives at
# about -26 dBFS. This scale puts a bed near -22 dBFS, which at 0.42 lands
# around -30 dBFS: audible as a bed under the voice without competing with it.
#
# Two earlier scales were both wrong. The original 0.42 put Jupiter's bed at
# -15 to -19 dBFS, about 4 dB *louder* than the narration playing over it. Then
# 0.08 overcorrected to -32 dBFS, which at 0.42 is -39 dBFS effective, some
# 27 dB under a normal listening level: effectively silent on a phone speaker.
LEVEL_SCALE = 0.24


def cycles(rate: float) -> float:
    """Snap a modulation rate to a whole number of cycles per loop.

    At least one cycle, so a very slow rate cannot snap to a standstill and turn
    the movement into a constant offset.
    """
    return max(1, round(rate * DURATION)) / DURATION


def sample(body: str, t: float) -> float:
    base, harmonic, noise, motion = PROFILES[body]
    phase = 2.0 * math.pi * base * t

    # Low harmonic bed.
    value = math.sin(phase) * 0.55
    # Every multiplier here is a whole number on purpose. The bed loops under
    # narration for as long as a child stays on a body, so the waveform has to
    # come back to where it started after exactly DURATION: a partial that does
    # not divide the loop lands on a different phase each repeat and the seam
    # ticks. Whole harmonics cost a little of the "detuned" character and buy a
    # loop nobody can hear the join in.
    value += math.sin(phase * 2.0 + 0.7) * harmonic
    value += math.sin(phase * 4.0 + 1.9) * harmonic * 0.35

    # Slow movement makes the loop feel alive without sounding like music. The
    # rate is snapped to whole cycles per loop for the same reason as above.
    lfo = 0.65 + 0.35 * math.sin(2.0 * math.pi * cycles(motion) * t + 1.1)
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
        burst = max(0.0, math.sin(2.0 * math.pi * cycles(0.8) * t))
        value += math.sin(2.0 * math.pi * (base * 5) * t) * 0.06 * burst

    # Icy worlds get a bright high shimmer so they read clearly different
    # from rocky rumbles on small speakers.
    if body in ICY_SHIMMER:
        value += math.sin(2.0 * math.pi * (base * 2) * t + 0.9) * 0.10
        value += math.sin(2.0 * math.pi * (base * 3) * t + 2.2) * 0.05

    # Fade only the first/last 80 ms so a player that does not loop seamlessly
    # anyway cannot click.
    edge = min(t / 0.08, (DURATION - t) / 0.08, 1.0)
    return max(-1.0, min(1.0, value * LEVEL_SCALE * edge))


def render_pcm(body: str) -> bytes:
    frames = bytearray()
    for i in range(COUNT):
        t = i / SAMPLE_RATE
        value = int(sample(body, t) * 32767)
        frames.extend(struct.pack("<h", value))
    return bytes(frames)


def write_bed(body: str, force: bool) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / f"{body}.mp3"
    if path.exists() and not force:
        print(f"skip   {path.relative_to(ROOT)}")
        return

    # Synthesised straight to MP3 to match the mission cues, the narration and
    # the avatar cues, which are all MP3 too. The PCM exists only as ffmpeg's
    # input: shipping it as WAV instead costs about 4 MB across 27 beds for no
    # benefit a player can hear.
    with tempfile.TemporaryDirectory() as scratch:
        wav_path = Path(scratch) / f"{body}.wav"
        with wave.open(str(wav_path), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(SAMPLE_RATE)
            audio.writeframes(render_pcm(body))

        subprocess.run(
            [
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-i", str(wav_path),
                "-c:a", "libmp3lame",
                "-b:a", f"{BITRATE_KBPS}k",
                # 24 kHz is an MPEG-2 rate, so the header has to say MPEG-2 for
                # a player to read the sample rate back correctly.
                "-write_xing", "0",
                # No ID3 tag, matching the other generators. ffmpeg's default
                # TSSE tag declares a size that does not match the bytes
                # actually written, which misaligns the first MPEG frame for a
                # player that honours the declared size.
                "-id3v2_version", "0",
                "-map_metadata", "-1",
                str(path),
            ],
            check=True,
        )

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

    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required to encode the MP3s")

    for body in selected:
        write_bed(body, args.force)

    print(f"Processed {len(selected)} planetary sound assets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
