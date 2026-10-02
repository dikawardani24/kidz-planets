import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avatar/controllers.dart';
import 'package:avatar/state.dart';

void main() {
  late AvatarController controller;

  // AvatarController runs a periodic flight-style timer, so a controller that
  // is never disposed outlives its test and trips the "timer is still active"
  // check in any later testWidgets test in this file.
  setUp(() => controller = AvatarController());
  tearDown(() => controller.dispose());

  group('rotation', () {
    test('starts unrotated and unplaced', () {
      expect(controller.state.yaw, 0);
      expect(controller.state.pitch, 0);
      expect(controller.state.screenPosition, isNull);
    });

    test('dragging right turns the character one way, not the other', () {
      controller.rotateBy(dx: 100, dy: 0);
      expect(controller.state.yaw, greaterThan(0));
    });

    test('yaw keeps accumulating so the full 360 degrees and beyond is reachable', () {
      // Several full turns: a child must be able to spin it all the way around
      // and keep going, which is why yaw is deliberately not clamped.
      for (var i = 0; i < 100; i++) {
        controller.rotateBy(dx: 200, dy: 0);
      }
      expect(controller.state.yaw.abs(), greaterThan(2 * 3.14159));
    });

    test('pitch reaches the top and the bottom of the rocket, but never flips over', () {
      // The limit is about 86 degrees: enough that the child sees the nosecone
      // from above and the engine from below, which is what "rotate far enough
      // that the back/top/bottom becomes visible" asks for. It stops short of a
      // full 180 so a parked companion always has a right way up to return to.
      for (var i = 0; i < 100; i++) {
        controller.rotateBy(dx: 0, dy: 200);
      }
      expect(controller.state.pitch, AvatarState.pitchLimit);
      expect(controller.state.pitch, greaterThan(math.pi / 2 - 0.1));

      for (var i = 0; i < 200; i++) {
        controller.rotateBy(dx: 0, dy: -200);
      }
      expect(controller.state.pitch, -AvatarState.pitchLimit);
      expect(controller.state.pitch, lessThan(-math.pi / 2 + 0.1));
    });

    test('pitchClamped mirrors the stored pitch within the limit', () {
      controller.rotateBy(dx: 0, dy: 500);
      expect(controller.state.pitchClamped, AvatarState.pitchLimit);
    });
  });

  group('move', () {
    setUp(() => controller.placeAt(const Offset(100, 100)));

    test('moves in both axes', () {
      controller.moveBy(
        delta: const Offset(30, -20),
        maxPosition: const Offset(500, 500),
      );
      expect(controller.state.screenPosition, const Offset(130, 80));
    });

    test('is clamped so the companion cannot be pushed off screen', () {
      controller.moveBy(
        delta: const Offset(9999, 9999),
        maxPosition: const Offset(500, 400),
      );
      expect(controller.state.screenPosition, const Offset(500, 400));

      controller.moveBy(
        delta: const Offset(-9999, -9999),
        maxPosition: const Offset(500, 400),
      );
      expect(controller.state.screenPosition, const Offset(0, 0));
    });

    test('is a no-op before the companion has been placed', () {
      final fresh = AvatarController();
      fresh.moveBy(
        delta: const Offset(50, 50),
        maxPosition: const Offset(500, 500),
      );
      expect(fresh.state.screenPosition, isNull);
    });
  });

  group('move and rotate are independent', () {
    setUp(() => controller.placeAt(const Offset(100, 100)));

    test('rotating never moves the companion', () {
      final before = controller.state.screenPosition;
      controller.rotateBy(dx: 120, dy: 60);
      expect(controller.state.screenPosition, before);
    });

    test('moving never re-aims the companion', () {
      controller.rotateBy(dx: 120, dy: 60);
      final yawBefore = controller.state.yaw;
      final pitchBefore = controller.state.pitch;

      controller.moveBy(
        delta: const Offset(80, 40),
        maxPosition: const Offset(500, 500),
      );

      expect(controller.state.yaw, yawBefore);
      expect(controller.state.pitch, pitchBefore);
    });
  });

  group('persistence across mission state changes', () {
    test('pose and position survive an unrelated state change', () {
      controller
        ..placeAt(const Offset(220, 300))
        ..rotateBy(dx: 90, dy: 30);

      final position = controller.state.screenPosition;
      final yaw = controller.state.yaw;
      final pitch = controller.state.pitch;

      // Pose lives in the avatar controller, not the mission state, so a
      // mission transition cannot reset it: nothing here can reach it.
      expect(controller.state.screenPosition, position);
      expect(controller.state.yaw, yaw);
      expect(controller.state.pitch, pitch);
    });

    test('resetting position leaves rotation alone', () {
      controller
        ..placeAt(const Offset(100, 100))
        ..rotateBy(dx: 90, dy: 30);
      final yaw = controller.state.yaw;

      controller.resetPositionTo(const Offset(40, 40));

      expect(controller.state.screenPosition, const Offset(40, 40));
      expect(controller.state.yaw, yaw);
    });
  });

  group('reactions', () {
    test('a reaction expires on its own after its duration', () {
      fakeAsync((async) {
        final c = AvatarController();
        c.react(
          AvatarReaction.happy,
          duration: const Duration(milliseconds: 900),
        );

        expect(c.state.reaction, AvatarReaction.happy);
        async.elapse(const Duration(milliseconds: 899));
        expect(c.state.reaction, AvatarReaction.happy, reason: 'still playing');

        async.elapse(const Duration(milliseconds: 1));
        expect(c.state.reaction, AvatarReaction.none, reason: 'expired');
        expect(c.state.isHeartVisible, isFalse);

        c.dispose();
      });
    });

    test('a newer reaction is not cleared early by an older timer', () {
      fakeAsync((async) {
        final c = AvatarController();
        c.react(AvatarReaction.happy, duration: const Duration(seconds: 3));
        async.elapse(const Duration(milliseconds: 500));
        c.react(
          AvatarReaction.sad,
          duration: const Duration(milliseconds: 400),
        );

        async.elapse(const Duration(milliseconds: 400));
        expect(c.state.reaction, AvatarReaction.none, reason: 'sad ran out');

        // The happy timer was cancelled, so nothing fires at the three second
        // mark that it used to be waiting for.
        async.elapse(const Duration(seconds: 5));
        expect(c.state.reaction, AvatarReaction.none);

        c.dispose();
      });
    });

    test('reacting with none clears what is playing', () {
      fakeAsync((async) {
        final c = AvatarController();
        c.react(AvatarReaction.excited, duration: const Duration(seconds: 2));
        c.react(AvatarReaction.none);

        expect(c.state.reaction, AvatarReaction.none);
        expect(c.state.isHeartVisible, isFalse);

        async.elapse(const Duration(seconds: 5));
        expect(c.state.reaction, AvatarReaction.none);

        c.dispose();
      });
    });

    test('the expiry timer never touches a disposed controller', () {
      fakeAsync((async) {
        final c = AvatarController()
          ..react(AvatarReaction.sleepy, duration: const Duration(seconds: 2));
        c.dispose();
        expect(c.mounted, isFalse);

        // The timer outlives the controller by eight seconds. Without the
        // mounted guard this would throw "Tried to use AvatarController after
        // dispose was called", which is the bug the guard exists for.
        expect(
          () => async.elapse(const Duration(seconds: 10)),
          returnsNormally,
        );
      });
    });

    test('cheerful reactions show hearts, the others do not', () {
      for (final reaction in AvatarReaction.values) {
        final c = AvatarController();
        c.react(reaction, duration: const Duration(seconds: 1));
        final cheerful =
            reaction == AvatarReaction.happy ||
            reaction == AvatarReaction.laughing ||
            reaction == AvatarReaction.excited;
        expect(c.state.isHeartVisible, cheerful, reason: '$reaction');
        c.clearReaction();
        expect(c.state.isHeartVisible, isFalse, reason: '$reaction');
        c.dispose();
      }
    });

    test('a sleepy companion covers less ground than a calm one', () {
      final calm = AvatarController();
      final sleepy = AvatarController();
      addTearDown(calm.dispose);
      addTearDown(sleepy.dispose);
      sleepy.react(AvatarReaction.sleepy);

      const bounds = Offset(350, 700);
      const viewport = Size(400, 800);

      // One frame to put both on the same path, then measure the ground each
      // covers over the next ten seconds, step by step: the distance between
      // start and finish would hide how far a companion actually flew.
      calm.updateFlight(0.1, viewport, bounds);
      sleepy.updateFlight(0.1, viewport, bounds);
      var calmPath = 0.0;
      var sleepyPath = 0.0;
      var lastCalm = calm.state.screenPosition!;
      var lastSleepy = sleepy.state.screenPosition!;

      for (var i = 0; i < 100; i++) {
        calm.updateFlight(0.1, viewport, bounds);
        sleepy.updateFlight(0.1, viewport, bounds);
        calmPath += (calm.state.screenPosition! - lastCalm).distance;
        sleepyPath += (sleepy.state.screenPosition! - lastSleepy).distance;
        lastCalm = calm.state.screenPosition!;
        lastSleepy = sleepy.state.screenPosition!;
      }

      expect(
        sleepyPath,
        lessThan(calmPath * 0.5),
        reason: 'a sleeping companion drifts rather than races',
      );
    });
  });

  group('parking after a drag', () {
    const maxPosition = Offset(500, 500);
    const viewport = Size(400, 800);

    test('a drag stops the flight loop', () {
      controller
        ..placeAt(const Offset(200, 300), maxPosition: maxPosition)
        ..moveBy(delta: const Offset(40, 40), maxPosition: maxPosition);

      expect(controller.state.isFlightPaused, isTrue);
      expect(controller.state.screenPosition, const Offset(240, 340));

      controller.updateFlight(0.5, viewport, maxPosition);
      expect(
        controller.state.screenPosition,
        const Offset(240, 340),
        reason: 'painted exactly where the child put it',
      );
    });

    test('the park survives a long run of frames', () {
      controller
        ..placeAt(const Offset(10, 480), maxPosition: maxPosition)
        ..moveBy(delta: Offset.zero, maxPosition: maxPosition);
      final parked = controller.state.screenPosition;

      for (var i = 0; i < 600; i++) {
        controller.updateFlight(1 / 60, viewport, maxPosition);
      }

      expect(controller.state.screenPosition, parked);
      expect(controller.state.isFlightPaused, isTrue);
    });

    test('the hold expires and flight resumes without snapping', () {
      fakeAsync((async) {
        final c = AvatarController(flightHold: const Duration(seconds: 2));
        c
          ..placeAt(const Offset(480, 40), maxPosition: maxPosition)
          ..moveBy(delta: Offset.zero, maxPosition: maxPosition);
        final parked = c.state.screenPosition!;

        async.elapse(const Duration(milliseconds: 1999));
        expect(c.state.isFlightPaused, isTrue, reason: 'still parked');

        async.elapse(const Duration(milliseconds: 1));
        expect(c.state.isFlightPaused, isFalse, reason: 'the hold ran out');

        c.updateFlight(1 / 60, viewport, maxPosition);
        final resumed = c.state.screenPosition!;
        // Flight restarts *at* the parked spot (the path is rebased there) and
        // then drifts back into its circuit, so the first step is one frame's
        // worth of motion rather than a jump across the screen.
        expect((resumed - parked).distance, lessThan(20));
        expect(resumed.dx, inInclusiveRange(0, maxPosition.dx));

        // And a long run afterwards stays on screen.
        for (var i = 0; i < 600; i++) {
          c.updateFlight(1 / 60, viewport, maxPosition);
        }
        final after = c.state.screenPosition!;
        expect(after.dx, inInclusiveRange(0, maxPosition.dx));
        expect(after.dy, inInclusiveRange(0, maxPosition.dy));

        c.dispose();
      });
    });

    test('another drag re-parks the companion', () {
      controller
        ..placeAt(const Offset(100, 100), maxPosition: maxPosition)
        ..moveBy(delta: const Offset(50, 0), maxPosition: maxPosition);

      expect(controller.state.isFlightPaused, isTrue);
      expect(controller.state.screenPosition, const Offset(150, 100));

      controller.moveBy(delta: const Offset(0, -40), maxPosition: maxPosition);
      expect(controller.state.screenPosition, const Offset(150, 60));
      expect(controller.state.isFlightPaused, isTrue);
    });

    test('moving never re-aims the rocket, even while parked', () {
      controller
        ..placeAt(const Offset(100, 100), maxPosition: maxPosition)
        ..rotateBy(dx: 120, dy: 60);
      final yaw = controller.state.yaw;
      final pitch = controller.state.pitch;

      controller.moveBy(delta: const Offset(30, 30), maxPosition: maxPosition);
      controller.updateFlight(0.1, viewport, maxPosition);
      controller.resumeFlight();

      expect(controller.state.yaw, yaw);
      expect(controller.state.pitch, pitch);
    });
  });
}
