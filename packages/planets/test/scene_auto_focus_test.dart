import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:planets/scene.dart';
import 'package:planets/state.dart';

import 'helpers/scene_stubs.dart';

/// [OrbitCameraRig.focusOn] eases over 0.82s but clamps any single frame's
/// `deltaSeconds` to 0.05, so settling it takes 17 calls.
const int kFramesToSettleFocus = 17;

PerspectiveCamera cameraAt(vm.Vector3 eye, [vm.Vector3? target]) =>
    PerspectiveCamera(
      fovRadiansY: 0.85,
      position: eye.clone(),
      target: (target ?? vm.Vector3.zero()).clone(),
      up: vm.Vector3(0, 1, 0),
    );

double distanceTo(String id, SolarSystemSceneBuilder builder, PerspectiveCamera cam) {
  final pos = OrbitCameraRig.worldPositionOf(builder.states[id]!);
  return cam.position.distanceTo(pos);
}

bool shouldRelease(
  String id,
  SolarSystemSceneBuilder builder,
  PerspectiveCamera cam,
) {
  final worldR = OrbitCameraRig.worldRadiusOf(builder.states[id]!);
  return distanceTo(id, builder, cam) >= worldR * 12.0;
}

double zoomFor(
  String id,
  SolarSystemSceneBuilder builder,
  PerspectiveCamera cam,
) {
  final render = builder.states[id]!;
  final worldR = OrbitCameraRig.worldRadiusOf(render);
  final base = OrbitCameraRig.baseDistanceFor(
    worldRadius: worldR,
    isSun: render.isSun,
  );
  return distanceTo(id, builder, cam) / base;
}

