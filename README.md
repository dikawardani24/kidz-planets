# Kidz Planets — Space Explorer

An interactive **true-3D** solar system for young explorers, ported from
`prototype/index.html` to Flutter. **No WebView** — planets and the Sun are
rendered with `flutter_scene` (SceneView + imperative Scene graph +
Texture2D planet textures).

## Run

```sh
bash run.sh            # interactive menu
bash run.sh run        # run the app (auto device)
bash run.sh run -d macos    # run on macOS desktop
bash run.sh run -d chrome   # run on Chrome (web)
bash run.sh test       # run logic tests
bash run.sh analyze    # flutter analyze
bash run.sh devices    # list devices
bash run.sh clean      # clean + pub get
```

> `run.sh` always passes `--enable-flutter-gpu` (required by flutter_scene).
> Use `bash run.sh …` — direct `./run.sh` may say "Permission denied" on a
> fresh checkout; run `chmod +x run.sh` once to fix that.

Flutter GPU is REQUIRED by flutter_scene (already enabled per-platform in
this repo: Android manifest, iOS/macOS Info.plist, Linux + Windows runners).
Textures live in `assets/textures/` and load via `Texture2D.fromAsset` —
no buildTextures/.fstex pipeline needed.

## Features (prototype parity)

- 3D Sun + 8 textured planets (PBR, studio-environment lit), Saturn ring band,
  starfield dome, orbit path rings
- Orbit simulation with play/pause + 0-3x speed slider
- Drag to orbit, pinch to zoom, tap planet chip / globe to open detail
- Detail mode: drag spins planet (momentum), pinch zooms, camera focuses
- Floating tappable planet labels projected with Camera.worldToScreen
- Planets grid, Missions (auto-complete on visit + toast), glass UI

## Architecture (SOLID)

```text
lib/
  domain/          # entities, repository interface, use-cases
  data/            # PlanetCatalog + LocalDataSource + RepositoryImpl
  application/     # ExplorerState, ExplorerController, SimulationClock
  infrastructure/  # scene/ (builder, animator, rig, controller) + services/
  presentation/    # screens/, widgets/, theme/
```

SRP: one job per file. OCP: extend animator/projector, UI unchanged.
ISP/DIP: narrow interfaces (TextureProvider, SolarSystemSceneController);
widgets depend on providers, never on Node/Texture2D directly.

## Tests

```sh
flutter test test/explorer_logic_test.dart
```

## Added libraries

flutter_scene (3D), flutter_riverpod (state), equatable (value equality),
vector_math (3D math), cupertino_icons, collection.
