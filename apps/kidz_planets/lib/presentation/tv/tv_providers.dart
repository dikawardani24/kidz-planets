import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scene/scene.dart';

import 'package:core/platform.dart';
import 'package:planets/audio.dart';
import 'package:planets/scene.dart';
import 'package:planets/state.dart';

import 'tv_explorer_controller.dart';

/// Production [TvSceneOps]: the same scene controller the touch UI drives.
///
/// No second camera, no duplicated planet logic — the TV controller steers the
/// one shared scene through the same methods the gesture handlers call.
class SolarSystemSceneOps implements TvSceneOps {
  SolarSystemSceneOps(this._scene);

  final SolarSystemSceneController _scene;

  @override
  void rotateView(double dxPx, double dyPx) =>
      _scene.rotateSolarSystem(dxPx, dyPx);

  @override
  void rotateObject(String planetId, double dxPx, double dyPx) =>
      _scene.rotatePlanet(planetId, dxPx, dyPx);

  @override
  void pinchTowardBody(double scaleFactor, String planetId) =>
      _scene.pinchTowardBody(scaleFactor, planetId);

  @override
  PerspectiveCamera buildCamera(ExplorerState ui) => _scene.buildCamera(ui);

  @override
  bool shouldAutoEnterDetail(String planetId, PerspectiveCamera camera) =>
      _scene.shouldAutoEnterDetail(planetId, camera);

  @override
  double prepareSeamlessSelection(String planetId, PerspectiveCamera camera) =>
      _scene.prepareSeamlessSelection(planetId, camera);

  @override
  double markZoomProgress(String planetId, PerspectiveCamera camera) =>
      _scene.markZoomProgress(planetId, camera);

  @override
  void cancelZoomFlight() => _scene.cancelZoomFlight();

  @override
  void resetOverview() => _scene.resetOverview();

  @override
  Offset? projectBodyCenter(
    String planetId,
    PerspectiveCamera camera,
    Size viewSize,
  ) => _scene.projectBodyCenter(planetId, camera, viewSize);
}

final tvSceneOpsProvider = Provider<TvSceneOps>((ref) {
  return SolarSystemSceneOps(ref.watch(solarSystemSceneControllerProvider));
});

/// Whether the TV companion currently holds D-pad focus.
///
/// Set by the companion's [TvFocusable] wrapper; read by the remote handler
/// so arrow presses aimed at the rocket are not also treated as explorer
/// input (see the `avatar` input layer).
final tvAvatarFocusedProvider = StateProvider<bool>((ref) => false);

/// Identity of the controller-cluster focus scope (mode/play/help pills).
///
/// Owned here so the BACK shuttle can find the cluster and re-seat focus
/// into it, and back out to the scene scope, without either side reaching
/// into the other's widget tree.
final tvChromeScopeProvider = Provider<FocusScopeNode>((ref) {
  final node = FocusScopeNode(debugLabel: 'tvChrome');
  ref.onDispose(node.dispose);
  return node;
});

/// The remote-first explorer driver, in catalogue order.
///
/// One instance per container, like the explorer itself; the touch UI never
/// touches it and it never touches the touch UI — both operate on the shared
/// [ExplorerController] state.
final tvExplorerControllerProvider =
    StateNotifierProvider<TvExplorerController, TvExplorerUiState>((ref) {
      final controller = TvExplorerController(
        explorer: ref.watch(explorerControllerProvider.notifier),
        scene: ref.watch(tvSceneOpsProvider),
        bodyIds: ref.watch(planetsProvider).map((p) => p.id).toList(),
        replayNarration: (planetId) {
          final planet = ref.read(planetByIdProvider(planetId));
          ref.read(planetNarrationServiceProvider).speakPlanet(planet);
        },
      );
      // Selection transitions steer the D-pad mode no matter who changed
      // the selection (remote, touch tap, rails button, tab switch):
      // entering detail switches to rotate, leaving returns to browse.
      // Manual toggles persist otherwise — only the transition steers.
      ref.listen<ExplorerState>(explorerControllerProvider, (prev, next) {
        final was = prev?.hasSelection ?? false;
        if (was == next.hasSelection) return;
        controller.setMode(
          next.hasSelection ? TvControlMode.rotate : TvControlMode.browse,
        );
      });
      return controller;
    });
