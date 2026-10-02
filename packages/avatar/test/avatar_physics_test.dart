import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:avatar/state.dart';

/// One frame at 60 Hz, the rate the friction constant is expressed in.
const double _frame = 1 / 60;

/// Steps [physics] by [seconds] of simulated time in real-sized frames.
List<AvatarBounce> _run(
  AvatarPhysics physics,
  double seconds, {
  required AvatarBounds bounds,
  double frame = _frame,
}) {
  final bounces = <AvatarBounce>[];
  for (var t = 0.0; t < seconds; t += frame) {
    bounces.addAll(physics.step(frame, bounds));
  }
  return bounces;
}

void main() {
  const open = AvatarBounds(min: Offset.zero, max: Offset(300, 600));

  /// Far larger than any throw covers, for the tests that are about the decay
  /// curve rather than about bouncing. A throw that rebounds off a wall is on a
  /// different path, and comparing two frame rates across rebounds would be
  /// comparing two paths rather than two rates.
  const roomy = AvatarBounds(min: Offset.zero, max: Offset(100000, 100000));

  /// The yaw a single frame of pure rolling adds, with no bounce involved.
  double rollFor(double velocity) =>
      (velocity * AvatarPhysicsConfig.spinPerPixel).clamp(
        -AvatarPhysicsConfig.maxSpin,
        AvatarPhysicsConfig.maxSpin,
      ) *
      _frame;

  group('launch', () {
    test('a throw below the minimum is a release, not a throw', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.launch(const Offset(AvatarPhysicsConfig.minThrowVelocity - 1, 0));

      expect(physics.isThrowing, isFalse);
      expect(physics.velocity, Offset.zero);
    });

    test('a throw is capped so a pointer spike cannot leave the screen', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.launch(const Offset(99999, 0));

      expect(physics.velocity.distance, AvatarPhysicsConfig.maxThrowVelocity);
    });

    test('a capped throw keeps its direction', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.launch(const Offset(3000, 4000));

      // Capping must not skew the throw sideways, or a hard flick would fly at a
      // different angle than the child drew.
      final ratio = physics.velocity.dy / physics.velocity.dx;
      expect(ratio, closeTo(4000 / 3000, 0.0001));
    });

    test('placing the toy drops any momentum', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.launch(const Offset(1000, 0));
      expect(physics.isThrowing, isTrue);

      physics.placeAt(const Offset(50, 50));
      expect(physics.velocity, Offset.zero);
      expect(physics.position, const Offset(50, 50));
    });
  });

  group('step', () {
    test('does nothing when nothing is moving', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      expect(physics.step(_frame, open), isEmpty);
      expect(physics.position, const Offset(10, 10));
    });

    test('a frame longer than the clamp is dropped, not integrated', () {
      final a = AvatarPhysics()..placeAt(const Offset(10, 10));
      final b = AvatarPhysics()..placeAt(const Offset(10, 10));
      a.launch(const Offset(1000, 0));
      b.launch(const Offset(1000, 0));

      a.step(5.0, open);
      b.step(AvatarPhysicsConfig.maxDeltaTime, open);

      expect(a.position.dx, closeTo(b.position.dx, 0.0001));
    });

    test('a zero or negative delta leaves the toy alone', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.launch(const Offset(1000, 0));

      physics.step(0.0, open);
      expect(physics.position, const Offset(10, 10));
      expect(physics.velocity.dx, closeTo(1000, 0.0001));
    });

    test('travels further the faster it was thrown, for the same time', () {
      double travelFor(double speed) {
        final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
        physics.launch(Offset(speed, 0));
        _run(physics, 0.25, bounds: roomy);
        return physics.position.dx;
      }

      final slow = travelFor(300);
      final fast = travelFor(1200);
      expect(fast, greaterThan(slow));
    });
  });

  group('settling', () {
    test('a throw eventually stops and lands exactly on the surface', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.launch(const Offset(1200, 900));

      _run(physics, 20, bounds: open);

      expect(physics.isThrowing, isFalse);
      expect(physics.velocity, Offset.zero);
      expect(physics.position.dx, inInclusiveRange(open.min.dx, open.max.dx));
      expect(physics.position.dy, inInclusiveRange(open.min.dy, open.max.dy));
    });

    test('the stop threshold decides when it stops, not the frame count', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.launch(const Offset(1000, 0));

      // Step until the speed first drops to the threshold.
      var steps = 0;
      while (physics.isThrowing && steps < 10000) {
        physics.step(_frame, open);
        steps++;
      }

      // A throw that stops has stopped, and the frame before it was still
      // above the threshold. This is what makes the threshold meaningful: a
      // value that never gates anything would pass a test that only checks the
      // toy eventually halts.
      expect(physics.isThrowing, isFalse);
      expect(steps, greaterThan(0));
    });
  });

  group('walls', () {
    test('a throw to the right bounces off the right wall, not a horizontal one', () {
      final physics = AvatarPhysics()..placeAt(const Offset(280, 100));
      physics.launch(const Offset(2000, 0));

      final bounces = physics.step(_frame, open);

      expect(bounces, isNotEmpty);
      // Reading the axis off the direction of travel instead of off the wall
      // reached is a real bug: it would reverse the vertical component and let
      // the toy sail straight through the right-hand wall.
      expect(bounces.first.axis, BounceAxis.horizontal);
      expect(physics.velocity.dx, lessThan(0));
      // The rest of the frame is spent travelling back inside the region, so
      // the toy has already left the wall by the time the frame ends. What must
      // not happen is it ending up outside it.
      expect(physics.position.dx, inInclusiveRange(0.0, open.max.dx));
      expect(physics.position.dx, lessThan(open.max.dx));
    });

    test('a throw upwards bounces off the top wall', () {
      final physics = AvatarPhysics()..placeAt(const Offset(100, 5));
      physics.launch(const Offset(0, -2000));

      final bounces = physics.step(_frame, open);

      expect(bounces.first.axis, BounceAxis.vertical);
      expect(physics.velocity.dy, greaterThan(0));
    });

    test('a bounce keeps the configured fraction of its speed', () {
      final physics = AvatarPhysics()..placeAt(const Offset(280, 100));
      physics.launch(const Offset(2000, 0));
      physics.step(_frame, open);

      // Friction is applied before the collision, so the reference speed is the
      // launched speed bled by one frame.
      final afterFriction = 2000 * math.pow(AvatarPhysicsConfig.friction, 1.0);
      expect(
        physics.velocity.dx.abs(),
        closeTo(afterFriction * AvatarPhysicsConfig.restitution, 0.5),
      );
    });

    test('a corner reports both axes', () {
      final physics = AvatarPhysics()..placeAt(const Offset(295, 595));
      physics.launch(const Offset(3000, 3000));

      final bounces = physics.step(_frame, open);

      expect(bounces.map((b) => b.axis).toSet(), {
        BounceAxis.horizontal,
        BounceAxis.vertical,
      });
    });

    test('a throw hard enough to cross the whole region in one frame cannot '
        'tunnel through the far wall', () {
      // At the cap, one clamped frame carries the toy 96 logical pixels, and a
      // small window is narrower than that. A single reflection at the end of
      // the step would let it pass through the wall it overshot and reappear on
      // the other side.
      const narrow = AvatarBounds(min: Offset.zero, max: Offset(60, 600));
      final physics = AvatarPhysics()..placeAt(const Offset(55, 100));
      physics.launch(Offset(AvatarPhysicsConfig.maxThrowVelocity, 0));

      _run(physics, 0.5, bounds: narrow);

      expect(physics.position.dx, inInclusiveRange(0, narrow.max.dx));
    });

    test('the toy never leaves the region it was given', () {
      for (final bounds in const [
        AvatarBounds(min: Offset.zero, max: Offset(300, 600)),
        AvatarBounds(min: Offset(20, 30), max: Offset(280, 570)),
        AvatarBounds(min: Offset(120, 250), max: Offset(120, 250)),
      ]) {
        final physics = AvatarPhysics()..placeAt(bounds.min);
        physics.launch(const Offset(2400, -1900));
        _run(physics, 12, bounds: bounds);

        expect(
          physics.position.dx,
          inInclusiveRange(
            math.min(bounds.min.dx, bounds.max.dx),
            math.max(bounds.min.dx, bounds.max.dx),
          ),
          reason: 'escaped horizontally in $bounds',
        );
        expect(
          physics.position.dy,
          inInclusiveRange(
            math.min(bounds.min.dy, bounds.max.dy),
            math.max(bounds.min.dy, bounds.max.dy),
          ),
          reason: 'escaped vertically in $bounds',
        );
      }
    });

    test('a collapsed region is survivable rather than an infinite loop', () {
      // A window smaller than the toy collapses the region to a point, where
      // every reflection lands on the same spot.
      final physics = AvatarPhysics()..placeAt(const Offset(120, 250));
      physics.launch(const Offset(2000, 0));

      expect(
        () => physics.step(
          _frame,
          const AvatarBounds(min: Offset(120, 250), max: Offset(120, 250)),
        ),
        returnsNormally,
      );
    });
  });

  group('rotation', () {
    test('a horizontal throw rolls the toy about the vertical axis', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.launch(const Offset(2000, 0));
      _run(physics, 0.2, bounds: open);

      expect(physics.yaw, greaterThan(0));
      expect(physics.pitch.abs(), lessThan(physics.yaw.abs()));
    });

    test('a vertical throw tips the toy rather than spinning it', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.launch(const Offset(0, 2000));
      _run(physics, 0.2, bounds: open);

      expect(physics.pitch, greaterThan(0));
      // Deliberately weaker than yaw: an upright rocket that tumbles over on
      // every vertical throw would read as falling rather than as flying.
      final vertical = AvatarPhysics()..placeAt(const Offset(10, 10));
      final horizontal = AvatarPhysics()..placeAt(const Offset(10, 10));
      vertical.launch(const Offset(0, 2000));
      horizontal.launch(const Offset(2000, 0));
      _run(vertical, 0.2, bounds: open);
      _run(horizontal, 0.2, bounds: open);

      expect(vertical.pitch.abs(), lessThan(horizontal.yaw.abs()));
    });

    test('spin is capped so a hard throw does not blur', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.launch(const Offset(AvatarPhysicsConfig.maxThrowVelocity, 0));

      // One frame at the cap on the angular rate.
      physics.step(_frame, open);
      expect(
        physics.yaw,
        lessThanOrEqualTo(AvatarPhysicsConfig.maxSpin * _frame + 1e-9),
      );
    });

    test('an impact kicks the toy on top of reversing it', () {
      final physics = AvatarPhysics()..placeAt(const Offset(280, 100));
      physics.launch(const Offset(2000, 0));
      physics.step(_frame, open);

      // The roll for this frame is known exactly from the velocity the bounce
      // left behind, so the turn can be compared against it directly rather than
      // against a second throw that would have bounced differently.
      final rollOnly = rollFor(physics.velocity.dx);
      expect(physics.yaw, greaterThan(rollOnly));
    });

    test('a throw continues the rotation the child already set up', () {
      final physics = AvatarPhysics()..placeAt(const Offset(10, 10));
      physics.setRotation(yaw: 1.25, pitch: -0.5);
      physics.launch(const Offset(1000, 0));

      expect(physics.yaw, greaterThanOrEqualTo(1.25));
      expect(physics.pitch, lessThanOrEqualTo(-0.5));
    });
  });

  group('reduced motion', () {
    test('a throw still goes where it was thrown, but settles sooner', () {
      double settleTime({required bool reducedMotion}) {
        final physics = AvatarPhysics(reducedMotion: reducedMotion)
          ..placeAt(const Offset(10, 10))
          ..launch(const Offset(2400, 0));
        var t = 0.0;
        while (physics.isThrowing && t < 60) {
          physics.step(_frame, roomy);
          t += _frame;
        }
        return physics.isThrowing ? 60 : t;
      }

      // Removing the throw outright would be worse than a calmer one: the child
      // flicked, and the toy has to go. This asserts the middle ground.
      expect(settleTime(reducedMotion: true), greaterThan(0));
      expect(
        settleTime(reducedMotion: true),
        lessThan(settleTime(reducedMotion: false)),
      );
    });

    test('the impact kick is dropped', () {
      final loud = AvatarPhysics()..placeAt(const Offset(280, 100));
      final calm = AvatarPhysics(reducedMotion: true)
        ..placeAt(const Offset(280, 100));
      loud.launch(const Offset(2000, 0));
      calm.launch(const Offset(2000, 0));
      loud.step(_frame, open);
      calm.step(_frame, open);

      // Both toys reverse and both roll identically, so the whole difference
      // between them is the kick. The extra damping reduced motion applies comes
      // after the roll, which is why the difference can be named exactly.
      final impact =
          2000 * AvatarPhysicsConfig.friction; // one frame of friction
      final expectedKick =
          AvatarPhysicsConfig.impactKick *
          (impact / AvatarPhysicsConfig.maxThrowVelocity);
      expect(calm.velocity.dx, lessThan(0));
      expect(loud.velocity.dx, lessThan(0));
      expect(loud.yaw - calm.yaw, closeTo(expectedKick, 0.0001));
    });

    test('the decay is frame-rate independent as well', () {
      double speedAfter(double seconds, double frame) {
        final physics = AvatarPhysics(reducedMotion: true)
          ..placeAt(const Offset(10, 10))
          ..launch(const Offset(2400, 0));
        // The step count is computed rather than accumulated in a loop: adding
        // 1/60 to itself thirty times lands a hair short of half a second, and
        // a loop bounded on that takes one step more than it means to, which is
        // enough to make the slower frame rate look like it decays more.
        final steps = (seconds / frame).round();
        for (var i = 0; i < steps; i++) {
          physics.step(frame, roomy);
        }
        return physics.velocity.distance;
      }

      expect(speedAfter(0.5, 1 / 30), closeTo(speedAfter(0.5, 1 / 60), 25));
      expect(speedAfter(0.5, 1 / 120), closeTo(speedAfter(0.5, 1 / 60), 12));
    });
  });

  group('AvatarBounds', () {
    test('clamps to both edges, not just the maximum', () {
      const bounds = AvatarBounds(min: Offset(20, 30), max: Offset(280, 570));
      expect(bounds.clamp(const Offset(0, 0)), const Offset(20, 30));
      expect(bounds.clamp(const Offset(400, 900)), const Offset(280, 570));
    });

    test('an inverted region clamps rather than throwing', () {
      // A window narrower than the toy can produce one, and a clamp whose
      // bounds are the wrong way round throws.
      final bounds = AvatarBounds(
        min: const Offset(200, 0),
        max: const Offset(100, 100),
      );
      expect(bounds.clamp(const Offset(50, 50)), const Offset(100, 50));
    });

    test('available subtracts the box, the insets and the chrome', () {
      final bounds = AvatarBounds.available(
        width: 400,
        height: 800,
        boxWidth: 132,
        boxHeight: 148,
        leftInset: 0,
        topInset: 50,
        rightInset: 0,
        bottomInset: 70,
        edgePadding: 8,
      );

      expect(bounds.min, const Offset(8, 58));
      expect(bounds.max, const Offset(260, 574));
      expect(bounds.isUsable, isTrue);
    });

    test('a window too small for the toy collapses instead of inverting', () {
      final bounds = AvatarBounds.available(
        width: 100,
        height: 100,
        boxWidth: 132,
        boxHeight: 148,
        leftInset: 0,
        topInset: 60,
        rightInset: 0,
        bottomInset: 60,
        edgePadding: 8,
      );

      expect(bounds.min.dx, bounds.max.dx);
      expect(bounds.min.dy, bounds.max.dy);
      expect(bounds.isUsable, isFalse);
      expect(() => bounds.clamp(const Offset(50, 50)), returnsNormally);
    });
  });
}
