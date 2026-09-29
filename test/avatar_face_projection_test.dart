import 'dart:math' as math;

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/avatar_state.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_face_projection.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_geometry.dart';

/// The face is painted by Flutter while the rocket is rendered by flutter_scene,
/// so the two only agree if this projection repeats the scene's maths exactly.
/// These tests pin the behaviour that agreement depends on: where the window
/// lands, and whether the child can see it at all.
void main() {
  const box = Size(132, 148);

  group('where the window lands', () {
    test('it sits inside the box', () {
      final projection = AvatarFaceProjection.forBox(
        box,
        yaw: 0,
        pitch: 0,
      );

      expect(projection.radius, greaterThan(0));
      expect(projection.centre.dx, inInclusiveRange(0, box.width));
      expect(projection.centre.dy, inInclusiveRange(0, box.height));
      expect(projection.radius, lessThan(box.width / 2));
    });

    test('it lands just above the middle, where the window is on the model',
        () {
      // The window is 0.05 body units up and the camera looks at 0.02, so it
      // is a little above the centre line - and only a little: the window is
      // the middle of the rocket's front, not its top.
      final projection = AvatarFaceProjection.forBox(box, yaw: 0, pitch: 0);

      expect(projection.centre.dy, lessThan(box.height / 2));
      expect(projection.centre.dy, greaterThan(box.height / 2 - 20));
      expect(projection.centre.dx, closeTo(box.width / 2, 0.001));
    });

    test('it scales with the box it is drawn in', () {
      final small = AvatarFaceProjection.forBox(
        const Size(66, 74),
        yaw: 0,
        pitch: 0,
      );
      final large = AvatarFaceProjection.forBox(
        const Size(132, 148),
        yaw: 0,
        pitch: 0,
      );

      expect(large.radius, greaterThan(small.radius));
      expect(large.radius / small.radius, closeTo(2, 0.001));
    });

    test('a bigger box with the same shape keeps the face proportional', () {
      final square = AvatarFaceProjection.forBox(
        const Size(200, 200),
        yaw: 0,
        pitch: 0,
      );
      expect(square.centre.dx, closeTo(100, 0.001));
      expect(square.radius, greaterThan(0));
    });

    test('an empty box cannot draw a face', () {
      final projection = AvatarFaceProjection.forBox(
        Size.zero,
        yaw: 0,
        pitch: 0,
      );

      expect(projection.radius, 0);
      expect(projection.facing, 0);
    });
  });

  group('whether the child can see the face', () {
    double facing({double yaw = 0, double pitch = 0}) =>
        AvatarFaceProjection.forBox(box, yaw: yaw, pitch: pitch).facing;

    test('facing forwards shows the whole face', () {
      expect(facing(), 1);
    });

    test('a quarter turn hides it, which is the back of the rocket', () {
      expect(facing(yaw: math.pi / 2), closeTo(0, 1e-9));
      expect(facing(yaw: -math.pi / 2), closeTo(0, 1e-9));
    });

    test('a half turn shows the engine, not the face', () {
      expect(facing(yaw: math.pi), closeTo(0, 1e-9));
    });

    test('a forty five degree turn is halfway gone', () {
      expect(facing(yaw: math.pi / 4), closeTo(math.sqrt2 / 2, 1e-6));
    });

    test('pitch fades it without ever flipping the sign', () {
      expect(
        facing(pitch: AvatarState.pitchLimit),
        closeTo(math.cos(1.5), 1e-6),
        reason: '86 degrees is nearly edge-on, not gone',
      );
      expect(facing(pitch: -AvatarState.pitchLimit), closeTo(math.cos(1.5), 1e-6));
      expect(facing(pitch: AvatarState.pitchLimit), lessThan(0.2));
      expect(facing(pitch: AvatarState.pitchLimit), greaterThan(0));
    });
  });

  group('following the body', () {
    test('a hover lifts the window with the rocket', () {
      final atRest = AvatarFaceProjection.forBox(box, yaw: 0, pitch: 0);
      final hovered = AvatarFaceProjection.forBox(
        box,
        yaw: 0,
        pitch: 0,
        motion: const AvatarBodyMotion(hover: 0.1),
      );

      expect(hovered.centre.dy, lessThan(atRest.centre.dy));
    });

    test('a bank swings the window sideways', () {
      final atRest = AvatarFaceProjection.forBox(box, yaw: 0, pitch: 0);
      final banked = AvatarFaceProjection.forBox(
        box,
        yaw: 0,
        pitch: 0,
        motion: const AvatarBodyMotion(tilt: 0.4),
      );

      expect(banked.centre.dy, isNot(closeTo(atRest.centre.dy, 0.001)));
    });

    test('a spin carries the window around the body', () {
      final atRest = AvatarFaceProjection.forBox(box, yaw: 0, pitch: 0);
      final spun = AvatarFaceProjection.forBox(
        box,
        yaw: 0,
        pitch: 0,
        motion: const AvatarBodyMotion(spin: -math.pi / 2),
      );

      // A quarter turn of the body takes the window off the front and round to
      // the side, and the face goes edge-on with it. Which side it swings to is
      // the builder's own quaternion convention, mirrored here exactly; what
      // matters is that it moves with the window and that the face steps aside
      // when it does.
      expect(spun.centre.dx, isNot(closeTo(atRest.centre.dx, 0.001)));
      expect(spun.facing, closeTo(0, 1e-6));
    });

    test('the window constant used here is the model\'s own', () {
      expect(AvatarPorthole.radius, 0.075);
      expect(AvatarPorthole.height, 0.05);
      expect(AvatarPorthole.depth, -0.12);
    });
  });
}