void main() {
  late SolarSystemSceneBuilder builder;

  setUp(() {
    builder = makeSceneBuilder();
    // Real catalogue scale: Sun big at origin, planets out on orbits.
    addBody(
      builder,
      'sun',
      position: vm.Vector3.zero(),
      radius: 4.2,
      isSun: true,
    );
    addBody(
      builder,
      'earth',
      position: vm.Vector3(12, 0, 0),
      radius: 0.95,
    );
    addBody(
      builder,
      'jupiter',
      position: vm.Vector3(18, 0, 0),
      radius: 2.0,
    );
  });

  group('world-space radius', () {
    test('sun and planets report their rendered radius', () {
      expect(OrbitCameraRig.worldRadiusOf(builder.states['sun']!), closeTo(4.2, 1e-9));
      expect(
        OrbitCameraRig.worldRadiusOf(builder.states['earth']!),
        closeTo(0.95, 1e-9),
      );
      expect(
        OrbitCameraRig.worldRadiusOf(builder.states['jupiter']!),
        closeTo(2.0, 1e-9),
      );
    });

    test('shared pipeline: no per-planet hacks, only radius scaling', () {
      // Same formula for every body; the Sun differs only by its 3.4 factor.
      expect(
        OrbitCameraRig.baseDistanceFor(worldRadius: 1.0, isSun: false),
        closeTo(3.6, 1e-9),
      );
      expect(
        OrbitCameraRig.baseDistanceFor(worldRadius: 1.0, isSun: true),
        closeTo(3.4, 1e-9),
      );
    });
  });

  group('auto-release hysteresis', () {
    test('earth holds focus inside the exit threshold', () {
      // Earth exit = 0.95 * 12 = 11.4. At 6 units it must stay selected.
      final cam = cameraAt(vm.Vector3(12 + 6, 0, 0), vm.Vector3(12, 0, 0));
      expect(shouldRelease('earth', builder, cam), isFalse);
    });

    test('earth releases past the exit threshold', () {
      final cam = cameraAt(vm.Vector3(12 + 20, 0, 0), vm.Vector3(12, 0, 0));
      expect(shouldRelease('earth', builder, cam), isTrue);
    });

    test('enter is strictly smaller than exit (no flicker)', () {
      for (final id in ['sun', 'earth', 'jupiter']) {
        final worldR = OrbitCameraRig.worldRadiusOf(builder.states[id]!);
        expect(worldR * 7.0, lessThan(worldR * 12.0));
      }
    });

    test('sun and jupiter share the same release pipeline', () {
      final nearSun = cameraAt(vm.Vector3(10, 0, 0));
      final farSun = cameraAt(vm.Vector3(60, 0, 0));
      expect(shouldRelease('sun', builder, nearSun), isFalse);
      expect(shouldRelease('sun', builder, farSun), isTrue);

      final nearJupiter = cameraAt(vm.Vector3(18 + 5, 0, 0));
      final farJupiter = cameraAt(vm.Vector3(18 + 30, 0, 0));
      expect(shouldRelease('jupiter', builder, nearJupiter), isFalse);
      expect(shouldRelease('jupiter', builder, farJupiter), isTrue);
    });
  });

  group('detail zoom from camera distance', () {
    test('earth zoom reproduces the exact camera distance', () {
      const base = 0.95 * 3.6;
      for (final dist in [0.5, 3.42, 6.65, 20.0]) {
        final cam = cameraAt(vm.Vector3(12 + dist, 0, 0));
        // Camera position is stored as 32-bit floats: single precision only.
        expect(zoomFor('earth', builder, cam), closeTo(dist / base, 1e-6));
      }
    });

    test('deep zoom continues past the old 0.4 floor', () {
      final cam = cameraAt(vm.Vector3(12 + 0.5, 0, 0));
      final zoom = zoomFor('earth', builder, cam);
      expect(zoom, lessThan(0.4));
      expect(zoom, greaterThan(0));
    });

    test('far zoom continues past the old 2.6 ceiling', () {
      final cam = cameraAt(vm.Vector3(12 + 20, 0, 0));
      expect(zoomFor('earth', builder, cam), greaterThan(2.6));
    });
  });

  group('seamless selection preserves the camera', () {
    test('earth selection keeps the exact pinch distance', () {
      final rig = OrbitCameraRig(state: CameraRigState());
      final eye = vm.Vector3(12 + 8, 0, 5);
      final before = (eye - vm.Vector3(12, 0, 0)).length;
      final zoom = rig.snapToBodyPreservingEye(
        planetId: 'earth',
        bodyPos: vm.Vector3(12, 0, 0),
        worldRadius: 0.95,
        isSun: false,
        eye: eye,
      );
      expect(zoom, closeTo(before / (0.95 * 3.6), 1e-6));
      final after = rig.buildCamera(
        ui: ExplorerState(selectedPlanetId: 'earth', detailZoom: zoom),
      );
      expect(
        (after.position - vm.Vector3(12, 0, 0)).length,
        closeTo(before, 1e-4),
      );
    });

    test('jupiter selection keeps the exact pinch distance', () {
      final rig = OrbitCameraRig(state: CameraRigState());
      final eye = vm.Vector3(18 + 10, 0, -4);
      final before = (eye - vm.Vector3(18, 0, 0)).length;
      final zoom = rig.snapToBodyPreservingEye(
        planetId: 'jupiter',
        bodyPos: vm.Vector3(18, 0, 0),
        worldRadius: 2.0,
        isSun: false,
        eye: eye,
      );
      final after = rig.buildCamera(
        ui: ExplorerState(selectedPlanetId: 'jupiter', detailZoom: zoom),
      );
      expect(
        (after.position - vm.Vector3(18, 0, 0)).length,
        closeTo(before, 1e-4),
      );
    });

    test('deselect keeps the exact camera position', () {
      final rig = OrbitCameraRig(state: CameraRigState());
      final eye = vm.Vector3(12 + 4, 1, 2);
      final zoom = rig.snapToBodyPreservingEye(
        planetId: 'earth',
        bodyPos: vm.Vector3(12, 0, 0),
        worldRadius: 0.95,
        isSun: false,
        eye: eye,
      );
      final detailCam = rig.buildCamera(
        ui: ExplorerState(selectedPlanetId: 'earth', detailZoom: zoom),
      );
      // Gesture handler freezes the eye synchronously, then the tick only
      // clears tracking (and may run with a stale frame's UI).
      rig.preserveEye(detailCam.position);
      rig.releaseFocus();
      final freeCam = rig.buildCamera(ui: const ExplorerState());
      expect(
        (freeCam.position - detailCam.position).length,
        lessThan(1e-6),
      );
    });

    test('zooming out in detail never snaps back to 100%', () {
      // Regression: the focus flight lands on the user's zoom, so zooming
      // out toward the release threshold moves monotonically outward.
      final rig = OrbitCameraRig(state: CameraRigState());
      final staterig = rig.state
        ..theta = 0.0
        ..phi = 0.3
        ..radius = 46.0;
      staterig.targetX = 0;
      final b = makeSceneBuilder();
      addBody(b, 'earth', position: vm.Vector3(12, 0, 0), radius: 0.95);
      var lastDist = -1.0;
      for (final zoom in [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]) {
        for (var i = 0; i < kFramesToSettleFocus; i++) {
          rig.focusOn('earth', b, deltaSeconds: 0.05, detailZoom: zoom);
        }
        // The displayed zoom eases 18% per built frame toward the request.
        PerspectiveCamera? cam;
        for (var i = 0; i < 60; i++) {
          cam = rig.buildCamera(
            ui: ExplorerState(selectedPlanetId: 'earth', detailZoom: zoom),
          );
        }
        final dist = (cam!.position - vm.Vector3(12, 0, 0)).length;
        expect(dist, greaterThan(lastDist));
        lastDist = dist;
      }
      // At 4.0x the 3.42 base the camera is past Earth's 11.4 exit range.
      expect(lastDist, greaterThan(0.95 * 12.0));
    });
  });

  group('close transition keeps the system visible', () {
    // The Close button clears selection with no gesture in flight, so the
    // view re-anchors on selection teardown. These tests drive exactly what
    // that teardown does: reanchorPreservingEye (same call the controller's
    // preserveReleaseEye makes) with the last rendered camera.
    const viewSize = Size(800, 600);

    test('select then close leaves the sun on screen', () {
      final rig = OrbitCameraRig(state: CameraRigState());
      final zoom = rig.snapToBodyPreservingEye(
        planetId: 'earth',
        bodyPos: vm.Vector3(12, 0, 0),
        worldRadius: 0.95,
        isSun: false,
        eye: vm.Vector3(12 + 2, 1, 1.5),
      );
      final detailCam = rig.buildCamera(
        ui: ExplorerState(selectedPlanetId: 'earth', detailZoom: zoom),
      );
      // Close: freeze the eye, hand the anchor back to the system center.
      rig.reanchorPreservingEye(detailCam.position.clone());
      rig.releaseFocus();
      final freeCam = rig.buildCamera(ui: const ExplorerState());
      expect(
        (freeCam.position - detailCam.position).length,
        lessThan(1e-6),
      );
      expect(rig.state.targetX, 0);
      expect(rig.state.targetY, 0);
      expect(rig.state.targetZ, 0);
      final sunScreen = freeCam.worldToScreen(vm.Vector3.zero(), viewSize);
      expect(sunScreen, isNotNull);
      expect(sunScreen!.dx, inInclusiveRange(0, viewSize.width));
      expect(sunScreen.dy, inInclusiveRange(0, viewSize.height));
    });

    test('close after heavy rotation preserves orientation', () {
      final rig = OrbitCameraRig(state: CameraRigState());
      rig.state
        ..theta = 2.6
        ..phi = 1.1
        ..radius = 6
        ..targetX = 12
        ..targetY = 0
        ..targetZ = 0;
      final detailCam = rig.buildCamera(
        ui: const ExplorerState(selectedPlanetId: 'earth'),
      );
      rig.reanchorPreservingEye(detailCam.position.clone());
      rig.releaseFocus();
      final freeCam = rig.buildCamera(ui: const ExplorerState());
      expect(
        (freeCam.position - detailCam.position).length,
        lessThan(1e-6),
      );
      expect(
        (freeCam.target - detailCam.target).length,
        greaterThan(1.0),
        reason: 'anchor returns to the system center, the eye does not move',
      );
    });

    test('close preserves the zoom level instead of resetting', () {
      final rig = OrbitCameraRig(state: CameraRigState());
      rig.snapToBodyPreservingEye(
        planetId: 'earth',
        bodyPos: vm.Vector3(12, 0, 0),
        worldRadius: 0.95,
        isSun: false,
        eye: vm.Vector3(12 + 1.2, 0.4, 0.8),
      );
      final detailCam = rig.buildCamera(
        ui: const ExplorerState(selectedPlanetId: 'earth', detailZoom: 0.4),
      );
      final distBefore = detailCam.position.length;
      rig.reanchorPreservingEye(detailCam.position.clone());
      rig.releaseFocus();
      // The eye (hence the visual zoom) is untouched …
      final freeCam = rig.buildCamera(ui: const ExplorerState());
      expect((freeCam.position - detailCam.position).length, lessThan(1e-6));
      // … and the radius now measures from the system center, not a default.
      expect(rig.state.radius, closeTo(distBefore, 1e-6));
      expect(rig.state.radius, isNot(closeTo(46.0, 1e-6)));
    });

    test('close never jumps to the default overview pose', () {
      final rig = OrbitCameraRig(state: CameraRigState());
      rig.state
        ..theta = 1.9
        ..phi = -0.6
        ..radius = 4.2
        ..targetX = 12
        ..targetY = 0
        ..targetZ = 0;
      final detailCam = rig.buildCamera(
        ui: const ExplorerState(selectedPlanetId: 'earth', detailZoom: 1.2),
      );
      rig.reanchorPreservingEye(detailCam.position.clone());
      rig.releaseFocus();
      expect(rig.state.theta, isNot(closeTo(0.0, 1e-6)));
      expect(rig.state.phi, isNot(closeTo(0.32, 1e-6)));
      expect(rig.state.radius, isNot(closeTo(46.0, 1e-6)));
      final freeCam = rig.buildCamera(ui: const ExplorerState());
      expect(
        (freeCam.position - detailCam.position).length,
        lessThan(1e-6),
      );
    });

    test('repeated select/close cycles do not walk the camera away', () {
      final rig = OrbitCameraRig(state: CameraRigState());
      for (var i = 0; i < 10; i++) {
        final eye = rig.buildCamera(ui: const ExplorerState()).position;
        // Production derives the selection zoom from the pinch distance.
        final zoom = rig.snapToBodyPreservingEye(
          planetId: 'earth',
          bodyPos: vm.Vector3(12, 0, 0),
          worldRadius: 0.95,
          isSun: false,
          eye: eye.clone(),
        );
        final detailCam = rig.buildCamera(
          ui: ExplorerState(selectedPlanetId: 'earth', detailZoom: zoom),
        );
        // Close teardown.
        rig.reanchorPreservingEye(detailCam.position.clone());
        rig.releaseFocus();
        final freeCam = rig.buildCamera(ui: const ExplorerState());
        expect(
          (freeCam.position - eye).length,
          lessThan(1e-4),
          reason: 'cycle $i must return to the pre-select eye',
        );
        expect(rig.state.targetX, 0);
        expect(rig.state.targetY, 0);
        expect(rig.state.targetZ, 0);
      }
      expect(rig.state.radius, lessThan(200));
      expect(rig.state.radius, greaterThan(0));
    });

    test('close after vertical flip still leaves a usable view', () {
      final rig = OrbitCameraRig(state: CameraRigState());
      rig.state
        ..theta = 0.7
        ..phi = -1.2
        ..radius = 7
        ..targetX = 12
        ..targetY = 0
        ..targetZ = 0;
      final detailCam = rig.buildCamera(
        ui: const ExplorerState(selectedPlanetId: 'earth'),
      );
      rig.reanchorPreservingEye(detailCam.position.clone());
      rig.releaseFocus();
      final freeCam = rig.buildCamera(ui: const ExplorerState());
      expect(
        (freeCam.position - detailCam.position).length,
        lessThan(1e-6),
      );
      final sunScreen = freeCam.worldToScreen(vm.Vector3.zero(), viewSize);
      expect(sunScreen, isNotNull);
      expect(sunScreen!.dx, inInclusiveRange(0, viewSize.width));
      expect(sunScreen.dy, inInclusiveRange(0, viewSize.height));
    });
  });
}
