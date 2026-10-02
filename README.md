# Kidz Planets — Space Explorer

An interactive **true-3D** solar system for young explorers, ported from
`prototype/index.html` to Flutter. **No WebView** — planets, the Sun and the
rocket companion are rendered with `flutter_scene` (SceneView + imperative Scene
graph + `Texture2D` planet textures).

## Run

```sh
bash run.sh            # interactive menu
bash run.sh run        # run the app (auto device)
bash run.sh run -d macos    # run on macOS desktop
bash run.sh run -d chrome   # run on Chrome (web)
bash run.sh test       # run every package's tests
bash run.sh check      # deps + format + analyze + test, the pre-commit gate
bash run.sh analyze    # analyze every package
bash run.sh devices    # list devices
bash run.sh clean      # clean + bootstrap
```

> `run.sh` always passes `--enable-flutter-gpu` (required by flutter_scene).
> Use `bash run.sh …` — direct `./run.sh` may say "Permission denied" on a
> fresh checkout; run `chmod +x run.sh` once to fix that.

Flutter GPU is REQUIRED by flutter_scene (already enabled per-platform in
this repo: Android manifest, iOS/macOS Info.plist, Linux + Windows runners).
Textures live in `apps/kidz_planets/assets/textures/` and load via
`Texture2D.fromAsset` — no buildTextures/.fstex pipeline needed.

## Architecture

A Melos workspace: one dependency resolution at the root, five packages that
each own one slice of the product, and an app that composes them.

```text
apps/kidz_planets/       the runnable app: composition root, screens, assets
packages/core/           localization, theme, screen metrics, simulation clock
packages/planets/        catalogue, scene, explorer, planet audio (incl. moons)
packages/avatar/         the 3D companion: physics, expressions, sound
packages/mission/        curriculum, grading, hints, celebration
```

The dependency direction is the architecture:

```text
kidz_planets -> {planets, avatar, mission, core}
feature     -> core
```

A feature package may import `core` and nothing else. Nothing imports the app.
`melos run check:deps` enforces this by scanning every `lib/` in the workspace,
because a single well-meaning import is how a boundary quietly disappears.

What that buys, concretely:

- **Explorer state is the planets package's.** `ExplorerController` owns the
  camera, transport and selection. It knows nothing about missions.
- **Grading is the app's.** `appShellProvider` watches the explorer for a new
  selection and asks the mission feature whether that tap was the mission
  target. Only the composition root is allowed to know about two features at
  once, and it does it by watching rather than by reaching into either package.
- **Mood is the app's too.** The avatar decides what a mood looks and sounds
  like; the shell decides *why* the companion is celebrating, because that
  answer lives in the mission package.
- **Cross-feature UI is a callback.** `PlanetsGridPanel` and `MissionsPanel`
  take `onDismiss` / `onOpenMission` and know nothing about tabs.
- **Copy resolves through a port.** Core owns the message templates but not the
  body catalogue they name, so the app injects a `BodyNameResolver`.

Two notes on things that are deliberately where they are:

- **Moons are part of `planets`.** They share the `Planet` entity, the orbit
  camera and the solar-system scene; a separate package would either duplicate
  that or force a leaky API into the scene builder.
- **Localization is generated into `core`.** Every feature package resolves
  copy, and a generated delegate cannot be imported from the app without making
  `core` depend on the app. `melos run gen` regenerates it from
  `packages/core/lib/src/l10n/arb/`.

### State and services

- **Riverpod** owns reactive state: everything a widget can watch.
- **GetIt** owns process-wide singletons: the configured `AudioSession` and the
  two audio players that must be one instance app-wide
  (`apps/kidz_planets/lib/dependency_injection/injection.dart`). The app
  overrides the planets package's own audio providers with those singletons in
  `main`, so narration and the mission celebration cue are one voice rather
  than two crossfading players.

The split is deliberate: a service registered as reactive state gets two
lifetimes, and then the app has to answer which one a widget is holding.

### Assets

Only the app bundles assets, and every pubspec entry is package-relative. A
path written as `../../assets/...` keeps the `../../` in the bundle key, and
nothing asking for `assets/textures/earth.png` would find it.

`flutter_scene` compiles GLBs through `apps/kidz_planets/hook/build.dart` into
`flutter_scene_generated/`, which is build output and must never be a package.

## Tests

```sh
melos run test                       # every package
melos run check                      # deps, format, analyze and test
cd packages/planets && flutter test test/explorer_logic_test.dart
```

Tests live next to the code they cover: `packages/planets/test` for the
explorer, scene and translations, `packages/avatar/test` for the companion,
`packages/mission/test` for the curriculum, `packages/core/test` for
localization and the clock, and `apps/kidz_planets/test` for the composition
itself — the shell, the overlays and the cross-package translation guard.

## Added libraries

flutter_scene (3D), flutter_riverpod (state), get_it (service locator),
equatable (value equality), vector_math (3D math), just_audio + audio_session
(sound), intl (localization), cupertino_icons, collection.