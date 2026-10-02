import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets/scene.dart';
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
      expect(
        builder.states['mars']!.spinNode.rotation,
        vm.Quaternion.identity(),
      );
      expect(builder.solarSystemRoot.rotation, vm.Quaternion.identity());
    });

    test('a sub-pixel planet drag is ignored', () {
      addBody(builder, 'earth');

      builder.rotatePlanet('earth', 0.0001, 0.0001);

      expect(
        builder.states['earth']!.spinNode.rotation,
        vm.Quaternion.identity(),
      );
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
