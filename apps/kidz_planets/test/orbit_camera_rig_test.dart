import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/infrastructure/scene/orbit_camera_rig.dart';
import 'package:kidz_planets/infrastructure/scene/scene_models.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'helpers/scene_stubs.dart';

/// [OrbitCameraRig.focusOn] eases over 0.82s but clamps any single frame's
/// `deltaSeconds` to 0.05, so settling it takes 17 calls.
const int kFramesToSettleFocus = 17;

void main() {
  late CameraRigState state;
  late OrbitCameraRig rig;

  setUp(() {
    state = CameraRigState();
    rig = OrbitCameraRig(state: state);
  });

  group('orbitBy', () {
    test('a rightward drag decreases theta', () {
      rig.orbitBy(10, 0);
      expect(state.theta, closeTo(-0.08, 1e-12));
    });

    test('a downward drag increases phi', () {
      rig.orbitBy(0, 10);
      expect(state.phi, closeTo(0.32 + 0.05, 1e-12));
    });

    test('clamps phi to stay clear of both poles', () {
      rig.orbitBy(0, 10_000);
      expect(state.phi, 1.25);
      rig.orbitBy(0, -10_000);
      expect(state.phi, -0.15);
    });

    test('leaves theta unclamped so the camera can keep circling', () {
      rig.orbitBy(-100, 0);
      expect(state.theta, closeTo(0.8, 1e-12));
    });
  });

  group('pinch', () {
    test('a scale factor above one zooms out', () {
      rig.pinch(2);
      expect(state.radius, closeTo(23, 1e-12));
    });

    test('a scale factor below one zooms in', () {
      rig.pinch(0.5);
      expect(state.radius, closeTo(OrbitCameraRig.kMaxRadius, 1e-12));
    });

    test('a factor of one is a no-op', () {
      rig.pinch(1);
      expect(state.radius, OrbitCameraRig.kOverviewRadius);
    });

    test('clamps to the max radius', () {
      rig.pinch(0.001);
      expect(state.radius, OrbitCameraRig.kMaxRadius);
    });

    test('clamps to the min radius', () {
      rig.pinch(1000);
      expect(state.radius, OrbitCameraRig.kMinRadius);
    });

    test('a zero or negative factor saturates instead of producing NaN', () {
      rig.pinch(0);
      expect(state.radius, OrbitCameraRig.kMaxRadius);
      rig.pinch(-2);
      expect(state.radius, OrbitCameraRig.kMinRadius);
    });
  });

  group('resetOverview', () {
    test('restores every field of the overview pose', () {
      state
        ..theta = 1.5
        ..phi = 1.1
        ..radius = 9
        ..targetX = 4
        ..targetY = 5
        ..targetZ = 6;

      rig.resetOverview();

      expect(state.theta, 0);
      expect(state.phi, 0.32);
      expect(state.radius, OrbitCameraRig.kOverviewRadius);
      expect(state.targetX, 0);
      expect(state.targetY, 0);
      expect(state.targetZ, 0);
    });

    test('leaves the field of view alone', () {
      state.fovRadians = 1.2;
      rig.resetOverview();
      expect(state.fovRadians, 1.2);
    });
  });

  group('buildCamera', () {
    test('places the eye on the orbit sphere around the target', () {
      state
        ..theta = 0.7
        ..phi = 0.3
        ..radius = 12
        ..targetX = 1
        ..targetY = 2
        ..targetZ = 3;

      final camera = rig.buildCamera(ui: const ExplorerState());

      // The camera stores its transform as 32-bit floats, so the expected
      // spherical position is only comparable to about single precision.
      final cosPhi = math.cos(0.3);
      expect(camera.position.x, closeTo(1 + 12 * cosPhi * math.sin(0.7), 1e-5));
      expect(camera.position.y, closeTo(2 + 12 * math.sin(0.3), 1e-5));
      expect(camera.position.z, closeTo(3 + 12 * cosPhi * math.cos(0.7), 1e-5));
    });

    test('keeps the eye exactly one radius away from the target', () {
      state
        ..theta = 1.1
        ..phi = -0.1
        ..radius = 9
        ..targetX = -2
        ..targetY = 4
        ..targetZ = 0.5;

      final camera = rig.buildCamera(ui: const ExplorerState());
      final distance =
          (camera.position - camera.target).length;

      expect(distance, closeTo(9, 1e-5));
    });

    test('puts the camera directly above the target at phi = pi/2', () {
      state
        ..phi = math.pi / 2
        ..radius = 5
        ..targetX = 1
        ..targetY = 1
        ..targetZ = 1;

      final camera = rig.buildCamera(ui: const ExplorerState());

      expect(camera.position.x, closeTo(1, 1e-5));
      expect(camera.position.y, closeTo(1 + 5, 1e-5));
      expect(camera.position.z, closeTo(1, 1e-5));
    });

    test('uses the rig field of view', () {
      state.fovRadians = 1.1;
      final camera = rig.buildCamera(ui: const ExplorerState());
      expect(camera.fovRadiansY, 1.1);
    });

    test('detail mode frames the focused body instead of the overview radius',
        () {
      // Detail mode re-derives the camera distance from the focused body, so a
      // pinch in overview mode must not leak into a detail view.
      state.radius = 80;
      const ui = ExplorerState(selectedPlanetId: 'earth');

      final camera = rig.buildCamera(ui: ui);

      expect((camera.position - camera.target).length, closeTo(3.6, 1e-6));
    });
  });

  group('focusOn', () {
    test('ignores an unknown planet id', () {
      rig.resetOverview();
      rig.focusOn('nowhere', makeSceneBuilder(), deltaSeconds: 0.05);
      expect(state.radius, OrbitCameraRig.kOverviewRadius);
      expect(state.targetX, 0);
    });

    test('eases the target toward the body rather than snapping', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3(10, 0, 0));
      state
        ..targetX = 0
        ..targetY = 0
        ..targetZ = 0;

      rig.focusOn('earth', builder, deltaSeconds: 0.05);

      // One 0.05s frame is 6% of the 0.82s flight, and the ease-out curve is
      // already ~17% of the way there.
      expect(state.targetX, greaterThan(0));
      expect(state.targetX, lessThan(10));
    });

    test('arrives exactly on the body after the flight completes', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3(4, -2, 7));

      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('earth', builder, deltaSeconds: 0.05);
      }

      expect(state.targetX, closeTo(4, 1e-9));
      expect(state.targetY, closeTo(-2, 1e-9));
      expect(state.targetZ, closeTo(7, 1e-9));
    });

    test('frames a full-size planet at 3.6x its radius', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3(3, 0, 0), radius: 1);

      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('earth', builder, deltaSeconds: 0.05);
      }

      expect(state.radius, closeTo(3.6, 1e-9));
    });

    test('frames the sun slightly closer than a planet of the same size', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'sun', position: vm.Vector3(3, 0, 0), radius: 1, isSun: true);

      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('sun', builder, deltaSeconds: 0.05);
      }

      expect(state.radius, closeTo(3.4, 1e-9));
    });

    test('keeps a tiny moon legible instead of burying it in the parent', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'moon', position: vm.Vector3(0, 0, 0.2), radius: 0.1);

      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('moon', builder, deltaSeconds: 0.05);
      }

      // 3.6x a 0.1-unit moon would be 0.36 units, below the 0.45 floor, so the
      // floor is what keeps it on screen.
      expect(state.radius, closeTo(0.45, 1e-9));
    });

    test('clamps the framing distance for a very large body', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'jupiter', position: vm.Vector3(0, 0, 0), radius: 10);

      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('jupiter', builder, deltaSeconds: 0.05);
      }

      expect(state.radius, closeTo(30, 1e-9), reason: 'capped at bodyMax');
    });

    test('a single huge frame still cannot overshoot the flight', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3(10, 0, 0));

      rig.focusOn('earth', builder, deltaSeconds: 100);

      expect(state.targetX, lessThan(10));
    });

    test('re-focusing the same body follows it without re-running the flight',
        () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth', position: vm.Vector3(10, 0, 0));

      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('earth', builder, deltaSeconds: 0.05);
      }
      expect(state.targetX, closeTo(10, 1e-9));

      // A moon keeps moving while it is being followed. Re-focusing must not
      // restart the intro flight, or the camera would lurch backwards.
      body.node.position = vm.Vector3(0, 0, 20);
      rig.focusOn('earth', builder, deltaSeconds: 0.05);

      expect(state.targetX, closeTo(0, 1e-9));
      expect(state.targetZ, closeTo(20, 1e-9));
    });

    test('focusing a different body does start a fresh flight', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3(10, 0, 0));
      addBody(builder, 'mars', position: vm.Vector3(0, 0, 20));

      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('earth', builder, deltaSeconds: 0.05);
      }
      expect(state.targetX, closeTo(10, 1e-9));

      rig.focusOn('mars', builder, deltaSeconds: 0.05);

      // Part way from Earth towards Mars, not a jump.
      expect(state.targetX, lessThan(10));
      expect(state.targetX, greaterThan(0));
      expect(state.targetZ, greaterThan(0));
    });
  });

  group('releaseFocus', () {
    test('decays the target back towards the origin', () {
      state
        ..targetX = 10
        ..targetY = 20
        ..targetZ = 30;

      rig.releaseFocus();

      expect(state.targetX, closeTo(9.2, 1e-9));
      expect(state.targetY, closeTo(18.4, 1e-9));
      expect(state.targetZ, closeTo(27.6, 1e-9));
    });

    test('eases the radius back out to the overview distance', () {
      state.radius = 20;

      rig.releaseFocus();

      expect(state.radius, closeTo(21.3, 1e-9));
    });

    test('keeps easing out one frame at a time', () {
      state.radius = 20;

      rig.releaseFocus();
      rig.releaseFocus();

      expect(state.radius, closeTo(22.535, 1e-9));
    });

    test('never zooms past the overview distance', () {
      state.radius = 50;

      rig.releaseFocus();

      expect(state.radius, 50);
    });

    test('a released camera converges on the origin', () {
      state
        ..targetX = 10
        ..targetY = 0
        ..targetZ = 0
        ..radius = 8;

      for (var i = 0; i < 400; i++) {
        rig.releaseFocus();
      }

      expect(state.targetX.abs(), lessThan(1e-6));
      expect(state.radius, closeTo(OrbitCameraRig.kOverviewRadius, 1e-6));
    });
  });

  group('labelsVisibleAtZoom', () {
    test('overview hides labels once the system is zoomed out', () {
      state.radius = 62;
      expect(rig.labelsVisibleAtZoom(const ExplorerState()), isTrue);

      state.radius = 62.5;
      expect(rig.labelsVisibleAtZoom(const ExplorerState()), isFalse);
    });

    test('detail keeps labels at the default zoom', () {
      const ui = ExplorerState(selectedPlanetId: 'earth');
      expect(rig.labelsVisibleAtZoom(ui), isTrue);
    });

    test('detail hides labels once zoomed far out', () {
      const ui = ExplorerState(selectedPlanetId: 'earth', detailZoom: 2.5);

      // The displayed zoom eases toward the requested zoom by 18% per frame.
      for (var i = 0; i < 60; i++) {
        rig.buildCamera(ui: ui);
      }

      expect(rig.labelsVisibleAtZoom(ui), isFalse);
    });

    test('detail does not adopt the user label preference', () {
      const ui = ExplorerState(selectedPlanetId: 'earth', showLabels: false);
      expect(rig.labelsVisibleAtZoom(ui), isTrue);
    });
  });
}
