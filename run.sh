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
#   ./run.sh build-apk [--debug] [--split]   Android APK, release (default) or
#                                             debug; --split emits per-ABI APKs.
#                                             One APK installs on phone, tablet
#                                             and TV (leanback launcher included)
#   ./run.sh install-apk [-d SERIAL] [apk]    adb install onto the connected
#                                             Android phone or TV (-r reinstall,
#                                             keeps data). Pair a TV first with
#                                             `adb connect <TV-IP>:5555`
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
    apk)   shift; do_build_apk "$@" ;;
    *) echo "Usage: ./run.sh build-macos | build-web | build-apk [--debug] [--split]"; exit 1 ;;
  esac
}

# Android APK for phone, tablet and TV: the manifest carries both the phone
# LAUNCHER and the TV LEANBACK_LAUNCHER, so one artifact installs everywhere.
# Defaults to a universal release APK; --debug builds debuggable output and
# --split emits one smaller APK per ABI (most TVs want the arm64 split).
do_build_apk() {
  local mode="--release" split="" extra=()
  for arg in "$@"; do
    case "$arg" in
      --debug) mode="--debug" ;;
      --release) mode="--release" ;;
      --split) split="--split-per-abi" ;;
      -h|--help)
        echo "Usage: ./run.sh build-apk [--debug] [--split] [flutter build apk args…]"
        return 0 ;;
      *) extra+=("$arg") ;;
    esac
  done
  echo "==> flutter build apk $mode $split${extra[@]+ ${extra[*]}}"
  # shellcheck disable=SC2086
  if [ "${#extra[@]}" -eq 0 ]; then
    (cd "$APP_DIR" && flutter build apk $mode $split)
  else
    (cd "$APP_DIR" && flutter build apk $mode $split "${extra[@]}")
  fi
  echo ""
  echo "APK(s) in $APP_DIR/build/app/outputs/flutter-apk/"
  echo "Install onto a phone or TV with: ./run.sh install-apk [-d SERIAL]"
}

# Installs an APK onto the connected Android phone or TV via adb.
# With no path given, prefers the universal release build, then debug.
# With several devices attached, -d SERIAL picks the target
# (see ./run.sh devices, or `adb devices`; pair a TV with
# `adb connect <TV-IP>:5555` first).
do_install_apk() {
  local serial="" apk=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -d|--device) serial="${2:-}"; shift 2 ;;
      -h|--help)
        echo "Usage: ./run.sh install-apk [-d SERIAL] [path-to.apk]"
        return 0 ;;
      *) apk="$1"; shift ;;
    esac
  done
  if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: 'adb' not found on PATH. Install the Android platform-tools."
    exit 1
  fi
  if [ -z "$apk" ]; then
    for candidate in \
      "$APP_DIR/build/app/outputs/flutter-apk/app-release.apk" \
      "$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"; do
      if [ -f "$candidate" ]; then apk="$candidate"; break; fi
    done
  fi
  if [ -z "$apk" ] || [ ! -f "$apk" ]; then
    echo "ERROR: no APK found. Build one first: ./run.sh build-apk [--debug] [--split]"
    exit 1
  fi
  if [ -z "$serial" ]; then
    local attached
    attached="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
    local count
    count="$(printf '%s\n' "$attached" | grep -c . || true)"
    if [ "$count" -ne 1 ]; then
      echo "ERROR: $count usable device(s) attached; pick one with -d SERIAL."
      echo "$attached" | sed 's/^/  /'
      echo "Tip: ./run.sh devices  (flutter) or: adb connect <TV-IP>:5555"
      exit 1
    fi
    serial="$attached"
  fi
  echo "==> adb -s $serial install -r $apk"
  adb -s "$serial" install -r "$apk"
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
  echo "  9) Full check              10) Build APK (release, phone+TV)"
  echo "  11) Build APK (debug)      12) Install APK to phone/TV"
  echo "  0) Exit"
  echo ""
  read -r -p "  Pick [0-12]: " choice
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
    10) do_build_apk ;;
    11) do_build_apk --debug ;;
    12)
      read -r -p "  Device serial (empty = auto-detect): " serial
      if [ -n "$serial" ]; then
        do_install_apk -d "$serial"
      else
        do_install_apk
      fi
      ;;
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
  install-apk) shift; do_install_apk "$@" ;;
  narration)
    shift
    # Kokoro needs Python 3.10-3.12 plus ffmpeg; the helper installs and
    # generates without needing a cloud TTS key.
    exec ./tool/setup_kokoro.sh "$@"
    ;;
  help|-h|--help) show_help ;;
  *) echo "Unknown command: $cmd"; echo ""; show_help; exit 1 ;;
esac
