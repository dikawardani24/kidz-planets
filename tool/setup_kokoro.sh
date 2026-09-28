#!/usr/bin/env bash
#
# Kidz Planets — local Kokoro narration setup.
#
# One-time setup, then generate. This only ever touches your Mac: Kokoro runs
# locally in a virtualenv and writes MP3 assets into the repository. No cloud
# TTS service, no API key, and no model inference inside the Flutter app.
#
#   ./tool/setup_kokoro.sh              check deps, create venv, install Kokoro
#   ./tool/setup_kokoro.sh --check      verify deps/venv only, install nothing
#   ./tool/setup_kokoro.sh --saturn     generate just Saturn to audition a voice
#   ./tool/setup_kokoro.sh --all        generate all 9 planets + 18 hotspots
#   ./tool/setup_kokoro.sh --all --force          regenerate existing files
#   ./tool/setup_kokoro.sh --saturn --voice af_sarah
#   ./tool/setup_kokoro.sh --list-voices
#
set -euo pipefail
cd "$(dirname "$0")/.."

VENV=".venv-kokoro"
VENV_PY="$VENV/bin/python"
GENERATOR="tool/generate_neural_narration.py"


# Kokoro pins requires-python >=3.10,<3.13, so 3.9 (still shipped by macOS)
# cannot be used to build the virtualenv. Stored as integer pairs so the
# comparison below is numeric rather than a fragile string sort.
PY_MIN=(3 10)
PY_MAX=(3 12)
PY_MIN_STR="3.10"
PY_MAX_STR="3.12"

say() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$1"; }
die() { printf '\033[1;31mERROR\033[0m %s\n' "$1" >&2; exit 1; }

# True when the interpreter satisfies Kokoro's Python range.
supported_python() {
  "$1" -c "
import sys
v = sys.version_info
lo = (${PY_MIN[0]}, ${PY_MIN[1]})
hi = (${PY_MAX[0]}, ${PY_MAX[1]})
raise SystemExit(0 if lo <= (v.major, v.minor) <= hi else 1)
" >/dev/null 2>&1
}

# pyenv installs interpreters outside PATH, and the shims only reach PATH in an
# interactive shell. Query pyenv directly so this script also works from CI,
# non-interactive shells, and editors that never source the shell profile.
pyenv_candidates() {
  [ -n "${PYENV_ROOT:-$HOME/.pyenv}" ] || return 0
  local root="${PYENV_ROOT:-$HOME/.pyenv}"
  [ -d "$root/versions" ] || return 0
  local dir
  # Newest version last, so sort -V keeps 3.12.13 ahead of 3.9.6.
  for dir in $(ls -1 "$root/versions" 2>/dev/null | sort -V -r); do
    [ -x "$root/versions/$dir/bin/python3" ] && printf '%s\n' "$root/versions/$dir/bin/python3"
  done
}

