import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/controllers/avatar_controller.dart';
import 'package:kidz_planets/application/state/avatar_state.dart';

void main() {
  late AvatarController controller;

  setUp(() => controller = AvatarController());

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

    test('yaw keeps accumulating so the full 360 degrees and beyond is reachable',
        () {
      // Several full turns: a child must be able to spin it all the way around
      // and keep going, which is why yaw is deliberately not clamped.
      for (var i = 0; i < 100; i++) {
        controller.rotateBy(dx: 200, dy: 0);
      }
      expect(controller.state.yaw.abs(), greaterThan(2 * 3.14159));
    });

    test('pitch is clamped so a full vertical flip is not reachable', () {
      for (var i = 0; i < 100; i++) {
        controller.rotateBy(dx: 0, dy: 200);
      }
      expect(controller.state.pitch, AvatarState.pitchLimit);

      for (var i = 0; i < 200; i++) {
        controller.rotateBy(dx: 0, dy: -200);
      }
      expect(controller.state.pitch, -AvatarState.pitchLimit);
    });

    test('pitchClamped mirrors the stored pitch within the limit', () {
      controller.rotateBy(dx: 0, dy: 500);
      expect(controller.state.pitchClamped, AvatarState.pitchLimit);
    });
  });

  group('move', () {
    setUp(() => controller.placeAt(const Offset(100, 100)));

    test('moves in both axes', () {
      controller.moveBy(delta: const Offset(30, -20), maxPosition: const Offset(500, 500));
      expect(controller.state.screenPosition, const Offset(130, 80));
    });

    test('is clamped so the companion cannot be pushed off screen', () {
      controller.moveBy(delta: const Offset(9999, 9999), maxPosition: const Offset(500, 400));
      expect(controller.state.screenPosition, const Offset(500, 400));

      controller.moveBy(delta: const Offset(-9999, -9999), maxPosition: const Offset(500, 400));
      expect(controller.state.screenPosition, const Offset(0, 0));
    });

    test('is a no-op before the companion has been placed', () {
      final fresh = AvatarController();
      fresh.moveBy(delta: const Offset(50, 50), maxPosition: const Offset(500, 500));
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

      controller.moveBy(delta: const Offset(80, 40), maxPosition: const Offset(500, 500));

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
}
