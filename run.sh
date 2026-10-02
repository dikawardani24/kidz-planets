#!/usr/bin/env bash
#
# Kidz Planets — one-command runner.
#
#   ./run.sh              interactive menu (default)
#   ./run.sh run [device] run the app (Flutter GPU flag included, required by flutter_scene)
#   ./run.sh test         run the whole workspace test suite
#   ./run.sh check        deps + format + analyze + test, the pre-commit gate
#   ./run.sh analyze      analyze every package
#   ./run.sh get          melos bootstrap (resolves all packages at once)
#   ./run.sh clean        flutter clean + bootstrap
#   ./run.sh devices      list available devices
#   ./run.sh doctor       flutter doctor
#   ./run.sh narration    generate Kokoro neural narration MP3s (local only)
#   ./run.sh build-macos  release build for macOS
#   ./run.sh build-web    release build for web
#   ./run.sh build-apk    release build for Android
#   ./run.sh format       dart format every package
#   ./run.sh help         this help
#
# Extra args after the command are passed through, e.g.:
#   ./run.sh run -d chrome --verbose
#
set -euo pipefail
cd "$(dirname "$0")"

# The runnable app is a workspace member, so anything that builds or launches
# runs from its own directory; everything else goes through Melos at the root.
APP_DIR="apps/kidz_planets"

# flutter_scene renders through Flutter GPU — this flag is REQUIRED.
GPU_FLAG="--enable-flutter-gpu"

need_flutter() {
  if ! command -v flutter >/dev/null 2>&1; then
    echo "ERROR: 'flutter' not found on PATH."
    echo "Install it from https://docs.flutter.dev/get-started/install then re-run."
    exit 1
  fi
}

need_melos() {
  need_flutter
  # melos is a dev_dependency of the workspace root and lives in the pub
  # cache, which is not on PATH by default.
  export PATH="$PATH:$HOME/.pub-cache/bin"
  if ! command -v melos >/dev/null 2>&1; then
    echo "ERROR: 'melos' not found. Run 'dart pub global activate melos'."
    exit 1
  fi
}

do_get() {
  need_melos
  echo "==> melos bootstrap…"
  melos bootstrap
}

do_analyze() {
  need_melos
  echo "==> melos run analyze…"
  melos run analyze
}

do_format() {
  need_melos
  echo "==> melos run format…"
  melos run format
}

do_test() {
  need_melos
  echo "==> melos run test…"
  melos run test
}

do_check() {
  need_melos
  echo "==> melos run check…"
  melos run check
}

do_run() {
  need_flutter
  # "$@" = optional device id + any extra flutter run flags.
  echo "==> flutter run $GPU_FLAG $*"
  # shellcheck disable=SC2086
  (cd "$APP_DIR" && flutter run $GPU_FLAG "$@")
}

do_devices() { need_flutter; (cd "$APP_DIR" && flutter devices); }
do_doctor() { need_flutter; flutter doctor; }

do_clean() {
  need_melos
  echo "==> flutter clean…"
  (cd "$APP_DIR" && flutter clean)
  do_get
}

do_build() {
  need_flutter
  case "${1:-}" in
    macos) shift; (cd "$APP_DIR" && flutter build macos "$@") ;;
    web)   shift; (cd "$APP_DIR" && flutter build web "$@") ;;
    apk)   shift; (cd "$APP_DIR" && flutter build apk "$@") ;;
    *) echo "Usage: ./run.sh build-macos | build-web | build-apk"; exit 1 ;;
  esac
}

show_help() { sed -n '3,/^# Extra args/p' "$0" | sed 's/^# \{0,1\}//'; }

show_menu() {
  echo ""
  echo "  Kidz Planets — Space Explorer"
  echo "  ============================="
  echo "  1) Run app (auto device)   2) Run on macOS"
  echo "  3) Run on Chrome (web)     4) Run tests"
  echo "  5) Analyze                 6) Devices"
  echo "  7) Doctor                  8) Clean + bootstrap"
  echo "  9) Full check              0) Exit"
  echo ""
  read -r -p "  Pick [0-9]: " choice
  case "$choice" in
    1) do_run ;;
    2) do_run -d macos ;;
    3) do_run -d chrome ;;
    4) do_test ;;
    5) do_analyze ;;
    6) do_devices ;;
    7) do_doctor ;;
    8) do_clean ;;
    9) do_check ;;
    0) exit 0 ;;
    *) echo "Unknown option: $choice"; exit 1 ;;
  esac
}

cmd="${1:-menu}"
case "$cmd" in
  menu) show_menu ;;
  run) shift; do_run "$@" ;;
  test) shift; do_test "$@" ;;
  check) do_check ;;
  analyze) do_analyze ;;
  get) do_get ;;
  clean) do_clean ;;
  devices) do_devices ;;
  doctor) do_doctor ;;
  format) do_format ;;
  build-macos) shift; do_build macos "$@" ;;
  build-web) shift; do_build web "$@" ;;
  build-apk) shift; do_build apk "$@" ;;
  narration)
    shift
    # Kokoro needs Python 3.10-3.12 plus ffmpeg; the helper installs and
    # generates without needing a cloud TTS key.
    exec ./tool/setup_kokoro.sh "$@"
    ;;
  help|-h|--help) show_help ;;
  *) echo "Unknown command: $cmd"; echo ""; show_help; exit 1 ;;
esac
