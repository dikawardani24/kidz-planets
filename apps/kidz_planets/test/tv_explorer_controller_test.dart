import 'package:core/platform.dart';
import 'package:core/time.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets/state.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:kidz_planets/presentation/tv/tv_discovery_graph.dart';
import 'package:kidz_planets/presentation/tv/tv_explorer_controller.dart';

/// Camera-free stand-in for the scene: records motion, scripts thresholds.
class FakeSceneOps implements TvSceneOps {
  final PerspectiveCamera camera = PerspectiveCamera(
    fovRadiansY: 0.85,
    position: vm.Vector3(0, 0, 46),
    target: vm.Vector3(0, 0, 0),
    up: vm.Vector3(0, 1, 0),
  );

  final List<(double, double)> viewRotations = [];
  final List<(String, double, double)> objectRotations = [];
  final List<(double, String)> pinches = [];

  /// Bodies OK asked to visit, in order: the smooth flight requests.
  final List<String> flightRequests = [];
  bool flightActive = false;
  int cancelFlights = 0;
  int resets = 0;

  bool autoEnter = false;
  double progress = 0;
  double seamlessZoom = 0.8;

  @override
  void rotateView(double dxPx, double dyPx) => viewRotations.add((dxPx, dyPx));

  @override
  void rotateObject(String planetId, double dxPx, double dyPx) =>
      objectRotations.add((planetId, dxPx, dyPx));

  @override
  void pinchTowardBody(double scaleFactor, String planetId) =>
      pinches.add((scaleFactor, planetId));

  @override
  PerspectiveCamera buildCamera(ExplorerState ui) => camera;

  @override
  bool shouldAutoEnterDetail(String planetId, PerspectiveCamera camera) =>
      autoEnter;

  @override
  double prepareSeamlessSelection(String planetId, PerspectiveCamera camera) =>
      seamlessZoom;

  @override
  double markZoomProgress(String planetId, PerspectiveCamera camera) =>
      progress;

  @override
  void cancelZoomFlight() {
    cancelFlights++;
    flightActive = false;
  }

