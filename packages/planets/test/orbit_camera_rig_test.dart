import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets/state.dart';
import 'package:planets/scene.dart';
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
    test('a scale factor above one zooms in', () {
      rig.pinch(2);
      expect(state.radius, closeTo(23, 1e-12));
    });

    test('a scale factor below one zooms out past the old max', () {
      rig.pinch(0.5);
      expect(state.radius, closeTo(92, 1e-12));
    });

    test('a factor of one is a no-op', () {
      rig.pinch(1);
      expect(state.radius, OrbitCameraRig.kOverviewRadius);
    });

    test('repeated zoom-in continues past the old 8-unit floor', () {
      for (var i = 0; i < 10; i++) {
        rig.pinch(2);
      }
      expect(state.radius, lessThan(1.0));
      expect(state.radius, greaterThan(0));
    });

    test('repeated zoom-out continues past the old 90-unit ceiling', () {
      for (var i = 0; i < 10; i++) {
        rig.pinch(0.5);
      }
      expect(state.radius, greaterThan(90.0));
    });

    test('a zero or negative factor is ignored instead of producing NaN', () {
      rig.pinch(0);
      expect(state.radius, OrbitCameraRig.kOverviewRadius);
      rig.pinch(-2);
      expect(state.radius, OrbitCameraRig.kOverviewRadius);
    });

    test('pinchToward moves the eye toward the focal body on zoom-in', () {
      state
        ..targetX = 0
        ..targetY = 0
        ..targetZ = 0
        ..radius = 46;
      final before = rig.buildCamera(ui: const ExplorerState()).position;
      final beforeDist = (before - vm.Vector3(12, 0, 0)).length;
      rig.pinchToward(2.0, focalWorldPoint: vm.Vector3(12, 0, 0));
      final after = rig.buildCamera(ui: const ExplorerState()).position;
      // The eye approaches Earth …
      expect((after - vm.Vector3(12, 0, 0)).length, lessThan(beforeDist));
      // … while the anchor never moves.
      expect(state.targetX, 0);
      expect(state.targetY, 0);
      expect(state.targetZ, 0);
    });

    test('pinchToward moves the eye away from the focal body on zoom-out', () {
      state
        ..targetX = 0
        ..targetY = 0
        ..targetZ = 0
        ..radius = 46;
      final focal = vm.Vector3(12, 0, 0);
      final beforeDist =
          (rig.buildCamera(ui: const ExplorerState()).position - focal).length;
      rig.pinchToward(0.5, focalWorldPoint: focal);
      final afterDist =
          (rig.buildCamera(ui: const ExplorerState()).position - focal).length;
      // Away from the marked body, while the anchor never moves.
      expect(afterDist, greaterThan(beforeDist));
      expect(state.targetX, 0);
      expect(state.targetY, 0);
      expect(state.targetZ, 0);
    });

    test('repeated focal pinches never drift the anchor off-screen', () {
      state.radius = 46;
      final focal = vm.Vector3(12, 0, 0);
      final startDist = (rig.buildCamera(ui: const ExplorerState()).position -
              focal)
          .length;
      for (var i = 0; i < 50; i++) {
        rig.pinchToward(1.1, focalWorldPoint: focal);
      }
      // Fifty gestures later the rotation anchor is still the system center.
      expect(state.targetX, 0);
      expect(state.targetY, 0);
      expect(state.targetZ, 0);
      // … and the eye has converged toward the focal area, not drifted past.
      final endDist =
          (rig.buildCamera(ui: const ExplorerState()).position - focal).length;
      expect(endDist, lessThan(startDist));
      expect(endDist, lessThan(12.0));
    });

    test('on-axis focal pinch preserves the current rotation', () {
      state
        ..theta = 0.5
        ..phi = 0.2
        ..radius = 46;
      // A focal point straight ahead (the anchor itself) moves along the
      // current view ray, so orientation must not change.
      rig.pinchToward(2.0, focalWorldPoint: vm.Vector3.zero());
      // Angles round-trip through atan2/asin, so single precision only.
      expect(state.theta, closeTo(0.5, 1e-6));
      expect(state.phi, closeTo(0.2, 1e-6));
      expect(state.radius, lessThan(46));
    });

    test('pure pinch preserves orientation', () {
      state
        ..theta = 0.5
        ..phi = 0.2;
      rig.pinch(2.0);
      expect(state.theta, closeTo(0.5, 1e-12));
      expect(state.phi, closeTo(0.2, 1e-12));
    });

    test('approach progress is 1 exactly at the enter distance', () {
      // Earth: 0.95 * 7 = 6.65 units is the detail-entry threshold.
      expect(
        OrbitCameraRig.approachProgress(distance: 6.65, worldRadius: 0.95),
        closeTo(1.0, 1e-9),
      );
    });

    test('approach progress passes 90% just outside entry', () {
      expect(
        OrbitCameraRig.approachProgress(distance: 7.0, worldRadius: 0.95),
        greaterThan(0.90),
      );
      expect(
        OrbitCameraRig.approachProgress(distance: 8.0, worldRadius: 0.95),
        lessThan(0.90),
      );
    });

    test('approach progress degrades safely on degenerate input', () {
      expect(
        OrbitCameraRig.approachProgress(distance: double.infinity, worldRadius: 1.0),
        0.0,
      );
      expect(
        OrbitCameraRig.approachProgress(distance: 5.0, worldRadius: 0.0),
        0.0,
      );
      expect(
        OrbitCameraRig.approachProgress(distance: 0.0, worldRadius: 1.0),
        greaterThan(1.0),
      );
    });

    test('marked zoom keeps looking at the body, never back at the sun', () {
      // Regression: pinchToward used to re-pin the target to the origin
      // every frame, fighting the look-track — the eye arrived at the marked
      // body while staring past it at the Sun.
      state.radius = 46;
      final body = vm.Vector3(12, 0, 0);
      for (var i = 0; i < 300; i++) {
        rig.easeLookAt(bodyPos: body, deltaSeconds: 1 / 60);
      }
      for (var i = 0; i < 50; i++) {
        rig.pinchToward(1.1, focalWorldPoint: body);
        rig.easeLookAt(bodyPos: body, deltaSeconds: 1 / 60);
        // The view direction never swings back toward the origin mid-zoom.
        expect(state.targetX, closeTo(12, 0.5));
      }
      final eye = rig.buildCamera(ui: const ExplorerState()).position;
      expect((eye - body).length, lessThan(2.0));
      expect(state.targetX, closeTo(12, 1e-3));
    });

    test('manual pinch cancels a running zoom flight', () {
      state.radius = 46;
      final eye = rig.buildCamera(ui: const ExplorerState()).position.clone();
      rig.beginZoomToBody(worldRadius: 0.95, eye: eye);
      expect(rig.zoomFlightActive, isTrue);
      rig.pinchToward(1.2, focalWorldPoint: vm.Vector3(12, 0, 0));
      expect(rig.zoomFlightActive, isFalse);
    });

    test('zoom flight converges to the entry distance', () {
      state
        ..theta = 0.3
        ..phi = 0.25
        ..radius = 40;
      final body = vm.Vector3(12, 0, 0);
      final startEye =
          rig.buildCamera(ui: const ExplorerState()).position.clone();
      final startDist = (startEye - body).length;
      rig.beginZoomToBody(worldRadius: 0.95, eye: startEye);
      var done = false;
      var progress = 0.0;
      var lastDist = startDist;
      var crossedNarration = false;
      var doneAtCross = false;
      for (var i = 0; i < 600 && !done; i++) {
        final step = rig.stepZoomFlight(
          deltaSeconds: 1 / 60,
          bodyPos: body,
        );
        done = step.done;
        progress = step.progress;
        if (progress > 0.90 && !crossedNarration) {
          crossedNarration = true;
          doneAtCross = done;
        }
        final dist =
            (rig.buildCamera(ui: const ExplorerState()).position - body)
                .length;
        expect(dist, lessThanOrEqualTo(lastDist + 1e-6));
        lastDist = dist;
      }
      expect(done, isTrue);
      // The >90% narration point is crossed before arrival, never after.
      expect(crossedNarration, isTrue);
      expect(doneAtCross, isFalse);
      expect(progress, greaterThan(0.9));
      expect(lastDist, closeTo(0.95 * 7, 0.95 * 7 * 0.05));
      // Arrival already faces the body: no swing needed when detail opens.
      expect(state.targetX, closeTo(12, 0.1));
      expect(state.targetY, closeTo(0, 0.1));
      expect(state.targetZ, closeTo(0, 0.1));
      expect(rig.zoomFlightActive, isFalse);
    });

    test('marking turns the camera to face the body without moving it', () {
      state
        ..theta = 0.0
        ..phi = 0.32
        ..radius = 46.0;
      final eye = rig.buildCamera(ui: const ExplorerState()).position.clone();
      final body = vm.Vector3(12, 0, 0);
      for (var i = 0; i < 300; i++) {
        rig.easeLookAt(bodyPos: body, deltaSeconds: 1 / 60);
      }
      // Eye (hence distance) untouched …
      final after = rig.buildCamera(ui: const ExplorerState()).position;
      expect((after - eye).length, lessThan(1e-6));
      // … but the look direction now rests on the marked body.
      expect(state.targetX, closeTo(12, 1e-3));
      expect(state.targetY, closeTo(0, 1e-3));
      expect(state.targetZ, closeTo(0, 1e-3));
    });

    test('look tracking follows an orbiting body with a fixed eye', () {
      state.radius = 30;
      final eye = rig.buildCamera(ui: const ExplorerState()).position.clone();
      final body = vm.Vector3(12, 0, 0);
      for (var i = 0; i < 120; i++) {
        body.z += 0.02;
        rig.easeLookAt(bodyPos: body, deltaSeconds: 1 / 60);
      }
      expect(
        (rig.buildCamera(ui: const ExplorerState()).position - eye).length,
        lessThan(1e-6),
      );
      // Still facing the body after it moved ~2.4 units.
      expect(state.targetX, closeTo(body.x, 0.6));
      expect(state.targetZ, closeTo(body.z, 0.6));
    });

    test('zoom flight tracks a moving body', () {
      state.radius = 30;
      final eye = rig.buildCamera(ui: const ExplorerState()).position.clone();
      rig.beginZoomToBody(worldRadius: 1.0, eye: eye);
      final body = vm.Vector3(10, 0, 0);
      var done = false;
      for (var i = 0; i < 600 && !done; i++) {
        // The body drifts sideways while the camera flies.
        body.x += 0.005;
        done = rig
            .stepZoomFlight(deltaSeconds: 1 / 60, bodyPos: body)
            .done;
      }
      expect(done, isTrue);
      final endDist =
          (rig.buildCamera(ui: const ExplorerState()).position - body).length;
      expect(endDist, closeTo(7.0, 7.0 * 0.05));
    });

    test('cancelled flight reports done with zero progress', () {
      state.radius = 46;
      final eye = rig.buildCamera(ui: const ExplorerState()).position.clone();
      rig.beginZoomToBody(worldRadius: 0.95, eye: eye);
      rig.cancelZoomFlight();
      final step = rig.stepZoomFlight(
        deltaSeconds: 1 / 60,
        bodyPos: vm.Vector3(12, 0, 0),
      );
      expect(step.done, isTrue);
      expect(step.progress, 0.0);
    });

    test('anyFrameOnScreen is true when a body is inside the viewport', () {
      const size = Size(800, 600);
      expect(
        LabelProjector.anyFrameOnScreen(
          const [
            PlanetLabelFrame(
              id: 'earth',
              screenX: 400,
              screenY: 300,
              worldDepth: 1,
              visible: true,
            ),
          ],
          size,
        ),
        isTrue,
      );
    });

    test('anyFrameOnScreen is false when every body is outside', () {
      const size = Size(800, 600);
      expect(
        LabelProjector.anyFrameOnScreen(
          const [
            PlanetLabelFrame(
              id: 'earth',
              screenX: -200,
              screenY: 300,
              worldDepth: 1,
              visible: true,
            ),
            PlanetLabelFrame(
              id: 'mars',
              screenX: 900,
              screenY: 700,
              worldDepth: 2,
              visible: false,
            ),
          ],
          size,
        ),
        isFalse,
      );
    });

    test('anyFrameOnScreen treats an empty frame list as lost', () {
      expect(
        LabelProjector.anyFrameOnScreen(const [], const Size(800, 600)),
        isFalse,
      );
    });

    test('anyFrameOnScreen ignores an empty viewport', () {
      expect(LabelProjector.anyFrameOnScreen(const [], Size.zero), isTrue);
    });

    test('reanchor keeps the eye and restores the system anchor', () {
      state
        ..theta = 0.4
        ..phi = 0.1
        ..radius = 5
        ..targetX = 10
        ..targetY = 0
        ..targetZ = 0;
      final eye = rig.buildCamera(ui: const ExplorerState()).position.clone();
      rig.reanchorPreservingEye(eye);
      expect(state.targetX, 0);
      expect(state.targetY, 0);
      expect(state.targetZ, 0);
      final after = rig.buildCamera(ui: const ExplorerState()).position;
      expect((after - eye).length, lessThan(1e-6));
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
      final distance = (camera.position - camera.target).length;

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

    test('detail mode frames the focused body instead of the overview radius', () {
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
      addBody(
        builder,
        'sun',
        position: vm.Vector3(3, 0, 0),
        radius: 1,
        isSun: true,
      );

      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('sun', builder, deltaSeconds: 0.05);
      }

      expect(state.radius, closeTo(3.4, 1e-9));
    });

    test('frames a tiny moon at its true 3.6x distance (no floor hack)', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'moon', position: vm.Vector3(0, 0, 0.2), radius: 0.1);

      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('moon', builder, deltaSeconds: 0.05);
      }

      expect(state.radius, closeTo(0.36, 1e-9));
    });

    test('frames a very large body at its true distance (no bodyMax cap)', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'jupiter', position: vm.Vector3(0, 0, 0), radius: 10);

      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('jupiter', builder, deltaSeconds: 0.05);
      }

      expect(state.radius, closeTo(36, 1e-9));
    });

    test('detail zoom is unbounded in both directions', () {
      expect(rig.detailRadiusForZoom(0.05), closeTo(0.18, 1e-9));
      expect(rig.detailRadiusForZoom(10.0), closeTo(36.0, 1e-9));
    });

    test('focus lands on the current zoom, not back on 100%', () {
      // Regression: zooming out in detail mode must not be dragged back to
      // the default framing by a fresh/restarted focus flight.
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3(10, 0, 0), radius: 1.0);
      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('earth', builder, deltaSeconds: 0.05, detailZoom: 2.5);
      }
      // 2.5x Earth's 3.6 base = 9 units, not the 3.6 default.
      expect(state.radius, closeTo(9.0, 1e-9));
    });

    test('snapToBodyPreservingEye keeps the camera eye fixed', () {
      state
        ..theta = 0.0
        ..phi = 0.3
        ..radius = 20
        ..targetX = 0
        ..targetY = 0
        ..targetZ = 0;
      final before = rig.buildCamera(ui: const ExplorerState());
      final eye = before.position.clone();
      final zoom = rig.snapToBodyPreservingEye(
        planetId: 'earth',
        bodyPos: vm.Vector3(10, 0, 0),
        worldRadius: 1.0,
        isSun: false,
        eye: eye,
      );
      expect(zoom, closeTo((eye - vm.Vector3(10, 0, 0)).length / 3.6, 1e-9));
      final after = rig.buildCamera(
        ui: ExplorerState(selectedPlanetId: 'earth', detailZoom: zoom),
      );
      expect((after.position - eye).length, lessThan(1e-4));
    });

    test('a single huge frame still cannot overshoot the flight', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3(10, 0, 0));

      rig.focusOn('earth', builder, deltaSeconds: 100);

      expect(state.targetX, lessThan(10));
    });

    test(
      're-focusing the same body follows it without re-running the flight',
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
      },
    );

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
    test('preserves the target instead of recentering on the origin', () {
      state
        ..targetX = 10
        ..targetY = 20
        ..targetZ = 30;

      rig.releaseFocus();

      expect(state.targetX, 10);
      expect(state.targetY, 20);
      expect(state.targetZ, 30);
    });

    test('preserves the radius when no detail zoom is handed over', () {
      state.radius = 20;

      rig.releaseFocus();

      expect(state.radius, 20);
    });

    test('hands the detail eye back to free exploration exactly', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3(10, 0, 0), radius: 1.0);
      for (var i = 0; i < kFramesToSettleFocus; i++) {
        rig.focusOn('earth', builder, deltaSeconds: 0.05, detailZoom: 0.5);
      }
      // User pinched to 0.5x while selected: detail eye is at 1.8 units.
      // The gesture handler freezes that eye synchronously before deselect.
      final detailCam = rig.buildCamera(
        ui: ExplorerState(selectedPlanetId: 'earth', detailZoom: 0.5),
      );
      expect(state.radius, closeTo(1.8, 1e-9));
      rig.preserveEye(detailCam.position);
      rig.releaseFocus();
      expect(state.radius, closeTo(1.8, 1e-6));
      expect(state.targetX, closeTo(10, 1e-9));
      final freeCam = rig.buildCamera(ui: const ExplorerState());
      expect(
        (freeCam.position - detailCam.position).length,
        lessThan(1e-6),
      );
    });

    test('ending a gesture never resets the radius', () {
      state.radius = 3.0;
      rig.preserveEye(vm.Vector3(3, 0, 0));
      final kept = state.radius;
      rig.releaseFocus();
      expect(state.radius, kept);
    });

    test('releaseFocus never moves the camera, even mid-flight', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3(10, 0, 0), radius: 1.0);
      rig.focusOn('earth', builder, deltaSeconds: 0.05);
      final radiusBefore = state.radius;
      final targetBefore = vm.Vector3(
        state.targetX,
        state.targetY,
        state.targetZ,
      );
      rig.releaseFocus();
      expect(state.radius, radiusBefore);
      expect(state.targetX, targetBefore.x);
      expect(state.targetY, targetBefore.y);
      expect(state.targetZ, targetBefore.z);
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