# Pick the first interpreter that satisfies Kokoro's Python range.
find_python() {
  local candidate
  for candidate in $(pyenv_candidates) python3.12 python3.11 python3.10 python3; do
    [ -x "$candidate" ] || command -v "$candidate" >/dev/null 2>&1 || continue
    if supported_python "$candidate"; then
      command -v "$candidate" >/dev/null 2>&1 && command -v "$candidate" || printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

check_brew_tools() {
  local missing=()
  command -v ffmpeg >/dev/null 2>&1 || missing+=("ffmpeg")
  command -v espeak-ng >/dev/null 2>&1 || missing+=("espeak-ng")
  if [ ${#missing[@]} -gt 0 ]; then
    if [ "$1" = "quiet" ]; then
      return 1
    fi
    warn "Missing: ${missing[*]}"
    if command -v brew >/dev/null 2>&1; then
      say "Installing Homebrew packages…"
      brew install ffmpeg espeak-ng
    else
      die "Install them manually: brew install ffmpeg espeak-ng"
    fi
  fi
  return 0
}

check_python() {
  if ! find_python >/dev/null 2>&1; then
    die "Kokoro needs Python $PY_MIN_STR to $PY_MAX_STR, and no suitable interpreter is on PATH.
  macOS ships Python 3.9, which cannot install it. Install a supported one:
    brew install python@3.12"
  fi
}

check_venv() {
  [ -x "$VENV_PY" ] || return 1
  "$VENV_PY" -c "import kokoro, soundfile" >/dev/null 2>&1
}

create_venv() {
  local py
  py="$(find_python)" || die "No supported Python found."
  say "Creating $VENV with $py ($("$py" --version 2>&1))"
  [ -d "$VENV" ] && rm -rf "$VENV"
  "$py" -m venv "$VENV"
}

install_kokoro() {
  say "Installing Kokoro (first run downloads the model, ~90 MB)…"
  "$VENV_PY" -m pip install --quiet --upgrade pip
  "$VENV_PY" -m pip install --quiet "kokoro>=0.9.4" soundfile
  say "Kokoro installed."
}

ensure_ready() {
  check_python
  check_brew_tools install
  if check_venv; then
    say "Existing $VENV is ready."
    return
  fi
  create_venv
  install_kokoro
}

activate_env() {
  # Apple Silicon: enable the PyTorch MPS fallback Kokoro recommends.
  if [ "$(uname -m)" = "arm64" ]; then
    export PYTORCH_ENABLE_MPS_FALLBACK=1
  fi
}

do_check() {
  say "Checking prerequisites…"
  local ok=1 py planets hotspots
  py="$(find_python 2>/dev/null || true)"
  if [ -n "$py" ]; then
    echo "  python: $py ($("$py" --version 2>&1))"
  else
    # macOS still ships Python 3.9, which cannot install Kokoro.
    echo "  python: MISSING (need $PY_MIN_STR to $PY_MAX_STR; 'brew install python@3.12')"
    ok=0
  fi
  if command -v ffmpeg >/dev/null 2>&1; then
    echo "  ffmpeg: installed"
  else
    echo "  ffmpeg: MISSING (required to encode MP3)"
    ok=0
  fi
  if command -v espeak-ng >/dev/null 2>&1; then
    echo "  espeak-ng: installed"
  else
    echo "  espeak-ng: MISSING (optional, needed by some voices)"
  fi
  if check_venv; then
    echo "  venv: $VENV ready"
  else
    echo "  venv: not set up yet"
    ok=0
  fi
  # `|| true` because ls exits nonzero while no MP3s exist yet, which would
  # otherwise trip `set -e` before the summary is printed.
  planets=$(ls assets/audio/narration/planets/*.mp3 2>/dev/null | wc -l | tr -d ' ' || true)
  hotspots=$(ls assets/audio/narration/hotspots/*.mp3 2>/dev/null | wc -l | tr -d ' ' || true)
  echo "  assets: $planets/9 planets, $hotspots/18 hotspots generated"
  echo ""
  if [ "$ok" = "1" ]; then
    say "All prerequisites satisfied."
  else
    warn "Not ready. Fix the items above, then run: ./tool/setup_kokoro.sh"
  fi
  return 0
}

do_dry_run() {
  "$VENV_PY" "$GENERATOR" --dry-run "$@"
}

do_generate() {
  local target="$1"; shift
  activate_env
  # Only pass --voice when the user asked for one. The generator already
  # resolves --voice > KOKORO_VOICE > af_heart, so passing a default here
  # would silently outrank a KOKORO_VOICE set in the environment.
  local voice_arg=()
  [ -n "$VOICE_EXPLICIT" ] && voice_arg=(--voice "$VOICE")
  if [ "$target" = "saturn" ]; then
    say "Generating Saturn${VOICE:+ with voice $VOICE}"
    "$VENV_PY" "$GENERATOR" --only saturn ${voice_arg[@]+"${voice_arg[@]}"} "$@"
    say "Audition assets/audio/narration/planets/saturn.mp3"
    echo "  Happy with it? Then generate everything:"
    echo "    ./tool/setup_kokoro.sh --all"
    return
  fi
  say "Generating all narration${VOICE:+ with voice $VOICE} (this takes a few minutes)"
  "$VENV_PY" "$GENERATOR" ${voice_arg[@]+"${voice_arg[@]}"} "$@"
  local planets hotspots
  planets=$(ls assets/audio/narration/planets/*.mp3 2>/dev/null | wc -l | tr -d ' ' || true)
  hotspots=$(ls assets/audio/narration/hotspots/*.mp3 2>/dev/null | wc -l | tr -d ' ' || true)
  say "Done. $planets/9 planets and $hotspots/18 hotspots present."
  echo "  Review the audio, then commit the MP3s:"
  echo "    git add assets/audio/narration && git commit -m 'feat: add Kokoro neural narration assets'"
}

show_help() { sed -n '3,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//'; }

mode="setup"
VOICE=""
VOICE_EXPLICIT=""
FORCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) mode="check" ;;
    --dry-run) mode="dry-run" ;;
    --saturn) mode="saturn" ;;
    --all) mode="all" ;;
    --force) FORCE="--force" ;;
    --list-voices)
      cat <<'VOICES'
  Kokoro voices worth trying for a friendly kids' educational read:

    af_heart    American female, warm and clear   (default)
    af_sarah    American female, bright and upbeat
    am_michael  American male, calm and steady
    am_adam     American male, deeper and slower
    bf_emma     British female, warm
    bf_isabella British female, softer

  Use one with:
    ./tool/setup_kokoro.sh --saturn --voice af_sarah
VOICES
      exit 0 ;;
    --voice)
      shift
      [ $# -gt 0 ] || die "--voice needs a voice name (see --list-voices)"
      case "$1" in
        -*) die "--voice needs a voice name (see --list-voices)" ;;
      esac
      VOICE="$1"
      VOICE_EXPLICIT=1
      ;;
    -h|--help) show_help; exit 0 ;;
    *) die "Unknown option: $1 (try --help)" ;;
  esac
  shift
done

case "$mode" in
  check) do_check ;;
  dry-run) check_python; do_dry_run ;;
  setup) ensure_ready ;;
  saturn|all)
    check_python
    check_venv || { check_brew_tools install; create_venv; install_kokoro; }
    do_generate "$mode" ${FORCE:+$FORCE}
    ;;
esac