  @override
  void resetOverview() => resets++;

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

TvBackContext quietBack({
  bool celebrationVisible = false,
  bool missionsOpen = false,
  void Function()? onCloseCelebration,
  void Function()? onExitMissions,
}) => TvBackContext(
  celebrationVisible: celebrationVisible,
  missionsOpen: missionsOpen,
  closeCelebration: onCloseCelebration ?? () {},
  exitMissions: onExitMissions ?? () {},
);

void main() {
  const bodies = ['mercury', 'venus', 'earth', 'mars'];

  (ExplorerController, FakeSceneOps, TvExplorerController) setup({
    List<String> bodyIds = bodies,
    Duration selectDebounce = Duration.zero,
    Duration chromeTimeout = const Duration(seconds: 4),
    TvDiscoveryGraph? discovery,
  }) {
    final explorer = ExplorerController(clock: SimulationClock());
    final scene = FakeSceneOps();
    final narrated = <String>[];
    final tv = TvExplorerController(
      explorer: explorer,
      scene: scene,
      bodyIds: bodyIds,
      discovery: discovery,
      replayNarration: narrated.add,
      selectDebounce: selectDebounce,
      chromeTimeout: chromeTimeout,
    );
    addTearDown(() {
      tv.dispose();
      explorer.dispose();
    });
    return (explorer, scene, tv);
  }

  /// Graph mirroring the catalogue shape: primaries in orbit order with the
  /// real parent<->moon families attached.
  TvDiscoveryGraph moonGraph() => TvDiscoveryGraph(
    primaries: const ['sun', 'earth', 'mars', 'jupiter', 'saturn'],
    childrenByParent: const {
      'earth': ['moon'],
      'mars': ['phobos', 'deimos'],
      'jupiter': ['io', 'europa', 'ganymede', 'callisto'],
    },
    parentById: const {
      'sun': null,
      'earth': null,
      'mars': null,
      'jupiter': null,
      'saturn': null,
      'moon': 'earth',
      'phobos': 'mars',
      'deimos': 'mars',
      'io': 'jupiter',
      'europa': 'jupiter',
      'ganymede': 'jupiter',
      'callisto': 'jupiter',
    },
  );

  bool down(
    TvExplorerController tv,
    TvRemoteKey key,
    TvInputLayer layer, {
    TvBackContext? back,
    bool isRepeat = false,
  }) => tv.handleKeyDown(
    key,
    layer,
    back: back ?? quietBack(),
    isRepeat: isRepeat,
  );

  group('object navigation (browse mode)', () {
    test('LEFT/RIGHT moves the mark and wraps around', () {
      final (explorer, _, tv) = setup();
      expect(down(tv, TvRemoteKey.right, TvInputLayer.explorer), isTrue);
      expect(explorer.state.markedTargetId, 'mercury');
      expect(down(tv, TvRemoteKey.right, TvInputLayer.explorer), isTrue);
      expect(explorer.state.markedTargetId, 'venus');
      expect(down(tv, TvRemoteKey.left, TvInputLayer.explorer), isTrue);
      expect(explorer.state.markedTargetId, 'mercury');
      expect(down(tv, TvRemoteKey.left, TvInputLayer.explorer), isTrue);
      expect(explorer.state.markedTargetId, 'mars');
    });

    test('repeats keep stepping the cursor', () {
      final (explorer, _, tv) = setup();
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      down(tv, TvRemoteKey.right, TvInputLayer.explorer, isRepeat: true);
      expect(explorer.state.markedTargetId, 'venus');
    });

    test('OK visits the target with one smooth flight, no two-step mark', () {
      final (explorer, scene, tv) = setup();
      // First OK: parks on the first discovery and starts the flight.
      down(tv, TvRemoteKey.center, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'mercury');
      expect(scene.flightRequests, ['mercury']);
      expect(explorer.state.hasSelection, isFalse);
      // The scene tick finishes the flight by opening detail at the reached
      // distance (simulated here); the child never sees a mark/select split.
      explorer.selectPlanet('mercury');
      expect(explorer.state.selectedPlanetId, 'mercury');
    });

    test('OK on a selection re-speaks instead of leaving detail', () {
      final (explorer, _, tv) = setup();
      explorer.selectPlanet('earth');
      down(tv, TvRemoteKey.center, TvInputLayer.explorer);
      expect(explorer.state.selectedPlanetId, 'earth');
    });

    test('rapid double OK starts exactly one flight', () {
      final (explorer, scene, tv) = setup(
        selectDebounce: const Duration(seconds: 10),
      );
      down(tv, TvRemoteKey.center, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'mercury');
      expect(scene.flightRequests, ['mercury']);
      // The follow-up press lands inside the debounce window, so no second
      // flight fires: one press, one outcome.
      down(tv, TvRemoteKey.center, TvInputLayer.explorer);
      expect(scene.flightRequests, ['mercury']);
      expect(explorer.state.hasSelection, isFalse);
    });

    test('detail LEFT/RIGHT switches the detailed body', () {
      final (explorer, scene, tv) = setup();
      explorer.selectPlanet('earth');
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      expect(explorer.state.selectedPlanetId, 'mars');
      expect(scene.cancelFlights, greaterThanOrEqualTo(1));
      down(tv, TvRemoteKey.left, TvInputLayer.explorer);
      expect(explorer.state.selectedPlanetId, 'earth');
    });
  });

  group('discovery relationships (moons via their planet)', () {
    test('LEFT/RIGHT walks primaries in orbit order', () {
      final (explorer, _, tv) = setup(discovery: moonGraph());
      explorer.markTarget('sun');
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'earth');
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'mars');
    });

    test('DOWN enters the first moon, UP returns to the parent', () {
      final (explorer, _, tv) = setup(discovery: moonGraph());
      explorer.markTarget('earth');
      down(tv, TvRemoteKey.down, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'moon');
      down(tv, TvRemoteKey.up, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'earth');
    });

    test('DOWN tours a moon family, sideways steps between siblings', () {
      final (explorer, _, tv) = setup(discovery: moonGraph());
      explorer.markTarget('jupiter');
      down(tv, TvRemoteKey.down, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'io');
      down(tv, TvRemoteKey.down, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'europa');
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'ganymede');
      down(tv, TvRemoteKey.left, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'europa');
      down(tv, TvRemoteKey.up, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'jupiter');
    });

