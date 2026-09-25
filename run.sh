#!/usr/bin/env bash
#
# Kidz Planets — one-command runner.
#
#   ./run.sh              interactive menu (default)
#   ./run.sh run [device] run the app (Flutter GPU flag included, required by flutter_scene)
#   ./run.sh test         run logic tests
#   ./run.sh analyze      flutter analyze
#   ./run.sh get          flutter pub get (offline-first, falls back to online)
#   ./run.sh clean        flutter clean + pub get
#   ./run.sh devices      list available devices
#   ./run.sh doctor       flutter doctor
#   ./run.sh build-macos  release build for macOS
#   ./run.sh build-web    release build for web
#   ./run.sh build-apk    release build for Android
#   ./run.sh format       dart format lib test
#   ./run.sh help         this help
#
# Extra args after the command are passed through, e.g.:
#   ./run.sh run -d chrome --verbose
#
set -euo pipefail
cd "$(dirname "$0")"

# flutter_scene renders through Flutter GPU — this flag is REQUIRED.
GPU_FLAG="--enable-flutter-gpu"
TEST_FILE="test/explorer_logic_test.dart"

need_flutter() {
  if ! command -v flutter >/dev/null 2>&1; then
    echo "ERROR: 'flutter' not found on PATH."
    echo "Install it from https://docs.flutter.dev/get-started/install then re-run."
    exit 1
  fi
}

do_get() {
  need_flutter
  echo "==> flutter pub get (offline first)…"
  flutter pub get --offline 2>/dev/null || flutter pub get
}

do_analyze() {
  need_flutter
  echo "==> flutter analyze…"
  flutter analyze --no-pub
}

do_test() {
  need_flutter
  echo "==> flutter test $TEST_FILE…"
  flutter test --no-pub "$TEST_FILE"
}

do_run() {
  need_flutter
  # "$@" = optional device id + any extra flutter run flags.
  echo "==> flutter run $GPU_FLAG $*"
  # shellcheck disable=SC2086
  flutter run $GPU_FLAG "$@"
}

do_devices() { need_flutter; flutter devices; }
do_doctor() { need_flutter; flutter doctor; }

do_clean() {
  need_flutter
  echo "==> flutter clean…"
  flutter clean
  do_get
}

do_format() {
  need_flutter
  dart format lib test
}

do_build() {
  need_flutter
  case "${1:-}" in
    macos) shift; flutter build macos "$@" ;;
    web)   shift; flutter build web "$@" ;;
    apk)   shift; flutter build apk "$@" ;;
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
  echo "  7) Doctor                  8) Clean + get"
  echo "  0) Exit"
  echo ""
  read -r -p "  Pick [0-8]: " choice
  case "$choice" in
    1) do_run ;;
    2) do_run -d macos ;;
    3) do_run -d chrome ;;
    4) do_test ;;
    5) do_analyze ;;
    6) do_devices ;;
    7) do_doctor ;;
    8) do_clean ;;
    0) exit 0 ;;
    *) echo "Unknown option: $choice"; exit 1 ;;
  esac
}

cmd="${1:-menu}"
case "$cmd" in
  menu) show_menu ;;
  run) shift; do_run "$@" ;;
  test) shift; do_test "$@" ;;
  analyze) do_analyze ;;
  get) do_get ;;
  clean) do_clean ;;
  devices) do_devices ;;
  doctor) do_doctor ;;
  format) do_format ;;
  build-macos) shift; do_build macos "$@" ;;
  build-web) shift; do_build web "$@" ;;
  build-apk) shift; do_build apk "$@" ;;
  help|-h|--help) show_help ;;
  *) echo "Unknown command: $cmd"; echo ""; show_help; exit 1 ;;
esac
