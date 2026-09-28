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

Two one-shot cues play through `PlanetSoundService.playMissionSuccess()` and
`playMissionFailure()` when `ExplorerController._checkMission()` accepts or
rejects the selected planet:

```text
assets/audio/sfx/missions/mission_success.wav
assets/audio/sfx/missions/mission_failure.wav
```

Unlike the planetary beds these are *not* generated locally. They come from
Kenney's **Digital Audio** pack (<https://kenney.nl/assets/digital-audio>),
released under **CC0 1.0 Universal** (public domain) — free for personal,
educational and commercial use, attribution optional. Crediting Kenney is
appreciated but not required.

| App asset | Source file | Character |
| --- | --- | --- |
| `mission_success.wav` | `Audio/pepSound3.ogg` | 0.44 s ascending run, ~F#4 to F5: a bright "yay!" |
| `mission_failure.wav` | `Audio/phaserDown1.ogg` | 0.47 s descending sweep, D5 to E4: a clear, gentle "nope" |

The two cues deliberately move in opposite directions so children can tell them
apart by ear alone. The failure cue falls rather than buzzing, which keeps it
discouraging but not harsh for a young audience.

Both are stored as 24 kHz / 16-bit / mono PCM WAV to match the generated
planetary beds, with 8 ms edge fades so the one-shots never click and peaks
normalised to roughly -2 dBFS so they sit clearly above the 0.42-volume
ambience while leaving headroom. To rebuild them from the source pack:

```bash
ffmpeg -i pepSound3.ogg \
  -af "lowpass=f=10500,afade=t=in:st=0:d=0.008,afade=t=out:st=0.419:d=0.025" \
  -ar 24000 -ac 1 -c:a pcm_s16le success_stage.wav
ffmpeg -i success_stage.wav -af "volume=-1.5dB" \
  -ar 24000 -ac 1 -c:a pcm_s16le mission_success.wav

ffmpeg -i phaserDown1.ogg \
  -af "lowpass=f=10500,afade=t=in:st=0:d=0.008,afade=t=out:st=0.445:d=0.025" \
  -ar 24000 -ac 1 -c:a pcm_s16le failure_stage.wav
ffmpeg -i failure_stage.wav -af "volume=3.0dB" \
  -ar 24000 -ac 1 -c:a pcm_s16le mission_failure.wav
```

`test/mission_sfx_assets_test.dart` guards both files: it checks they exist in
the source tree, are loadable through `RootBundle` (which is what
`AudioPlayer.setAsset` reads), and are decodable 24 kHz mono PCM.