    test('no meaningful relation means stay, never jump to UI', () {
      final (explorer, scene, tv) = setup(discovery: moonGraph());
      tv.registerTarget(
        TvRegisteredTarget(
          id: 'chrome:play-pause',
          center: const Offset(100, 1900),
          onActivate: () {},
        ),
      );
      // UP from a planet and DOWN from a moonless... Saturn has no moons in
      // this graph, and a lone moon has no sideways sibling.
      explorer.markTarget('mars');
      down(tv, TvRemoteKey.up, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'mars');
      explorer.markTarget('moon');
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'moon');
      down(tv, TvRemoteKey.down, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'moon');
      // Staying put never lands on chrome.
      expect(tv.state.spatialFocusId, isNot('chrome:play-pause'));
      expect(scene.pinches, isEmpty);
    });

    test('OK on a moon visits the moon itself', () {
      final (explorer, scene, tv) = setup(discovery: moonGraph());
      explorer.markTarget('earth');
      down(tv, TvRemoteKey.down, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'moon');
      down(tv, TvRemoteKey.center, TvInputLayer.explorer);
      expect(scene.flightRequests.last, 'moon');
    });
  });

  group('spatial navigation (discovery owns the D-pad)', () {
    test('LEFT/RIGHT moves the cursor; UP/DOWN without relations stays', () {
      final (explorer, scene, tv) = setup();
      explorer.markTarget('earth');
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'mars');
      // No parent/child relations in a flat list: UP/DOWN stay put instead
      // of jumping somewhere unrelated.
      down(tv, TvRemoteKey.down, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'mars');
      down(tv, TvRemoteKey.up, TvInputLayer.explorer);
      expect(explorer.state.markedTargetId, 'mars');
      tv.advance(1 / 60);
      expect(scene.pinches, isEmpty);
      expect(scene.viewRotations, isEmpty);
    });

    test('discovery navigation never focuses chrome controls', () {
      final (explorer, _, tv) = setup();
      var calls = 0;
      tv.registerTarget(
        TvRegisteredTarget(
          id: 'chrome:zoom-in',
          center: const Offset(100, 100),
          onActivate: () => calls++,
        ),
      );
      explorer.markTarget('earth');
      for (final key in TvRemoteKey.values) {
        if (key == TvRemoteKey.center ||
            key == TvRemoteKey.back ||
            key == TvRemoteKey.playPause) {
          continue;
        }
        down(tv, key, TvInputLayer.explorer);
        expect(tv.state.spatialFocusId, isNot('chrome:zoom-in'));
      }
      expect(calls, 0);
      // Discovery OK visits the body; it never fires chrome activations.
      down(tv, TvRemoteKey.center, TvInputLayer.explorer);
      expect(calls, 0);
      expect(explorer.state.markedTargetId, isNot('chrome:zoom-in'));
    });

    test('selecting a planet never enters rotate mode', () {
      final (explorer, _, tv) = setup();
      expect(tv.state.mode, TvControlMode.browse);
      explorer.selectPlanet('earth');
      expect(tv.state.mode, TvControlMode.browse);
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      expect(tv.state.mode, TvControlMode.browse);
    });

    test('OK on a chrome target fires only in the UI layer', () {
      final (explorer, _, tv) = setup();
      var calls = 0;
      tv.registerTarget(
        TvRegisteredTarget(
          id: 'chrome:zoom-in',
          center: const Offset(100, 100),
          onActivate: () => calls++,
        ),
      );
      explorer.markTarget('earth');
      tv.updateSpatialFocusForTest('chrome:zoom-in');
      // Discovery owns the D-pad: OK visits the body, chrome stays silent.
      down(tv, TvRemoteKey.center, TvInputLayer.explorer);
      expect(calls, 0);
      // The UI layer owns chrome: OK fires its activation, not body logic.
      explorer.closeDetail();
      tv.enterChrome();
      tv.updateSpatialFocusForTest('chrome:zoom-in');
      down(tv, TvRemoteKey.center, TvInputLayer.explorer);
      expect(calls, 1);
      expect(explorer.state.hasSelection, isFalse);
    });

    test('BACK leaves the UI layer before anything else behind it', () {
      final (_, _, tv) = setup();
      tv.enterChrome();
      expect(tv.state.chromeFocused, isTrue);
      expect(tv.handleBack(quietBack()), TvBackOutcome.exitedChrome);
      expect(tv.state.chromeFocused, isFalse);
      expect(tv.handleBack(quietBack()), TvBackOutcome.unhandled);
    });

    test('quiet controls fade after inactivity and return on input', () async {
      final (_, _, tv) = setup(chromeTimeout: const Duration(milliseconds: 20));
      expect(tv.state.chromeVisible, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(tv.state.chromeVisible, isFalse);
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      expect(tv.state.chromeVisible, isTrue);
    });
  });

  group('rotation', () {
    test('browse arrows never rotate', () {
      final (_, scene, tv) = setup();
      down(tv, TvRemoteKey.left, TvInputLayer.explorer);
      down(tv, TvRemoteKey.up, TvInputLayer.explorer);
      tv.advance(0.5);
      expect(scene.viewRotations, isEmpty);
      tv.handleKeyUp(TvRemoteKey.left);
      tv.handleKeyUp(TvRemoteKey.up);
    });

    test('held direction in rotate mode spins up and glides to a stop', () {
      final (_, scene, tv) = setup();
      tv.setMode(TvControlMode.rotate);
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      tv.advance(1 / 60);
      tv.advance(1 / 60);
      expect(scene.viewRotations.length, 2);
      // Accelerating: the second step covers more ground than the first.
      expect(
        scene.viewRotations[1].$1.abs(),
        greaterThan(scene.viewRotations[0].$1.abs()),
      );
      // Capped: even a long hold never exceeds the speed cap per frame.
      tv.advance(5);
      final capped = scene.viewRotations.last.$1.abs();
      expect(
        capped,
        lessThanOrEqualTo(TvExplorerController.maxRotationSpeed * 0.05 + 1),
      );
      // Released: motion decays instead of halting mid-glide.
      tv.handleKeyUp(TvRemoteKey.right);
      final atRelease = scene.viewRotations.length;
      tv.advance(1 / 60);
      expect(scene.viewRotations.length, atRelease + 1);
      tv.advance(10);
      final settled = scene.viewRotations.length;
      tv.advance(10);
      expect(scene.viewRotations.length, settled);
    });

    test('rotation steers the selected body in detail', () {
      final (explorer, scene, tv) = setup();
      explorer.selectPlanet('mars');
      tv.setMode(TvControlMode.rotate);
      down(tv, TvRemoteKey.up, TvInputLayer.explorer);
      tv.advance(1 / 60);
      expect(scene.objectRotations, isNotEmpty);
      expect(scene.objectRotations.first.$1, 'mars');
      expect(scene.viewRotations, isEmpty);
      tv.handleKeyUp(TvRemoteKey.up);
    });

    test('switching mode drops held keys', () {
      final (_, scene, tv) = setup();
      tv.setMode(TvControlMode.rotate);
      down(tv, TvRemoteKey.right, TvInputLayer.explorer);
      tv.setMode(TvControlMode.browse);
      tv.advance(1.0);
      expect(scene.viewRotations, isEmpty);
    });
  });

  group('play/pause', () {
    test('toggles the simulation clock, repeats ignored', () {
      final (explorer, _, tv) = setup();
      expect(explorer.state.running, isTrue);
      expect(down(tv, TvRemoteKey.playPause, TvInputLayer.explorer), isTrue);
      expect(explorer.state.running, isFalse);
      expect(
        down(tv, TvRemoteKey.playPause, TvInputLayer.explorer, isRepeat: true),
        isTrue,
      );
      expect(explorer.state.running, isFalse);
    });

    test('works from any layer', () {
      final (explorer, _, tv) = setup();
      expect(down(tv, TvRemoteKey.playPause, TvInputLayer.modal), isTrue);
      expect(explorer.state.running, isFalse);
    });
  });

  group('input priority', () {
    test('dialog open: arrows and OK go to the dialog, BACK closes it', () {
      final (_, _, tv) = setup();
      var closed = 0;
      final back = quietBack(
        celebrationVisible: true,
        onCloseCelebration: () => closed++,
      );
      expect(
        down(tv, TvRemoteKey.left, TvInputLayer.modal, back: back),
        isFalse,
      );
      expect(
        down(tv, TvRemoteKey.center, TvInputLayer.modal, back: back),
        isFalse,
      );
      expect(
        down(tv, TvRemoteKey.back, TvInputLayer.modal, back: back),
        isTrue,
      );
      expect(closed, 1);
    });

    test('mission open: explorer ignores the D-pad', () {
      final (explorer, _, tv) = setup();
      expect(down(tv, TvRemoteKey.right, TvInputLayer.mission), isFalse);
      expect(explorer.state.markedTargetId, isNull);
      expect(down(tv, TvRemoteKey.back, TvInputLayer.mission), isFalse);
    });

    test('avatar focused: arrows yield to the companion', () {
      final (explorer, _, tv) = setup();
      expect(down(tv, TvRemoteKey.left, TvInputLayer.avatar), isFalse);
      expect(explorer.state.markedTargetId, isNull);
    });
  });

  group('BACK hierarchy', () {
    test('celebration > detail > mark > missions > unhandled', () {
      final (explorer, _, tv) = setup();
      var celebrations = 0;
      var exits = 0;

      // Detail first.
      explorer.selectPlanet('earth');
      expect(tv.handleBack(quietBack()), TvBackOutcome.closedDetail);
      expect(explorer.state.hasSelection, isFalse);

      // Then the mark.
      explorer.markTarget('mars');
      expect(tv.handleBack(quietBack()), TvBackOutcome.clearedMark);
      expect(explorer.state.markedTargetId, isNull);

      // Then missions.
      expect(
        tv.handleBack(
          quietBack(missionsOpen: true, onExitMissions: () => exits++),
        ),
        TvBackOutcome.exitedMissions,
      );
      expect(exits, 1);

      // Celebration outranks all of it.
      explorer.selectPlanet('earth');
      explorer.markTarget('mars');
      expect(
        tv.handleBack(
          quietBack(
            celebrationVisible: true,
            missionsOpen: true,
            onCloseCelebration: () => celebrations++,
          ),
        ),
        TvBackOutcome.dismissedCelebration,
      );
      expect(celebrations, 1);
      expect(explorer.state.hasSelection, isTrue);

      // The win stays selected behind the dialog: BACK unwinds it first.
      expect(tv.handleBack(quietBack()), TvBackOutcome.closedDetail);
      expect(tv.handleBack(quietBack()), TvBackOutcome.clearedMark);

      // Nothing left to unwind: the system may have it.
      expect(tv.handleBack(quietBack()), TvBackOutcome.unhandled);
    });

    test('held BACK unwinds exactly one layer', () {
      final (explorer, _, tv) = setup();
      explorer.selectPlanet('earth');
      expect(
        tv.handleKeyDown(
          TvRemoteKey.back,
          TvInputLayer.explorer,
          back: quietBack(),
          isRepeat: true,
        ),
        isTrue,
      );
      expect(explorer.state.hasSelection, isTrue);
    });
  });

  group('avatar fallback', () {
    test('OK with the avatar layer but no focus drives the tap equivalent', () {
      final (_, _, tv) = setup();
      var calls = 0;
      expect(
        tv.handleKeyDown(
          TvRemoteKey.center,
          TvInputLayer.avatar,
          back: quietBack(),
          onInteractAvatar: () => calls++,
        ),
        isTrue,
      );
      expect(calls, 1);
    });

    test('repeats never double-fire the avatar fallback', () {
      final (_, _, tv) = setup();
      var calls = 0;
      TvBackContext back = quietBack();
      for (var i = 0; i < 3; i++) {
        tv.handleKeyDown(
          TvRemoteKey.center,
          TvInputLayer.avatar,
          back: back,
          isRepeat: i > 0,
          onInteractAvatar: () => calls++,
        );
      }
      expect(calls, 1);
    });

    test('explorer select never touches the avatar callback', () {
      final (explorer, _, tv) = setup();
      var calls = 0;
      expect(
        tv.handleKeyDown(
          TvRemoteKey.center,
          TvInputLayer.explorer,
          back: quietBack(),
          onInteractAvatar: () => calls++,
        ),
        isTrue,
      );
      expect(calls, 0);
      expect(explorer.state.markedTargetId, isNotNull);
    });
  });

  group('chrome state', () {
    test('mode toggle flips and re-shows the hint', () {
      final (_, _, tv) = setup();
      expect(tv.state.mode, TvControlMode.browse);
      tv.dismissHint();
      expect(tv.state.hintVisible, isFalse);
      tv.toggleMode();
      expect(tv.state.mode, TvControlMode.rotate);
      expect(tv.state.hintVisible, isTrue);
    });

    test('explore starts directly in the solar system, no home menu', () {
      final (_, _, tv) = setup();
      // No category home on TV: the child lands in the system itself.
      expect(tv.state.homeVisible, isFalse);
      tv.showHome();
      expect(tv.state.homeVisible, isTrue);
      tv.dismissHome();
      expect(tv.state.homeVisible, isFalse);
    });

    test('ensureCursor parks on the first body only when empty-handed', () {
      final (explorer, _, tv) = setup();
      tv.ensureCursor();
      expect(explorer.state.markedTargetId, 'mercury');
      explorer.selectPlanet('venus');
      explorer.markTarget('earth');
      tv.ensureCursor();
      expect(explorer.state.markedTargetId, 'earth');
    });

    test('quick select toggles and dismisses on BACK', () {
      final (_, _, tv) = setup();
      expect(tv.state.quickSelectVisible, isFalse);
      tv.toggleQuickSelect();
      expect(tv.state.quickSelectVisible, isTrue);
      expect(tv.handleBack(quietBack()), TvBackOutcome.closedDetail);
      expect(tv.state.quickSelectVisible, isFalse);
    });
  });
}
