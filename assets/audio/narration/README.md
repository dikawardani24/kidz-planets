# Neural narration audio

The app plays pre-generated neural TTS files with `just_audio`. Device TTS remains
only as a fallback while the bundled files are missing.

## Free local generation with Kokoro

The repository includes `tool/generate_neural_narration.py`. It reads the narration
copy directly from `lib/data/datasources/planet_catalog.dart`, then runs Kokoro
locally and writes MP3 assets into this directory.

Kokoro is an open-weight 82M-parameter TTS model with an Apache license. Its
official inference library supports local Python generation and 24 kHz audio.

### macOS setup

Install the native tools:

```bash
brew install espeak-ng ffmpeg
```

Create a dedicated Python environment:

```bash
python3 -m venv .venv-kokoro
source .venv-kokoro/bin/activate
pip install "kokoro>=0.9.4" soundfile
```

For Apple Silicon Macs, Kokoro's documentation recommends enabling the PyTorch
MPS fallback:

```bash
export PYTORCH_ENABLE_MPS_FALLBACK=1
```

### Generate one test narration

Start with Saturn so you can judge the voice before generating every file:

```bash
python3 tool/generate_neural_narration.py --only saturn
```

The default voice is `af_heart`. You can test another local Kokoro voice:

```bash
python3 tool/generate_neural_narration.py --only saturn --voice af_sarah
python3 tool/generate_neural_narration.py --only saturn --voice am_michael
```

### Generate everything

```bash
python3 tool/generate_neural_narration.py
```

This generates the nine planet narrations and all hotspot narrations from the
existing catalog.

Use `--force` to regenerate existing files:

```bash
python3 tool/generate_neural_narration.py --force
```

Preview the asset list without loading the model:

```bash
python3 tool/generate_neural_narration.py --dry-run
```

## Asset naming

Planet assets:

- `planets/sun.mp3`
- `planets/mercury.mp3`
- `planets/venus.mp3`
- `planets/earth.mp3`
- `planets/mars.mp3`
- `planets/jupiter.mp3`
- `planets/saturn.mp3`
- `planets/uranus.mp3`
- `planets/neptune.mp3`

Hotspot assets use the slug of the hotspot title, for example
`hotspots/great_red_spot.mp3` and `hotspots/icy_rings.mp3`.

Flutter asset directories are declared separately for `planets/` and
`hotspots/` so the nested audio files are bundled correctly.

## Cost

This workflow does not call ElevenLabs or any other TTS API. After the Kokoro
model and dependencies are downloaded, narration generation runs locally.

Do not commit the Kokoro model or Python virtual environment to this repository.