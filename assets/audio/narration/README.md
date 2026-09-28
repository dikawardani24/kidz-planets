# Neural narration audio

The app plays pre-generated neural TTS files with `just_audio`. Device TTS remains
only as a fallback while the bundled files are missing.

## Quick start

One command does the whole setup and generation:

```bash
./run.sh narration
```

Or call the helper directly:

```bash
./tool/setup_kokoro.sh              # install dependencies and set up the venv
./tool/setup_kokoro.sh --saturn     # generate Saturn only, to audition the voice
./tool/setup_kokoro.sh --all        # generate all 9 planets + 18 hotspots
./tool/setup_kokoro.sh --check      # report what is missing, install nothing
```

The helper installs `ffmpeg`/`espeak-ng` via Homebrew, creates `.venv-kokoro`,
installs Kokoro, and exports `PYTORCH_ENABLE_MPS_FALLBACK=1` on Apple Silicon.
It is safe to re-run.

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

Kokoro requires **Python 3.10 to 3.12** (`requires-python >=3.10,<3.13`). macOS
ships Python 3.9, so install a newer interpreter first if `pip` rejects the
install:

```bash
brew install python@3.12
python3.12 -m venv .venv-kokoro
```

### Using pyenv instead

pyenv is the other common option. Because the pyenv shims only reach `PATH` in
an **interactive** shell, each shell needs its own init line.

**fish** — add to `~/.config/fish/config.fish`:

```fish
if status is-interactive; and type -q pyenv
    set -gx PYENV_ROOT $HOME/.pyenv
    pyenv init - fish | source
end
```

Use `pyenv init - fish | source`, **not** `eval (pyenv init - fish)`. Command
substitution joins the output onto a single line, which corrupts the multi-line
`while ... end` block that pyenv emits.

**zsh/bash** — add to `~/.zshrc`:

```bash
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init -)"
```

Then start a new shell and confirm:

```bash
cd /path/to/kidz-planets
python3 --version          # 3.12.x
pyenv local 3.12.13        # pins the version for this repo only
```

`tool/setup_kokoro.sh` also looks inside `~/.pyenv/versions` directly, so it
works from non-interactive shells and CI even when the shims are absent from
`PATH`. `.python-version` is gitignored because it is a machine-local pin.

Also note that `espeak-ng` supplies the phoneme fallback used by some voices, and
`ffmpeg` is required to encode the MP3 assets.

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