import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:avatar/scene.dart';
import 'package:avatar/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// The companion's scene builder, checked against the rotations and ticks the
/// controller actually sends it. The projection maths that decides where the
/// painted face lands is pinned in avatar_face_projection_test.dart; what
/// matters here is that the 3D body agrees with it.
void main() {
  group('AvatarSceneBuilder.setRotation', () {
    late AvatarSceneBuilder avatar;

    setUp(
      () => avatar = AvatarSceneBuilder(
        geometries: AvatarGeometryFactory(),
        materials: AvatarMaterialFactory(),
      ),
    );

    test('a neutral pose leaves the root unrotated', () {
      avatar.setRotation(const AvatarState());

      expect(
        avatar.avatarRoot.rotation,
        closeToQuaternion(vm.Quaternion.identity()),
      );
    });

    test('yaw turns the rocket about its own up axis', () {
      avatar.setRotation(const AvatarState(yaw: 1));

      expect(avatar.avatarRoot.rotation.y, closeTo(math.sin(0.5), 1e-6));
      expect(avatar.avatarRoot.rotation.w, closeTo(math.cos(0.5), 1e-6));
    });

    test('pitch is clamped so the rocket never flips over', () {
      avatar.setRotation(const AvatarState(pitch: 5));

      final expected = vm.Quaternion.axisAngle(
        vm.Vector3(1, 0, 0),
        AvatarState.pitchLimit,
      );
      expect(avatar.avatarRoot.rotation, closeToQuaternion(expected));
    });

    test('a large negative pitch is clamped the same way', () {
      avatar.setRotation(const AvatarState(pitch: -5));

      final expected = vm.Quaternion.axisAngle(
        vm.Vector3(1, 0, 0),
        -AvatarState.pitchLimit,
      );
      expect(avatar.avatarRoot.rotation, closeToQuaternion(expected));
    });
  });

  group('AvatarSceneBuilder.tick', () {
    late AvatarSceneBuilder avatar;

    setUp(
      () => avatar = AvatarSceneBuilder(
        geometries: AvatarGeometryFactory(),
        materials: AvatarMaterialFactory(),
      ),
    );

    /// The idle animations are sine waves, so t=0 puts every hover at zero and
    /// leaves only the constant bank angles to assert on.
    void tickAtZero({
      AvatarIdleAction action = AvatarIdleAction.none,
      String? planetId,
    }) {
      avatar.tick(Duration.zero, AvatarMood.searching, action, planetId);
    }

    double bank() => avatar.bodyRoot.rotation.z;
    double hover() => avatar.bodyRoot.position.y;

    test('flying banks the rocket forward', () {
      tickAtZero(action: AvatarIdleAction.flying);

      expect(bank(), closeTo(math.sin(0.35 / 2), 1e-6));
    });

    test('thinking tips the rocket back', () {
      tickAtZero(action: AvatarIdleAction.thinking);

      expect(bank(), closeTo(math.sin(-0.15 / 2), 1e-6));
    });

    test('sitting drops the rocket and levels the wings', () {
      tickAtZero(action: AvatarIdleAction.sitting);

      expect(hover(), closeTo(-0.12, 1e-6));
      expect(bank(), 0);
    });

    test('a calm idle just bobs', () {
      tickAtZero();

      expect(hover(), 0);
      expect(bank(), 0);
    });

    test('an ice world overrides the idle action', () {
      for (final id in ['neptune', 'uranus', 'pluto']) {
        tickAtZero(action: AvatarIdleAction.sitting, planetId: id);
        expect(hover(), 0, reason: '$id floats at t=0');
        expect(bank(), 0, reason: '$id has no constant bank');
      }
    });

    test('a hot world overrides the idle action', () {
      tickAtZero(action: AvatarIdleAction.sitting, planetId: 'sun');

      expect(bank(), closeTo(math.sin(0.15 / 2), 1e-6));
    });

    test('a rocky world keeps the idle action animation', () {
      tickAtZero(action: AvatarIdleAction.sitting, planetId: 'mars');

      expect(hover(), closeTo(-0.12, 1e-6));
    });

    test('the hover animates over time', () {
      tickAtZero(action: AvatarIdleAction.flying);
      final atZero = hover();

      avatar.tick(
        const Duration(milliseconds: 500),
        AvatarMood.searching,
        AvatarIdleAction.flying,
        null,
      );

      // sin(0.5 * 6) * 0.04
      expect(hover(), closeTo(math.sin(3) * 0.04, 1e-6));
      expect(hover(), isNot(closeTo(atZero, 1e-6)));
    });
  });

  group('AvatarSceneBuilder.showTarget', () {
    late AvatarSceneBuilder avatar;

    setUp(
      () => avatar = AvatarSceneBuilder(
        geometries: AvatarGeometryFactory(),
        materials: AvatarMaterialFactory(),
      ),
    );

    test('the target remains hidden', () {
      avatar.showTarget(visible: true, color: const Color(0xFFFFFFFF));
      expect(avatar.targetPivot.visible, isFalse);
    });
  });

  group('AvatarSceneBuilder reactions', () {
    late AvatarSceneBuilder avatar;

    setUp(
      () => avatar = AvatarSceneBuilder(
        geometries: AvatarGeometryFactory(),
        materials: AvatarMaterialFactory(),
      ),
    );

    /// Ticks the rocket at [seconds] with a settled idle. Sitting holds a
    /// constant pose, so anything that changes next can only be the reaction.
    void tickAt(double seconds) => avatar.tick(
      Duration(milliseconds: (seconds * 1000).round()),
      AvatarMood.searching,
      AvatarIdleAction.sitting,
      null,
    );

    double hover() => avatar.bodyRoot.position.y;
    double bank() => avatar.bodyRoot.rotation.z;
    double spin() => avatar.bodyRoot.rotation.y;

    /// The settled sitting pose: how far down and how far round the body sits.
    const double settledHover = -0.12;

    test('a reaction starts from the settled pose, not mid-wobble', () {
      tickAt(3);
      avatar.setReaction(AvatarReaction.sad);
      tickAt(3); // the reaction clock starts at zero on this very tick

      expect(
        hover(),
        closeTo(settledHover, 1e-6),
        reason: 'nothing has arrived',
      );
      expect(bank(), closeTo(0, 1e-6));
    });

    test('a reaction eases in instead of snapping', () {
      avatar.setReaction(AvatarReaction.sad);
      tickAt(3);
      final atStart = hover();

      tickAt(3.16); // 160ms in, halfway through the 320ms fade
      final halfway = hover();

      tickAt(4); // long settled
      final full = hover();

      expect(atStart, closeTo(settledHover, 1e-6));
      // The fade is a smoothstep, and smoothstep(0.5) is exactly 0.5, so the
      // halfway pose is exactly halfway between the two.
      expect(halfway, closeTo(settledHover - 0.5 * 0.055, 1e-6));
      expect(full, closeTo(settledHover - 0.055, 1e-6));
      expect(full, lessThan(halfway));
      expect(halfway, lessThan(atStart));
    });

    test('sad droops downwards', () {
      avatar.setReaction(AvatarReaction.sad);
      tickAt(3);
      tickAt(4);

      expect(hover(), lessThan(settledHover));
      expect(bank(), lessThan(0));
    });

    test('happy bounces above the settled hover', () {
      avatar.setReaction(AvatarReaction.happy);
      tickAt(3);
      tickAt(4); // one second in, sin(14) is near its peak

      expect(hover(), greaterThan(settledHover));
    });

    test('dizzy spins the rocket about its own axis', () {
      avatar.setReaction(AvatarReaction.dizzy);
      tickAt(3);
      tickAt(4);

      expect(
        spin(),
        isNot(closeTo(0, 1e-6)),
        reason: 'a pirouette, not a nudge',
      );
      expect(bank(), isNot(closeTo(0, 1e-6)), reason: 'and a wobble with it');
    });

    test('clearing the reaction settles the rocket back down', () {
      avatar.setReaction(AvatarReaction.sad);
      tickAt(3);
      tickAt(4);
      avatar.setReaction(AvatarReaction.none);
      tickAt(5);

      expect(hover(), closeTo(settledHover, 1e-6));
      expect(bank(), closeTo(0, 1e-6));
      expect(spin(), closeTo(0, 1e-6));
    });

    test('a reaction never touches the pose the child chose', () {
      const pose = AvatarState(yaw: 1.1, pitch: -0.4);
      avatar.setRotation(pose);
      final aimed = avatar.avatarRoot.rotation.clone();

      avatar.setReaction(AvatarReaction.excited);
      tickAt(3);
      tickAt(4);

      expect(avatar.avatarRoot.rotation, closeToQuaternion(aimed));
    });

    test('the same reaction twice starts its clock again', () {
      avatar.setReaction(AvatarReaction.sad);
      tickAt(3);
      tickAt(4);
      final settled = hover();

      avatar.setReaction(AvatarReaction.none);
      tickAt(5);
      avatar.setReaction(AvatarReaction.sad);
      tickAt(6);

      expect(
        hover(),
        closeTo(settledHover, 1e-6),
        reason: 'the second sad starts from zero again',
      );
      expect(settled, lessThan(settledHover));
    });
  });
}

/// Unsigned rotation magnitude in radians, independent of the axis.
double turnAngle(vm.Quaternion q) => 2 * math.acos(q.w.abs().clamp(0.0, 1.0));

Matcher closeToQuaternion(vm.Quaternion expected) => predicate<vm.Quaternion>(
  (q) =>
      (q.x - expected.x).abs() < 1e-6 &&
      (q.y - expected.y).abs() < 1e-6 &&
      (q.z - expected.z).abs() < 1e-6 &&
      (q.w - expected.w).abs() < 1e-6,
  'is within 1e-6 of $expected',
);
