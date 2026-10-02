import 'dart:math' as math;

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:avatar/state.dart';
import 'package:avatar/scene.dart';

/// The face is painted by Flutter while the rocket is rendered by flutter_scene,
/// so the two only agree if this projection repeats the scene's maths exactly.
/// These tests pin the behaviour that agreement depends on: where the window
/// lands, and how readable the face is at that pose.
///
/// On readability: the face is a deliberate camera-facing billboard. It used to
/// fade out as the body turned edge-on or upside down, which meant a fast throw
/// turned the companion into a faceless rocket mid-flight. The rocket body now
/// tumbles freely and the face stays readable, attached to the projected window
/// and kept upright by the painter. So [AvatarFaceProjection.facing] is a
/// constant, and what these tests pin instead is that the window keeps tracking
/// the body while the face does not.
void main() {
  const box = Size(132, 148);

  group('where the window lands', () {
    test('it sits inside the box', () {
      final projection = AvatarFaceProjection.forBox(box, yaw: 0, pitch: 0);

      expect(projection.radius, greaterThan(0));
      expect(projection.centre.dx, inInclusiveRange(0, box.width));
      expect(projection.centre.dy, inInclusiveRange(0, box.height));
      expect(projection.radius, lessThan(box.width / 2));
    });

    test(
      'it lands just above the middle, where the window is on the model',
      () {
        // The window is 0.05 body units up and the camera looks at 0.02, so it
        // is a little above the centre line - and only a little: the window is
        // the middle of the rocket's front, not its top.
        final projection = AvatarFaceProjection.forBox(box, yaw: 0, pitch: 0);

        expect(projection.centre.dy, lessThan(box.height / 2));
        expect(projection.centre.dy, greaterThan(box.height / 2 - 20));
        expect(projection.centre.dx, closeTo(box.width / 2, 0.001));
      },
    );

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
    AvatarFaceProjection at({double yaw = 0, double pitch = 0}) =>
        AvatarFaceProjection.forBox(box, yaw: yaw, pitch: pitch);

    test('facing forwards shows the whole face', () {
      expect(at().facing, 1);
    });

    test('a quarter turn still shows the face', () {
      // The window swings round to the side of the body, and the face follows
      // it rather than disappearing: a toy that loses its face the moment the
      // child turns it is a bug report, not a 3D effect.
      expect(at(yaw: math.pi / 2).facing, 1);
      expect(at(yaw: -math.pi / 2).facing, 1);
      expect(
        at(yaw: math.pi / 2).centre.dx,
        isNot(closeTo(at().centre.dx, 0.001)),
      );
    });

    test('a half turn still shows the face', () {
      expect(at(yaw: math.pi).facing, 1);
      expect(at(yaw: math.pi).centre.dy, isNot(closeTo(at().centre.dy, 0.001)));
    });

    test('a forty five degree turn does not fade the face', () {
      expect(at(yaw: math.pi / 4).facing, 1);
    });

    test('pitch never fades the face either way', () {
      expect(at(pitch: AvatarState.pitchLimit).facing, 1);
      expect(at(pitch: -AvatarState.pitchLimit).facing, 1);
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
      // the side. Which side it swings to is the builder's own quaternion
      // convention, mirrored here exactly; what matters is that the face stays
      // glued to the window it belongs to.
      expect(spun.centre.dx, isNot(closeTo(atRest.centre.dx, 0.001)));
      expect(spun.facing, 1);
    });

    test('the window constant used here is the model\'s own', () {
      // Pinned because this projection is the only thing keeping the painted
      // face on the modelled window. If these move, the face is drawn on empty
      // fuselage and no other test fails.
      expect(AvatarPorthole.radius, 0.075);
      expect(AvatarPorthole.height, 0.08);
      expect(AvatarPorthole.depth, -0.30);
    });
  });
}
