#!/usr/bin/env python3
"""Generate the companion's expression sounds locally.

The companion has a face and a voice, and until now it had exactly one sound
(the bounce). A character that changes expression silently reads as broken in a
way that a toy which was simply quiet does not: a laugh with no laugh, or a
droop with no sound, looks like the animation failed to start.

Each cue is synthesized here rather than sourced externally, for the same
reason `generate_avatar_bounce_sfx.py` synthesizes its thud: the asset carries
no third-party licence into a children's app, and any of these can be
regenerated deterministically if the expression timings change.

The timbres are deliberately built from short pitched gestures rather than
being recordings of a person, because the companion is not a person. A voiced
"ha" would imply a mouth that is not there; a two-note rising interval reads as
cheerfulness without implying speech. They also stay clear of the narration
band, because a competing voice is worse than no voice: the cues sit in a
narrow band around 500-1200 Hz while speech lives mostly below 1 kHz and above
2 kHz, so the two can share the speaker without either disappearing.

Usage:
  python3 tool/generate_avatar_expression_sfx.py [--force]
  python3 tool/generate_avatar_expression_sfx.py --only happy sad
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
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets/audio/sfx/avatar"

SAMPLE_RATE = 24_000
BITRATE_KBPS = 96
CHANNELS = 1
PEAK = 0.82


@dataclass
class Note:
    """One pitched gesture inside a cue.

    A cue is a list of these rather than a single sweep, because a reaction is
    a phrase: a happy face rises and settles, it does not beep once. Two or
    three notes is enough to imply that shape.
    """

    start_hz: float
    duration: float
    gain: float = 1.0
    # An optional glide to this frequency across the note. Rising glides read
    # as "up", falling glides as "down", and they cost nothing.
    end_hz: float | None = None
    harmonics: tuple[tuple[float, float], ...] = ((1.0, 1.0), (2.0, 0.26), (3.0, 0.09))
    # A per-note decay, in e-foldings per second. Higher stops the note sooner,
    # which is what keeps a rising phrase from turning into a held chord.
    decay: float = 9.0
    attack: float = 0.004
    # Some cues read better with a soft noise breath under the tones, which is
    # what makes a gesture feel like air rather than a test tone.
    breath: float = 0.0
    breath_hz: float = 0.0


@dataclass
class Cue:
    """A named expression sound."""

    name: str
    notes: list[Note]
    # Silence between notes, as a fraction of a second.
    gap: float = 0.0
    seed: int = 0
    # Reverses the cue in time. Used for the sad droop, which is a fall heard
    # as a gesture rather than a note that simply ends.
    reverse: bool = False
    breath: float = field(default=0.0)


def _render_note(
    note: Note,
    rng: random.Random,
    sample_rate: int,
) -> list[float]:
    """Renders one note as floats in -1..1."""
    total = max(1, int(sample_rate * note.duration))
    end_hz = note.end_hz if note.end_hz is not None else note.start_hz
    breath_total = int(sample_rate * note.breath) if note.breath else 0

    phase = 0.0
    breath_phase = 0.0
    breath_state = 0.0
    out: list[float] = []
    for index in range(total):
        t = index / sample_rate
        progress = index / total

        # An exponential glide, for the same reason the bounce uses one: pitch
        # is perceived logarithmically, so a linear ramp spends most of its
        # length inaudibly low.
        freq = note.start_hz * math.pow(end_hz / note.start_hz, progress)

        phase += 2.0 * math.pi * freq / sample_rate
        value = 0.0
        for multiple, harmonic_gain in note.harmonics:
            value += harmonic_gain * math.sin(phase * multiple)

        # Fast attack, exponential decay. A slow attack on a reaction would
        # arrive after the face has already changed, which is the one thing
        # that must not happen: the sound and the expression start together.
        if t < note.attack:
            envelope = t / note.attack
        else:
            envelope = math.exp(-note.decay * (t - note.attack))
        value *= envelope

        if index < breath_total:
            window = 1.0 - (index / breath_total)
            breath_phase += 2.0 * math.pi * note.breath_hz / sample_rate
            breath_state += 0.14 * (rng.uniform(-1.0, 1.0) - breath_state)
            value += note.breath * window * window * (
                0.7 * breath_state + 0.3 * math.sin(breath_phase)
            )

        out.append(value)
    return out


def _render_cue(cue: Cue, sample_rate: int = SAMPLE_RATE) -> list[float]:
    rng = random.Random(cue.seed)
    gap_samples = int(sample_rate * cue.gap)

    samples: list[float] = []
    for index, note in enumerate(cue.notes):
        if index > 0 and gap_samples > 0:
            samples.extend([0.0] * gap_samples)
        samples.extend(_render_note(note, rng, sample_rate))

    if cue.reverse:
        samples.reverse()

    # One gentle fade at each end of the whole cue, so a cue that starts or
    # stops mid-tone does not click. Without this a percussive ending that gets
    # cut by the next reaction produces an audible tick.
    edge = min(int(sample_rate * 0.004), len(samples) // 4)
    for i in range(edge):
        gain = i / edge
        samples[i] *= gain
        samples[-1 - i] *= gain

    peak = max(abs(s) for s in samples) or 1.0
    return [s / peak * PEAK for s in samples]


def _write_wav(samples: list[float], path: Path) -> None:
    ints = [int(max(-1.0, min(1.0, s)) * 32767) for s in samples]
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(CHANNELS)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(struct.pack("<%dh" % len(ints), *ints))


def _encode_mp3(wav_path: Path, mp3_path: Path) -> None:
    subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(wav_path),
            "-c:a", "libmp3lame",
            "-b:a", f"{BITRATE_KBPS}k",
            "-write_xing", "0",
            # No ID3 tag and no metadata, matching the bounce and the mission
            # cues. ffmpeg's default TSSE tag declares a size that does not
            # match the bytes written, which misaligns the stream for a player
            # that honours it and stops the app's own asset test walking frames.
            "-id3v2_version", "0",
            "-map_metadata", "-1",
            str(mp3_path),
        ],
        check=True,
    )


# A soft, round harmonic stack. The second harmonic is what gives the toy a
# body; higher ones stay low so nothing turns reedy.
ROUND = ((1.0, 1.0), (2.0, 0.26), (3.0, 0.09))
# Fewer upper partials, for the cues that should sound like breath rather than
# a toy tapping.
SOFT = ((1.0, 1.0), (2.0, 0.14))


CUES: list[Cue] = [
    # Happy: a rising two-note lift, the smallest gesture that reads as cheer.
    Cue(
        name="avatar_happy",
        seed=1101,
        gap=0.035,
        notes=[
            Note(620.0, 0.075, gain=0.9, end_hz=700.0, harmonics=ROUND, decay=13.0),
            Note(880.0, 0.16, gain=1.0, end_hz=990.0, harmonics=ROUND, decay=8.0),
        ],
    ),
    # Excited: the same lift, faster and higher, so it is distinguishable from
    # happy by tempo alone and does not need a separate timbre.
    Cue(
        name="avatar_excited",
        seed=1102,
        gap=0.018,
        notes=[
            Note(780.0, 0.05, gain=0.8, end_hz=880.0, harmonics=ROUND, decay=17.0),
            Note(1046.0, 0.045, gain=0.85, end_hz=1174.0, harmonics=ROUND, decay=17.0),
            Note(1318.0, 0.05, gain=0.9, end_hz=1480.0, harmonics=ROUND, decay=16.0),
            Note(1760.0, 0.19, gain=1.0, end_hz=1568.0, harmonics=ROUND, decay=7.0),
        ],
    ),
    # Laughing: three short rising puffs. Not voiced on purpose, see module doc.
    Cue(
        name="avatar_laughing",
        seed=1103,
        gap=0.03,
        notes=[
            Note(520.0, 0.06, gain=0.8, end_hz=600.0, harmonics=SOFT, decay=15.0, breath=0.1, breath_hz=1400.0),
            Note(640.0, 0.06, gain=0.85, end_hz=720.0, harmonics=SOFT, decay=15.0, breath=0.1, breath_hz=1500.0),
            Note(780.0, 0.22, gain=1.0, end_hz=660.0, harmonics=SOFT, decay=7.0, breath=0.12, breath_hz=1600.0),
        ],
    ),
    # Surprised: one quick upward leap and a held top, which is the shape of
    # the face. Bright harmonics, because surprise is the only cue here that
    # should sound like it came from somewhere brighter.
    Cue(
        name="avatar_surprised",
        seed=1104,
        notes=[
            Note(560.0, 0.045, gain=0.85, end_hz=1250.0, harmonics=ROUND, decay=12.0),
            Note(1250.0, 0.26, gain=1.0, end_hz=1180.0, harmonics=ROUND, decay=7.0, breath=0.06, breath_hz=2600.0),
        ],
    ),
    # Sad: a falling pair, reversed in time so the droop is heard as a gesture
    # rather than as a note that trails away and stops.
    Cue(
        name="avatar_sad",
        seed=1105,
        gap=0.05,
        reverse=True,
        notes=[
            Note(520.0, 0.12, gain=0.85, harmonics=SOFT, decay=8.0),
            Note(400.0, 0.3, gain=1.0, end_hz=360.0, harmonics=SOFT, decay=5.0),
        ],
    ),
    # Dizzy: a wobbling detuned pair. Two tones beating against each other is
    # what "unsteady" sounds like, and it is why this is a pair and not a
    # sweep like the bounce.
    Cue(
        name="avatar_dizzy",
        seed=1106,
        notes=[
            Note(430.0, 0.2, gain=0.8, end_hz=470.0, harmonics=SOFT, decay=6.0),
            Note(443.0, 0.2, gain=0.8, end_hz=418.0, harmonics=SOFT, decay=6.0),
            Note(436.0, 0.24, gain=0.9, end_hz=452.0, harmonics=SOFT, decay=6.0),
            Note(449.0, 0.24, gain=0.9, end_hz=425.0, harmonics=SOFT, decay=6.0),
        ],
    ),
    # Sleepy: a long falling sigh with almost no top, the quietest cue here.
    Cue(
        name="avatar_sleepy",
        seed=1107,
        notes=[
            Note(500.0, 0.14, gain=0.6, end_hz=460.0, harmonics=SOFT, decay=7.0, breath=0.07, breath_hz=700.0),
            Note(450.0, 0.42, gain=0.7, end_hz=330.0, harmonics=SOFT, decay=4.0, breath=0.06, breath_hz=600.0),
        ],
    ),
    # Talking: a single soft blip, not a phrase. The mouth is already animated
    # at about three syllables a second, so a sound per syllable would be a
    # machine gun; one blip marks that the companion has started speaking and
    # the animation carries the rest.
    Cue(
        name="avatar_talking",
        seed=1108,
        gap=0.02,
        notes=[
            Note(700.0, 0.05, gain=0.7, end_hz=760.0, harmonics=SOFT, decay=16.0, breath=0.05, breath_hz=1800.0),
            Note(780.0, 0.12, gain=0.75, end_hz=720.0, harmonics=SOFT, decay=10.0, breath=0.05, breath_hz=1700.0),
        ],
    ),
    # Thinking: two mid tones that lean and settle. Deliberately unresolved,
    # because a final cadence would sound like an answer and this is a pause.
    Cue(
        name="avatar_thinking",
        seed=1109,
        gap=0.06,
        notes=[
            Note(600.0, 0.11, gain=0.75, end_hz=660.0, harmonics=SOFT, decay=11.0),
            Note(620.0, 0.28, gain=0.8, end_hz=596.0, harmonics=SOFT, decay=6.0),
        ],
    ),
    # Love: a bright sparkle, two notes a fifth apart with a fast upper one on
    # top. Placed high and short so it does not read as a reward fanfare.
    Cue(
        name="avatar_love",
        seed=1110,
        gap=0.02,
        notes=[
            Note(988.0, 0.06, gain=0.8, end_hz=1174.0, harmonics=ROUND, decay=14.0),
            Note(1318.0, 0.05, gain=0.7, end_hz=1568.0, harmonics=ROUND, decay=15.0),
            Note(1568.0, 0.2, gain=0.9, end_hz=1480.0, harmonics=ROUND, decay=8.0, breath=0.05, breath_hz=3200.0),
        ],
    ),
    # Confused: the asking wobble, a rise that stalls and falls back. This cue
    # exists for the `confused` reaction; see the note in the catalog.
    Cue(
        name="avatar_confused",
        seed=1111,
        gap=0.025,
        notes=[
            Note(540.0, 0.1, gain=0.8, end_hz=700.0, harmonics=SOFT, decay=11.0),
            Note(690.0, 0.1, gain=0.8, end_hz=560.0, harmonics=SOFT, decay=11.0),
            Note(575.0, 0.16, gain=0.75, end_hz=520.0, harmonics=SOFT, decay=10.0),
        ],
    ),
    # Success: a short major triad, deliberately clipped. The mission already
    # has a long success cue and this plays with it, so a full cadence would
    # be two celebrations fighting.
    Cue(
        name="avatar_success",
        seed=1112,
        gap=0.028,
        notes=[
            Note(784.0, 0.06, gain=0.85, harmonics=ROUND, decay=15.0),
            Note(988.0, 0.06, gain=0.85, harmonics=ROUND, decay=15.0),
            Note(1174.0, 0.24, gain=1.0, end_hz=1568.0, harmonics=ROUND, decay=7.0, breath=0.05, breath_hz=3000.0),
        ],
    ),
    # Failure: two low descending notes, then a small third note that comes
    # back up a little. The turn upward is the point: the mission cue that
    # plays with this is a genuine "try again", and a purely falling figure
    # would contradict it.
    Cue(
        name="avatar_failure",
        seed=1113,
        gap=0.05,
        notes=[
            Note(392.0, 0.1, gain=0.8, harmonics=SOFT, decay=10.0),
            Note(330.0, 0.12, gain=0.8, harmonics=SOFT, decay=10.0),
            Note(392.0, 0.2, gain=0.7, harmonics=SOFT, decay=8.0),
        ],
    ),
    # Find-object: a two-note attention call before a clue. Rising fifth, loud
    # enough to turn a head, short enough to hand over to the narration that
    # follows it immediately.
    Cue(
        name="avatar_find_object",
        seed=1114,
        gap=0.05,
        notes=[
            Note(660.0, 0.09, gain=0.85, end_hz=740.0, harmonics=ROUND, decay=11.0),
            Note(988.0, 0.18, gain=0.9, end_hz=1046.0, harmonics=ROUND, decay=8.0, breath=0.04, breath_hz=2800.0),
        ],
    ),
    # Throw whoosh: a fast airy sweep for a flick, not a tone. Short and
    # breathy so a hard throw reads as motion without sounding like a reward.
    Cue(
        name="avatar_throw_whoosh",
        seed=1115,
        gap=0.0,
        notes=[
            Note(320.0, 0.14, gain=0.9, end_hz=880.0, harmonics=SOFT, decay=7.0, breath=0.16, breath_hz=1400.0),
        ],
    ),
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="regenerate existing assets")
    parser.add_argument("--only", nargs="*", help="generate only these cue names")
    args = parser.parse_args()

    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required to encode the MP3s")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    selected = [c for c in CUES if args.only is None or c.name in set(args.only)]
    if args.only:
        unknown = set(args.only) - {c.name for c in CUES}
        if unknown:
            raise SystemExit(f"unknown cue(s): {', '.join(sorted(unknown))}")

    written = 0
    for cue in selected:
        out = OUTPUT_DIR / f"{cue.name}.mp3"
        if out.exists() and not args.force:
            print(f"{out.relative_to(ROOT)} already exists; pass --force to rebuild")
            continue
        with tempfile.TemporaryDirectory() as tmp:
            wav_path = Path(tmp) / f"{cue.name}.wav"
            _write_wav(_render_cue(cue), wav_path)
            _encode_mp3(wav_path, out)
        written += 1
        print(
            f"wrote {out.relative_to(ROOT)} "
            f"({out.stat().st_size / 1024:.1f} kB, "
            f"{sum(n.duration for n in cue.notes) + cue.gap * max(0, len(cue.notes) - 1):.2f}s)"
        )

    if written == 0:
        print("nothing written")
    else:
        print(f"\n{written} cue(s) written")


if __name__ == "__main__":
    main()
