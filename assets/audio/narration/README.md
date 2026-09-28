# Neural narration audio

The app plays pre-generated neural TTS files with `just_audio`. Device TTS remains
only as a fallback while the bundled files are missing.

## Generate the real neural audio

The repository includes `tool/generate_neural_narration.py`. It reads the narration
copy directly from `lib/data/datasources/planet_catalog.dart`, so the spoken
content does not need to be duplicated in another source file.

The generator uses ElevenLabs Text to Speech. ElevenLabs returns MP3 audio from
its TTS endpoint, which is exactly what the Flutter narration player expects.

Set the credentials locally; never commit the API key:

```bash
export ELEVENLABS_API_KEY="your-key"
export ELEVENLABS_VOICE_ID="your-voice-id"

python3 tool/generate_neural_narration.py
```

The default model is `eleven_multilingual_v2`, which is intended for stable,
high-fidelity narration. You can override it with:

```bash
export ELEVENLABS_MODEL="eleven_v3"
```

Generate a single entry while testing a voice:

```bash
python3 tool/generate_neural_narration.py --only saturn
```

Preview the complete asset list without calling the API:

```bash
python3 tool/generate_neural_narration.py --dry-run
```

Use `--force` to regenerate an existing file.

## Planet narration

- `planets/sun.mp3`
- `planets/mercury.mp3`
- `planets/venus.mp3`
- `planets/earth.mp3`
- `planets/mars.mp3`
- `planets/jupiter.mp3`
- `planets/saturn.mp3`
- `planets/uranus.mp3`
- `planets/neptune.mp3`

## Hotspot narration

Use the slug of the hotspot title:

- `hotspots/nuclear_fusion.mp3`
- `hotspots/solar_wind.mp3`
- `hotspots/speedy_orbit.mp3`
- `hotspots/cratered_face.mp3`
- `hotspots/runaway_heat.mp3`
- `hotspots/backward_spin.mp3`
- `hotspots/liquid_oceans.mp3`
- `hotspots/protective_shield.mp3`
- `hotspots/olympus_mons.mp3`
- `hotspots/polar_ice_caps.mp3`
- `hotspots/great_red_spot.mp3`
- `hotspots/79_moons.mp3`
- `hotspots/icy_rings.mp3`
- `hotspots/light_as_cork.mp3`
- `hotspots/sideways_roll.mp3`
- `hotspots/methane_sky.mp3`
- `hotspots/supersonic_winds.mp3`
- `hotspots/white_cirrus_clouds.mp3`

Flutter asset directories are declared separately for `planets/` and
`hotspots/` because files inside nested subdirectories are not included by
declaring only their parent directory.