#!/usr/bin/env python3
"""Generate the companion's bounce sound locally.

The throw system needs exactly one new sound: a soft, short impact for when the
toy hits a wall. It is synthesized here rather than sourced externally so the
asset carries no third-party licence into the app, and so it can be
regenerated deterministically if the throw tuning changes.

The sound is a damped downward pitch sweep (a rubber toy, not a drum) with a
very small filtered-noise transient for the contact itself. The sweep is
downward because a real bounce compresses and rebounds: pitch rising with
speed reads as a squeak, pitch falling reads as a soft knock.

One asset serves every impact. Louder hits are handled by playback volume in
`AvatarImpactSound.volumeForImpact`, so there is no need for a bank of
intensities, and a single timbre keeps the toy sounding like the same object at
every speed.

Usage:
  python3 tool/generate_avatar_bounce_sfx.py
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
OUTPUT = ASSETS / "audio/sfx/avatar/avatar_bounce.mp3"

# 24 kHz matches the narration and the planetary beds, and is one of the rates
# MPEG-2 defines, so the file needs no resampling and the existing asset tests
# cover it without a special case.
SAMPLE_RATE = 24_000

# Short on purpose. The cooldown between impacts is 70 ms, so anything much
# longer than that would still be ringing when the next bounce arrives and the
# rapid bounces of a fast throw would smear into a continuous buzz.
DURATION_SECONDS = 0.18

# Mono, because an impact is a point source in the middle of the screen and a
# stereo cue would imply the wall is to one side. 96 kbps is ample for a
# 0.18 s mono tone and is the same rate the short mission cue ships at.
BITRATE_KBPS = 96
CHANNELS = 1

# The pitch sweep, from the moment of contact to the end of the sound. A short
# drop is what makes it read as a knock on a soft object.
START_HZ = 420.0
END_HZ = 190.0

# How much of a harmonic stack to use. A pure sine is a beep; the second
# harmonic is what gives the toy a body, and the third is kept low so the tone
# stays round rather than reedy.
HARMONICS = ((1.0, 1.0), (2.0, 0.28), (3.0, 0.10), (4.0, 0.04))

# The contact transient, as a fraction of the total length. Short enough to read
# as the tap of contact rather than as a separate hiss.
TRANSIENT_FRACTION = 0.18
TRANSIENT_GAIN = 0.22

# A fast decay, so the sound stops rather than ringing on.
DECAY_PER_SECOND = 13.0

# Headroom below full scale. The playback volume is already scaled per impact,
# and a normalized-then-shaped file has nowhere left for the encoder to work.
PEAK = 0.82


def _envelope(t: float) -> float:
    """Attack fast, decay exponentially.

    The attack is a fraction of a millisecond: a contact has no slow onset, and
    an audible ramp up would sound like the toy winding up.
    """
    attack = 0.0025
    if t < attack:
        return t / attack
    return math.exp(-DECAY_PER_SECOND * (t - attack))


def _synthesize(seed: int) -> list[int]:
    """Renders the bounce as 16-bit mono samples."""
    rng = random.Random(seed)
    total = int(SAMPLE_RATE * DURATION_SECONDS)
    transient = int(SAMPLE_RATE * DURATION_SECONDS * TRANSIENT_FRACTION)

    # One-pole low-pass state for the noise, so the transient is a soft tap
    # rather than a hiss. The coefficient puts its corner well below the band
    # the tone lives in.
    noise_state = 0.0
    noise_alpha = 0.12

    samples: list[int] = []
    phase = 0.0
    for index in range(total):
        t = index / SAMPLE_RATE
        # Exponential sweep from START_HZ to END_HZ across the whole sound. An
        # exponential sweep is used rather than a linear one because pitch is
        # perceived logarithmically, and a linear ramp spends most of its time
        # inaudibly low.
        progress = t / DURATION_SECONDS
        freq = START_HZ * math.pow(END_HZ / START_HZ, progress)

        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        tone = 0.0
        for multiple, gain in HARMONICS:
            tone += gain * math.sin(phase * multiple)

        value = tone * _envelope(t)

        if index < transient:
            # A short burst of noise, low-passed and windowed to nothing at the
            # end of the transient, standing in for the contact itself.
            window = 1.0 - (index / transient)
            noise_state += noise_alpha * (rng.uniform(-1.0, 1.0) - noise_state)
            value += TRANSIENT_GAIN * window * window * noise_state

        samples.append(int(max(-1.0, min(1.0, value)) * 32767))

    peak = max(abs(s) for s in samples) or 1
    scale = (PEAK * 32767) / peak
    return [int(s * scale) for s in samples]


def _write_wav(samples: list[int], path: Path) -> None:
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(CHANNELS)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(struct.pack("<%dh" % len(samples), *samples))


def _encode_mp3(wav_path: Path, mp3_path: Path) -> None:
    subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(wav_path),
            "-c:a", "libmp3lame",
            "-b:a", f"{BITRATE_KBPS}k",
            # 24 kHz is an MPEG-2 rate, so the header has to say MPEG-2 for a
            # player to read the sample rate back correctly.
            "-write_xing", "0",
            # No ID3 tag, matching the mission cues. Left to itself, ffmpeg
            # writes a TSSE encoder tag whose declared size does not match the
            # bytes actually written, which leaves a tag that claims to run ten
            # bytes past the first MPEG frame. A player that honours the
            # declared size finds its stream misaligned, and the app's own
            # asset test cannot walk the frames at all.
            "-id3v2_version", "0",
            "-map_metadata", "-1",
            str(mp3_path),
        ],
        check=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--force",
        action="store_true",
        help="regenerate even if the asset already exists",
    )
    args = parser.parse_args()

    if OUTPUT.exists() and not args.force:
        print(f"{OUTPUT.relative_to(ROOT)} already exists; pass --force to rebuild")
        return

    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required to encode the MP3")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / "avatar_bounce.wav"
        _write_wav(_synthesize(seed=20240917), wav_path)
        _encode_mp3(wav_path, OUTPUT)

    size_kb = OUTPUT.stat().st_size / 1024
    print(f"wrote {OUTPUT.relative_to(ROOT)} ({size_kb:.1f} kB)")


if __name__ == "__main__":
    main()
