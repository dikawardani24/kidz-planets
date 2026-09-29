import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/avatar_state.dart';
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

    test('the target starts in its default pose until told otherwise', () {
      // _buildTarget hides it, but that needs a Scene, so a bare builder has
      // never run it.
      expect(avatar.targetPivot.visible, isTrue);
    });

    test('shows the target off to one side', () {
      avatar.showTarget(visible: true, color: const Color(0xFFFFFFFF));

      expect(avatar.targetPivot.visible, isTrue);
      expect(avatar.targetPivot.position.x, closeTo(-0.62, 1e-6));
      expect(avatar.targetPivot.position.y, closeTo(0.10, 1e-6));
    });

    test('hiding it does not move the target', () {
      avatar.showTarget(visible: true, color: const Color(0xFFFFFFFF));
      final shown = avatar.targetPivot.position.clone();

      avatar.showTarget(visible: false, color: const Color(0xFFFFFFFF));

      expect(avatar.targetPivot.visible, isFalse);
      expect(avatar.targetPivot.position, shown);
    });

    test('a different colour does not move the target', () {
      avatar.showTarget(visible: true, color: const Color(0xFFFFFFFF));
      final shown = avatar.targetPivot.position.clone();

      avatar.showTarget(visible: true, color: const Color(0xFFFF0000));

      expect(avatar.targetPivot.position, shown);
      expect(avatar.targetPivot.visible, isTrue);
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
