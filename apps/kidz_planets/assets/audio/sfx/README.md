# Planetary sound effects

Kidz Planets uses subtle, stylized sound-design beds on the detail screen.

These are **not literal sounds traveling through space**. Sound waves cannot propagate
through the vacuum of space. NASA also creates sonifications by translating space
data into audible forms. The app uses the same educational idea: each world gets a
distinct audio identity that reinforces the visual experience.

Generate the local WAV assets with Python's standard library:

```bash
python3 tool/generate_planet_sfx.py
```

Test one body:

```bash
python3 tool/generate_planet_sfx.py --only earth
python3 tool/generate_planet_sfx.py --only sun --force
```

The generated files are:

```text
assets/audio/sfx/planets/<body-id>.wav
```

The Flutter app loops the selected body's ambience while its detail view is open.
The `Sound` control in the detail sheet replays that ambience.

The sound design is intentionally subtle:
- Earth: gentle rotational/atmospheric hum
- Sun: warm low solar rumble with shimmer
- Jupiter: deep giant-world rumble
- Saturn: soft resonant/ring-like shimmer
- Io: more turbulent volcanic texture
- Europa/Enceladus: icy, high shimmering tones
- Triton: cold, distant low ambience

Do not describe these assets as recordings of sound in the vacuum of space.

# Mission sound effects

Two cues play when `ExplorerController._checkMission()` accepts or rejects the
selected planet:

```text
assets/audio/sfx/missions/mission_success.mp3
assets/audio/sfx/missions/mission_failure.mp3
```

`startMissionSuccess()` **loops** the success cue for as long as the celebration
dialog is on screen and stops it from `closeCelebration()`; it is the only
place the dialog is dismissed. `playMissionFailure()` remains a one-shot.

Unlike the planetary beds these are *not* generated locally. They come from
Kenney's **Digital Audio** pack (<https://kenney.nl/assets/digital-audio>),
released under **CC0 1.0 Universal** (public domain) — free for personal,
educational and commercial use, attribution optional. Crediting Kenney is
appreciated but not required.

| App asset | Source file | Character |
| --- | --- | --- |
| `mission_success.mp3` | `Audio/pepSound3.ogg` | 0.44 s ascending run, ~F#4 to F5: a bright "yay!" |
| `mission_failure.mp3` | `Audio/phaserDown1.ogg` | 0.47 s descending sweep, D5 to E4: a clear, gentle "nope" |

The two cues deliberately move in opposite directions so children can tell them
apart by ear alone. The failure cue falls rather than buzzing, which keeps it
discouraging but not harsh for a young audience.

Both are stored as 24 kHz / mono MP3, matching `assets/audio/narration`, with
8 ms edge fades so the cues never click and peaks normalised to roughly -2 dBFS
so they sit clearly above the 0.42-volume ambience while leaving headroom. The
success cue is played at 0.7 because nothing competes with it, unlike the beds.

MP3 rather than WAV because the narration is the only audio path confirmed to
play on every target platform, and it is MP3. The cues were first authored as
24 kHz / 16-bit / mono PCM WAV — identical sample rate and channel count to the
narration, so the container was the only difference and the only thing left to
rule out. At 0.44 s the lossy encode is transparent for these short synth tones,
and the decoded length is unchanged (576 samples per frame, `-write_xing 1` so
the last frame's padding is not counted).

Note that `.gitignore` ignores `*.wav` globally for the Kokoro narration
tooling, so `!assets/audio/sfx/**/*.mp3` is required for the MP3 cues to be
committed at all. To rebuild them from the source pack:

```bash
# Stage 1: 24 kHz mono PCM, so the edge fades and levels match the beds.
ffmpeg -i pepSound3.ogg \
  -af "lowpass=f=10500,afade=t=in:st=0:d=0.008,afade=t=out:st=0.419:d=0.025" \
  -ar 24000 -ac 1 -c:a pcm_s16le -map_metadata -1 success_stage.wav
ffmpeg -i phaserDown1.ogg \
  -af "lowpass=f=10500,afade=t=in:st=0:d=0.008,afade=t=out:st=0.445:d=0.025" \
  -ar 24000 -ac 1 -c:a pcm_s16le -map_metadata -1 failure_stage.wav

# Stage 2: normalise the peak.
ffmpeg -i success_stage.wav -af "volume=-1.5dB" \
  -ar 24000 -ac 1 -c:a pcm_s16le success_norm.wav
ffmpeg -i failure_stage.wav -af "volume=3.0dB" \
  -ar 24000 -ac 1 -c:a pcm_s16le failure_norm.wav

# Stage 3: encode. -id3v2_version 0 drops the encoder tag ffmpeg adds by
# default; -write_xing 1 keeps the frame count so duration stays exact.
ffmpeg -i success_norm.wav -codec:a libmp3lame -b:a 96k -ar 24000 -ac 1 \
  -map_metadata -1 -id3v2_version 0 -write_xing 1 mission_success.mp3
ffmpeg -i failure_norm.wav -codec:a libmp3lame -b:a 96k -ar 24000 -ac 1 \
  -map_metadata -1 -id3v2_version 0 -write_xing 1 mission_failure.mp3
```

`test/mission_sfx_assets_test.dart` guards both files: it checks they exist in
the source tree, are loadable through `RootBundle` (which is what
`AudioPlayer.setAsset` reads), and decode as 24 kHz mono MPEG-2 Layer III at
96 kbps. The test walks the frame headers itself rather than just sniffing the
container, so a truncated or renamed file fails rather than passing as "some
audio".
