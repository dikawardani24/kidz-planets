# Indonesian narration recordings

Drop the Indonesian `.mp3` files here, named to match the English ones
exactly (e.g. `earth.mp3`, `great_red_spot.mp3`).

The audio catalog resolves `assets/audio/narration/id/<group>/<name>.mp3`
first and falls back to the English file when the localized one is absent,
so the app works fully in Indonesian before any recording lands.

Run `flutter test test/asset_integrity_test.dart` to list what is still missing.
