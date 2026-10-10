import 'package:core/platform.dart';
import 'package:core/time.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets/state.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:kidz_planets/presentation/tv/tv_discovery_graph.dart';
import 'package:kidz_planets/presentation/tv/tv_explorer_controller.dart';

/// Camera-free stand-in for the scene: records flights, never moves.
class _FakeSceneOps implements TvSceneOps {
  final PerspectiveCamera camera = PerspectiveCamera(
    fovRadiansY: 0.85,
    position: vm.Vector3(0, 0, 46),
    target: vm.Vector3(0, 0, 0),
    up: vm.Vector3(0, 1, 0),
  );

  final List<String> flightRequests = [];
  bool flightActive = false;

  @override
  void rotateView(double dxPx, double dyPx) {}

  @override
  void rotateObject(String planetId, double dxPx, double dyPx) {}

  @override
  void pinchTowardBody(double scaleFactor, String planetId) {}

  @override
  PerspectiveCamera buildCamera(ExplorerState ui) => camera;

  @override
  bool shouldAutoEnterDetail(String planetId, PerspectiveCamera camera) =>
      false;

  @override
  double prepareSeamlessSelection(String planetId, PerspectiveCamera camera) =>
      0.8;

  @override
  double markZoomProgress(String planetId, PerspectiveCamera camera) => 0;

  @override
  void cancelZoomFlight() {
    flightActive = false;
  }

  @override
  void resetOverview() {}

  @override
  void startZoomToDetail(String planetId, PerspectiveCamera camera) {
    flightRequests.add(planetId);
    flightActive = true;
  }

  @override
  bool get zoomFlightActive => flightActive;

  @override
  Offset? projectBodyCenter(
    String planetId,
    PerspectiveCamera camera,
    Size viewSize,
  ) => null;
}

TvBackContext _quietBack() => TvBackContext(
  celebrationVisible: false,
  missionsOpen: false,
  closeCelebration: () {},
  exitMissions: () {},
);

