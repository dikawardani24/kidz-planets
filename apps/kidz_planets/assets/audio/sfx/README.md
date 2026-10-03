# Planetary sound effects

Kidz Planets uses subtle, stylized sound-design beds on the detail screen.

These are **not literal sounds traveling through space**. Sound waves cannot propagate
through the vacuum of space. NASA also creates sonifications by translating space
data into audible forms. The app uses the same educational idea: each world gets a
distinct audio identity that reinforces the visual experience.

The beds are generated **and committed**. They were generated-only for a while,
which meant a fresh clone built an app where every selection logged "Planet
sound unavailable" and played nothing: the `.gitignore` rule meant to let them
through was missing the `apps/kidz_planets/` prefix, so it matched nothing.

Regenerate all of them with Python's standard library plus `ffmpeg` (same
requirement as the other generators in `tool/`):

```bash
python3 tool/generate_planet_sfx.py
```

Rebuild one body, or overwrite an existing file:

```bash
python3 tool/generate_planet_sfx.py --only earth
python3 tool/generate_planet_sfx.py --only sun --force
```

The generated files are:

```text
assets/audio/sfx/planets/<body-id>.mp3
```

MP3 to match the narration and the cues, at 24 kHz / mono / 40 kb/s, which keeps
all 27 beds near 0.5 MB. The same beds as WAV cost about 5 MB for nothing a
player can hear on a synthesized loop.

Every component of a bed completes a whole number of cycles over the 4 s loop,
so the file loops without a seam. The beds are levelled to about -23 dBFS RMS,
which at the 0.42 volume the app plays them at lands near -30 dBFS effective:
roughly 4 dB under the narration playing over them. Getting this wrong is easy
in both directions and both were wrong at some point — an earlier 0.42 scale put
Jupiter above the voice, and a later 0.08 scale put every bed some 27 dB under a
normal listening level, which is indistinguishable from no sound at all.

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

MP3 rather than WAV because these are short and hand-authored, so the lossy
encode is transparent at 0.44 s and halves what the bundle carries. The cues
were first authored as 24 kHz / 16-bit / mono PCM WAV — identical sample rate
and channel count to the narration, so the container was the only difference;
WAV was ruled out as a *cause* of silence here only because the assets were
missing, not because the container was at fault. The decoded length is
unchanged (576 samples per frame, `-write_xing 1` so the last frame's padding is
not counted).

`.gitignore` ignores `*.wav` globally for the Kokoro narration tooling, so
anything under this folder that is not MP3 needs a whitelist entry, and it has
to carry the full package path: a pattern containing a slash is anchored to the
repository root, so `!assets/audio/sfx/**` matched nothing at all. That is why
this folder shipped as an empty directory behind a `.gitkeep` for as long as it
did — the beds were generated locally, silently ignored, and never reached any
build. Both formats are now covered by `!apps/kidz_planets/assets/audio/sfx/**`.
To rebuild the cues from the source pack:

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

`test/mission_sfx_assets_test.dart` guards all of these: it checks the beds and
the cues exist in the source tree, are loadable through `RootBundle` (which is
what `AudioPlayer.setAsset` reads), and decode as the format each one claims —
24 kHz mono PCM for the beds, 24 kHz MPEG-2 Layer III for the cues. The tests
walk the container themselves rather than just sniffing a header, so a truncated
or renamed file fails rather than passing as "some audio".
