import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/avatar_state.dart' hide AvatarMood;
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_geometry.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_materials.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_scene_builder.dart';
import 'package:kidz_planets/infrastructure/scene/solar_system_scene_builder.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'helpers/scene_stubs.dart';

void main() {
  group('SolarSystemSceneBuilder.setPlanetOrbitRadius', () {
    late SolarSystemSceneBuilder builder;

    setUp(() => builder = makeSceneBuilder());

    test('rescales a body along its existing angle', () {
      final body = addBody(builder, 'earth', position: vm.Vector3(3, 0, 4));

      builder.setPlanetOrbitRadius('earth', 50);

      expect(body.node.position.x, closeTo(30, 1e-9));
      expect(body.node.position.z, closeTo(40, 1e-9));
    });

    test('flattens a body onto the orbit plane', () {
      final body = addBody(builder, 'earth', position: vm.Vector3(3, 7, 4));

      builder.setPlanetOrbitRadius('earth', 5);

      expect(body.node.position.y, 0);
    });

    test('puts a body at the origin on the positive x axis', () {
      final body = addBody(builder, 'earth');

      builder.setPlanetOrbitRadius('earth', 7);

      expect(body.node.position.x, closeTo(7, 1e-9));
      expect(body.node.position.z, closeTo(0, 1e-9));
    });

    test('ignores an unknown planet', () {
      expect(() => builder.setPlanetOrbitRadius('nope', 5), returnsNormally);
    });
  });

  group('SolarSystemSceneBuilder rotation', () {
    late SolarSystemSceneBuilder builder;

    setUp(() => builder = makeSceneBuilder());

    test('a drag turns the whole system', () {
      builder.rotateSolarSystem(10, 0);

      expect(builder.solarSystemRoot.rotation, isNot(vm.Quaternion.identity()));
    });

    test('a sub-pixel drag is ignored', () {
      builder.rotateSolarSystem(0.0001, 0.0001);

      expect(builder.solarSystemRoot.rotation, vm.Quaternion.identity());
    });

    test('a longer drag turns the system further', () {
      builder.rotateSolarSystem(1, 0);
      final small = turnAngle(builder.solarSystemRoot.rotation);
      builder.rotateSolarSystem(1, 0);
      final doubled = turnAngle(builder.solarSystemRoot.rotation);

      expect(small, greaterThan(0));
      expect(doubled, greaterThan(small));
    });

    test('a drag turns only the targeted planet', () {
      addBody(builder, 'earth');
      addBody(builder, 'mars');

      builder.rotatePlanet('earth', 10, 0);

      final earth = builder.states['earth']!.spinNode.rotation;
      expect(earth, isNot(vm.Quaternion.identity()));
      expect(builder.states['mars']!.spinNode.rotation, vm.Quaternion.identity());
      expect(builder.solarSystemRoot.rotation, vm.Quaternion.identity());
    });

    test('a sub-pixel planet drag is ignored', () {
      addBody(builder, 'earth');

      builder.rotatePlanet('earth', 0.0001, 0.0001);

      expect(builder.states['earth']!.spinNode.rotation, vm.Quaternion.identity());
    });

    test('dragging an unknown planet is ignored', () {
      expect(() => builder.rotatePlanet('nope', 10, 0), returnsNormally);
    });

    test('angular velocity is the same gesture per unit of time', () {
      final byGesture = makeSceneBuilder();
      byGesture.rotateSolarSystem(1, 0);

      final byVelocity = makeSceneBuilder();
      byVelocity.rotateSolarSystemAngularVelocity(0.009, 0, 1);

      expect(
        byVelocity.solarSystemRoot.rotation.x,
        closeTo(byGesture.solarSystemRoot.rotation.x, 1e-6),
      );
      expect(
        byVelocity.solarSystemRoot.rotation.w,
        closeTo(byGesture.solarSystemRoot.rotation.w, 1e-6),
      );
    });

    test('a planet angular velocity matches the same gesture', () {
      addBody(builder, 'earth');

      final byGesture = makeSceneBuilder();
      addBody(byGesture, 'earth');
      byGesture.rotatePlanet('earth', 0.4, 0.2);

      builder.rotatePlanetAngularVelocity('earth', 0.0036, 0.0018, 1);

      expect(
        builder.states['earth']!.spinNode.rotation.y,
        closeTo(byGesture.states['earth']!.spinNode.rotation.y, 1e-6),
      );
    });
  });

  group('SolarSystemSceneBuilder.setOrbitsVisible', () {
    test('hides every orbit path at once', () {
      final builder = makeSceneBuilder();
      for (final id in ['earth', 'mars', 'venus']) {
        builder.orbitNodes[id] = Node();
      }

      builder.setOrbitsVisible(false);

      expect(builder.orbitNodes.values.every((n) => !n.visible), isTrue);
    });

    test('shows them again', () {
      final builder = makeSceneBuilder();
      builder.orbitNodes['earth'] = Node()..visible = false;

      builder.setOrbitsVisible(true);

      expect(builder.orbitNodes['earth']!.visible, isTrue);
    });

    test('is harmless with no orbits built', () {
      expect(() => makeSceneBuilder().setOrbitsVisible(false), returnsNormally);
    });
  });

  group('AvatarSceneBuilder.setRotation', () {
    late AvatarSceneBuilder avatar;

    setUp(() => avatar = AvatarSceneBuilder(
          geometries: AvatarGeometryFactory(),
          materials: AvatarMaterialFactory(),
        ));

    test('a neutral pose leaves the root unrotated', () {
      avatar.setRotation(const AvatarState());

      expect(avatar.avatarRoot.rotation, closeToQuaternion(vm.Quaternion.identity()));
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

    setUp(() => avatar = AvatarSceneBuilder(
          geometries: AvatarGeometryFactory(),
          materials: AvatarMaterialFactory(),
        ));

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

    setUp(() => avatar = AvatarSceneBuilder(
          geometries: AvatarGeometryFactory(),
          materials: AvatarMaterialFactory(),
        ));

    test('the target remains hidden', () {
      avatar.showTarget(visible: true, color: const Color(0xFFFFFFFF));
      expect(avatar.targetPivot.visible, isFalse);
    });
  });

  group('AvatarSceneBuilder reactions', () {
    late AvatarSceneBuilder avatar;

    setUp(() => avatar = AvatarSceneBuilder(
          geometries: AvatarGeometryFactory(),
          materials: AvatarMaterialFactory(),
        ));

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

      expect(hover(), closeTo(settledHover, 1e-6), reason: 'nothing has arrived');
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

      expect(spin(), isNot(closeTo(0, 1e-6)), reason: 'a pirouette, not a nudge');
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

      expect(hover(), closeTo(settledHover, 1e-6),
          reason: 'the second sad starts from zero again');
      expect(settled, lessThan(settledHover));
    });
  });

}

/// Unsigned rotation magnitude in radians, independent of the axis.
double turnAngle(vm.Quaternion q) => 2 * math.acos(q.w.abs().clamp(0.0, 1.0));

Matcher closeToQuaternion(vm.Quaternion expected) => predicate<vm.Quaternion>(
      (q) => (q.x - expected.x).abs() < 1e-6 &&
          (q.y - expected.y).abs() < 1e-6 &&
          (q.z - expected.z).abs() < 1e-6 &&
          (q.w - expected.w).abs() < 1e-6,
      'is within 1e-6 of $expected',
    );