void main() {
  const bodies = ['mercury', 'venus', 'earth', 'mars'];

  (ExplorerController, _FakeSceneOps, TvExplorerController) setup({
    List<String> bodyIds = bodies,
    TvDiscoveryGraph? discovery,
  }) {
    final explorer = ExplorerController(clock: SimulationClock());
    final scene = _FakeSceneOps();
    final tv = TvExplorerController(
      explorer: explorer,
      scene: scene,
      bodyIds: bodyIds,
      discovery: discovery,
      selectDebounce: Duration.zero,
    );
    addTearDown(() {
      tv.dispose();
      explorer.dispose();
    });
    return (explorer, scene, tv);
  }

  bool down(
    TvExplorerController tv,
    TvRemoteKey key, [
    TvInputLayer layer = TvInputLayer.explorer,
  ]) => tv.handleKeyDown(key, layer, back: _quietBack());

  TvRegisteredTarget chrome(
    String id,
    Offset center, {
    VoidCallback? onActivate,
  }) => TvRegisteredTarget(
    id: id,
    center: center,
    onActivate: onActivate ?? () {},
  );

  group('focus-mode state model', () {
    test('Planet Mode is the default', () {
      final (_, _, tv) = setup();
      expect(tv.state.chromeFocused, isFalse);
      expect(tv.state.focusMode, TvFocusMode.planet);
    });

    test('focusMode tracks enter/exitChrome without a duplicate flag', () {
      final (_, _, tv) = setup();
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(chrome('chrome:a', const Offset(100, 100)));
      tv.enterChrome();
      expect(tv.state.focusMode, TvFocusMode.menu);
      tv.exitChrome();
      expect(tv.state.focusMode, TvFocusMode.planet);
    });

    test('toggleFocusMode flips both ways', () {
      final (_, _, tv) = setup();
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(chrome('chrome:a', const Offset(100, 100)));
      tv.toggleFocusMode();
      expect(tv.state.focusMode, TvFocusMode.menu);
      tv.toggleFocusMode();
      expect(tv.state.focusMode, TvFocusMode.planet);
    });

    test('switch methods no-op safely when already in the target mode', () {
      final (_, _, tv) = setup();
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(chrome('chrome:a', const Offset(100, 100)));
      tv.switchToPlanet();
      expect(tv.state.focusMode, TvFocusMode.planet);
      tv.switchToMenu();
      tv.switchToMenu();
      expect(tv.state.focusMode, TvFocusMode.menu);
      expect(tv.state.spatialFocusId, 'chrome:a');
    });
  });

  group('Planet Mode discovery', () {
    test('arrows walk planets and stay in Planet Mode', () {
      final (explorer, _, tv) = setup();
      down(tv, TvRemoteKey.right);
      expect(explorer.state.markedTargetId, 'mercury');
      down(tv, TvRemoteKey.right);
      expect(explorer.state.markedTargetId, 'venus');
      expect(tv.state.focusMode, TvFocusMode.planet);
      expect(tv.state.spatialFocusId, 'venus');
    });

    test('a dead-end arrow parks the cursor on the toggle, mark untouched', () {
      final (explorer, scene, tv) = setup();
      down(tv, TvRemoteKey.right);
      expect(explorer.state.markedTargetId, 'mercury');
      // UP from a planet has no parent: dead end in a flat graph.
      down(tv, TvRemoteKey.up);
      expect(tv.state.spatialFocusId, tvModeToggleTargetId);
      // Offering the toggle moves only the cursor: no new mark, no flight,
      // no selection, still Planet Mode.
      expect(explorer.state.markedTargetId, 'mercury');
      expect(explorer.state.hasSelection, isFalse);
      expect(scene.flightRequests, isEmpty);
      expect(tv.state.focusMode, TvFocusMode.planet);
    });
  });

  group('mode switching and restoration', () {
    test('switchToMenu seeds a control and preserves explorer state', () {
      final (explorer, _, tv) = setup();
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(chrome('chrome:near', const Offset(500, 480)));
      tv.registerTarget(chrome('chrome:far', const Offset(50, 50)));
      down(tv, TvRemoteKey.right);
      expect(explorer.state.markedTargetId, 'mercury');

      tv.switchToMenu();

      expect(tv.state.focusMode, TvFocusMode.menu);
      expect(tv.state.spatialFocusId, 'chrome:near');
      // Entering Menu Mode never marks, selects or opens anything.
      expect(explorer.state.markedTargetId, 'mercury');
      expect(explorer.state.hasSelection, isFalse);
    });

    test('switching back to Planet Mode restores the previous body', () {
      final (explorer, _, tv) = setup();
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(chrome('chrome:a', const Offset(100, 100)));
      down(tv, TvRemoteKey.right);
      down(tv, TvRemoteKey.right);
      expect(explorer.state.markedTargetId, 'venus');

      tv.switchToMenu();
      expect(tv.state.spatialFocusId, 'chrome:a');
      tv.switchToPlanet();

      expect(tv.state.focusMode, TvFocusMode.planet);
      expect(tv.state.spatialFocusId, 'venus');
      expect(explorer.state.markedTargetId, 'venus');
    });

    test('switching back to Menu Mode restores the previous UI target', () {
      final (_, _, tv) = setup();
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(chrome('chrome:first', const Offset(100, 100)));
      tv.registerTarget(chrome('chrome:second', const Offset(500, 500)));

      tv.switchToMenu();
      // Nearest to the viewport centre seeds first.
      expect(tv.state.spatialFocusId, 'chrome:second');
      // Walk to the other control, leave, come back: the remembered one wins
      // over the nearest seed.
      tv.updateSpatialFocusForTest('chrome:first');
      tv.switchToPlanet();
      tv.switchToMenu();
      expect(tv.state.spatialFocusId, 'chrome:first');
    });

    test('a disposed menu target falls back safely', () {
      final (_, _, tv) = setup();
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(chrome('chrome:gone', const Offset(500, 500)));
      tv.registerTarget(chrome('chrome:stays', const Offset(100, 900)));

      tv.switchToMenu();
      expect(tv.state.spatialFocusId, 'chrome:gone');
      tv.switchToPlanet();
      tv.unregisterTarget('chrome:gone');

      // The remembered target is gone: re-entry lands on a live control,
      // never on a stale id, and never throws.
      tv.switchToMenu();
      expect(tv.state.focusMode, TvFocusMode.menu);
      expect(tv.state.spatialFocusId, 'chrome:stays');
    });

    test('an unknown remembered planet falls back to a valid body', () {
      final (explorer, _, tv) = setup(
        discovery: TvDiscoveryGraph.fromIds(const ['a', 'b']),
      );
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(chrome('chrome:a', const Offset(100, 100)));
      down(tv, TvRemoteKey.right);
      expect(explorer.state.markedTargetId, 'a');

      tv.switchToMenu();
      // Simulate the catalogue changing under the remembered cursor: the
      // next Planet Mode entry must land on a known body, not the stale id.
      tv.switchToPlanet();
      expect(tv.state.focusMode, TvFocusMode.planet);
      expect(tv.state.spatialFocusId, isNotNull);
    });

    test('switching modes never fires chrome activations or opens detail', () {
      final (explorer, _, tv) = setup();
      var calls = 0;
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(
        chrome('chrome:a', const Offset(100, 100), onActivate: () => calls++),
      );
      down(tv, TvRemoteKey.right);

      tv.switchToMenu();
      tv.switchToPlanet();
      tv.switchToMenu();
      tv.switchToPlanet();

      expect(calls, 0);
      expect(explorer.state.hasSelection, isFalse);
      expect(explorer.state.markedTargetId, 'mercury');
    });

    test('rapid repeated toggles never strand a stale cursor', () {
      final (explorer, _, tv) = setup();
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(chrome('chrome:a', const Offset(100, 100)));
      tv.registerTarget(
        TvRegisteredTarget(
          id: tvModeToggleTargetId,
          center: const Offset(900, 100),
          onActivate: () => tv.toggleFocusMode(),
        ),
      );
      down(tv, TvRemoteKey.right);

      for (var i = 0; i < 10; i++) {
        tv.toggleFocusMode();
      }

      // Even count returns to Planet Mode on the remembered body.
      expect(tv.state.focusMode, TvFocusMode.planet);
      expect(tv.state.spatialFocusId, 'mercury');
      expect(explorer.state.markedTargetId, 'mercury');
      expect(explorer.state.hasSelection, isFalse);

      tv.toggleFocusMode();
      expect(tv.state.focusMode, TvFocusMode.menu);
      expect(tv.state.spatialFocusId, 'chrome:a');
    });

    test('switchToPlanet keeps an open detail view open', () {
      final (explorer, _, tv) = setup();
      tv.updateViewportSize(const Size(1000, 1000));
      tv.registerTarget(chrome('chrome:a', const Offset(100, 100)));
      explorer.selectPlanet('earth');
      tv.enterChrome(preferId: 'chrome:a');

      tv.switchToPlanet();

      expect(tv.state.focusMode, TvFocusMode.planet);
      expect(explorer.state.selectedPlanetId, 'earth');
    });
  });
}
