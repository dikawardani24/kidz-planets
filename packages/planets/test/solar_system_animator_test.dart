import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:core/time.dart';
import 'package:planets/domain.dart';
import 'package:planets/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'helpers/scene_stubs.dart';

/// Signed rotation about +Y, in radians.
double yAngle(vm.Quaternion q) => math.atan2(q.y, q.w) * 2;

void main() {
  late SimulationClock clock;

  setUp(() => clock = SimulationClock());

  SolarSystemAnimator animatorFor(
    SolarSystemSceneBuilder builder,
    List<Planet> planets,
  ) {
    final animator = SolarSystemAnimator(
      clock: clock,
      builder: builder,
      planets: planets,
    );
    addTearDown(animator.detach);
    return animator;
  }

  group('tick', () {
    test('does nothing before the scene has any bodies', () {
      final builder = makeSceneBuilder();
      final animator = animatorFor(builder, [testPlanet()]);

      expect(() => animator.tick(0.016), returnsNormally);
    });

    test('places a planet on its orbit at the clock time', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [
        testPlanet(orbitRadius: 10, orbitSpeed: 0.2, startAngle: 0),
      ]);

      clock.tick(0.5);
      animator.tick(0.016);

      // angle = startAngle + 0.5 * 0.2 = 0.1
      expect(body.node.position.x, closeTo(math.cos(0.1) * 10, 1e-5));
      expect(body.node.position.y, 0);
      expect(body.node.position.z, closeTo(math.sin(0.1) * 10, 1e-5));
    });

    test('honours the starting angle', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [
        testPlanet(orbitRadius: 10, orbitSpeed: 0, startAngle: math.pi / 2),
      ]);

      animator.tick(0.016);

      expect(body.node.position.x, closeTo(0, 1e-5));
      expect(body.node.position.z, closeTo(10, 1e-5));
    });

    test('respects the simulation speed', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [
        testPlanet(orbitRadius: 10, orbitSpeed: 0.2),
      ]);

      clock.setSpeed(2);
      clock.tick(0.5);
      animator.tick(0.016);

      // The clock advanced a full second, so the angle is 0.2 not 0.1.
      expect(body.node.position.z, closeTo(math.sin(0.2) * 10, 1e-5));
    });

    test('never orbits the sun', () {
      final builder = makeSceneBuilder();
      final sun = addBody(
        builder,
        'sun',
        position: vm.Vector3(0, 0, 0),
        isSun: true,
      );
      final animator = animatorFor(builder, [
        testPlanet(id: 'sun', isSun: true, orbitRadius: 30, orbitSpeed: 0.5),
      ]);

      sun.node.position = vm.Vector3(1, 2, 3);
      clock.tick(1);
      animator.tick(0.016);

      expect(sun.node.position, vm.Vector3(1, 2, 3));
    });

    test('leaves a body with no orbit at its own position', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth', position: vm.Vector3(4, 5, 6));
      final animator = animatorFor(builder, [
        testPlanet(orbitRadius: 0, orbitSpeed: 1),
      ]);

      clock.tick(1);
      animator.tick(0.016);

      expect(body.node.position, vm.Vector3(4, 5, 6));
    });

    test('skips a render state with no matching planet', () {
      final builder = makeSceneBuilder();
      final ghost = addBody(builder, 'ghost', position: vm.Vector3(1, 1, 1));
      final animator = animatorFor(builder, [testPlanet()]);

      clock.tick(1);
      animator.tick(0.016);

      expect(ghost.node.position, vm.Vector3(1, 1, 1));
      expect(yAngle(ghost.spinNode.rotation), 0);
    });
  });

  group('moons', () {
    test('orbit their parent rather than the sun', () {
      final builder = makeSceneBuilder();
      // Insertion order matters: the parent has to be advanced first.
      final earth = addBody(builder, 'earth');
      final moon = addBody(builder, 'moon');
      final animator = animatorFor(builder, [
        testPlanet(id: 'earth', orbitRadius: 10, orbitSpeed: 0.2),
        testPlanet(
          id: 'moon',
          isMoon: true,
          parentPlanetId: 'earth',
          orbitRadius: 1,
          orbitSpeed: 0.4,
        ),
      ]);

      clock.tick(0.5);
      animator.tick(0.016);

      final earthAngle = 0.1;
      final moonAngle = 0.2;
      expect(
        moon.node.position.x,
        closeTo(math.cos(earthAngle) * 10 + math.cos(moonAngle), 1e-5),
      );
      expect(
        moon.node.position.z,
        closeTo(math.sin(earthAngle) * 10 + math.sin(moonAngle), 1e-5),
      );
      expect(moon.node.position.y, earth.node.position.y);
    });

    test('stay put while their parent is missing', () {
      final builder = makeSceneBuilder();
      final moon = addBody(builder, 'moon', position: vm.Vector3(7, 7, 7));
      final animator = animatorFor(builder, [
        testPlanet(
          id: 'moon',
          isMoon: true,
          parentPlanetId: 'nope',
          orbitRadius: 1,
        ),
      ]);

      clock.tick(1);
      animator.tick(0.016);

      expect(moon.node.position, vm.Vector3(7, 7, 7));
    });
  });

  group('setOrbitRadius', () {
    test('rescales a body while keeping it on the same angle', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth', position: vm.Vector3(3, 0, 4));
      final animator = animatorFor(builder, [testPlanet()]);

      animator.setOrbitRadius('earth', 50);

      // atan2(4, 3) is the 3-4-5 angle, so x and z scale to 30 and 40.
      expect(body.node.position.x, closeTo(30, 1e-5));
      expect(body.node.position.y, 0);
      expect(body.node.position.z, closeTo(40, 1e-5));
    });

    test('places a body sitting at the origin on the positive x axis', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [testPlanet()]);

      animator.setOrbitRadius('earth', 7);

      expect(body.node.position.x, closeTo(7, 1e-5));
      expect(body.node.position.z, closeTo(0, 1e-5));
    });

    test('ignores an unknown planet', () {
      final builder = makeSceneBuilder();
      final animator = animatorFor(builder, [testPlanet()]);

      expect(() => animator.setOrbitRadius('nope', 5), returnsNormally);
    });

    test('takes precedence over the catalogue orbit on the next tick', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [
        testPlanet(orbitRadius: 10, orbitSpeed: 0, startAngle: 0),
      ]);

      animator.setOrbitRadius('earth', 50);
      animator.tick(0.016);

      expect(body.node.position.x, closeTo(50, 1e-5));
    });

    test('resetOrbitRadius hands the body back to the catalogue', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [
        testPlanet(orbitRadius: 10, orbitSpeed: 0, startAngle: 0),
      ]);

      animator.setOrbitRadius('earth', 50);
      animator.resetOrbitRadius('earth');
      animator.tick(0.016);

      expect(body.node.position.x, closeTo(10, 1e-5));
    });

    test('detach drops every override', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [
        testPlanet(orbitRadius: 10, orbitSpeed: 0, startAngle: 0),
      ]);

      animator.setOrbitRadius('earth', 50);
      animator.detach();
      animator.tick(0.016);

      expect(body.node.position.x, closeTo(10, 1e-5));
    });
  });

  group('setFocusedPlanet', () {
    test('freezes the focused body so the camera does not chase it', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth', position: vm.Vector3(2, 0, 2));
      final animator = animatorFor(builder, [
        testPlanet(orbitRadius: 10, orbitSpeed: 1),
      ]);

      animator.setFocusedPlanet('earth');
      clock.tick(1);
      animator.tick(0.016);

      expect(body.node.position, vm.Vector3(2, 0, 2));
    });

    test('keeps spinning the focused body', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [testPlanet()]);

      animator.setFocusedPlanet('earth');
      animator.tick(0.5);

      expect(yAngle(body.spinNode.rotation), closeTo(0.12 * 0.5, 1e-7));
    });

    test('clearing the focus resumes the orbit', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [
        testPlanet(orbitRadius: 10, orbitSpeed: 0, startAngle: 0),
      ]);

      animator.setFocusedPlanet('earth');
      animator.setFocusedPlanet(null);
      animator.tick(0.016);

      expect(body.node.position.x, closeTo(10, 1e-5));
    });
  });

  group('spin', () {
    double spinAfter(
      Planet planet,
      double dt, {
      void Function(SolarSystemAnimator)? boost,
    }) {
      final builder = makeSceneBuilder();
      final body = addBody(builder, planet.id);
      final animator = animatorFor(builder, [planet]);
      boost?.call(animator);
      animator.tick(dt);
      return yAngle(body.spinNode.rotation);
    }

    test('a planet spins faster than the sun', () {
      final planet = spinAfter(testPlanet(), 1);
      final sun = spinAfter(testPlanet(id: 'sun', isSun: true), 1);

      expect(planet, closeTo(0.12, 1e-7));
      expect(sun, closeTo(0.02, 1e-7));
    });

    test('a moon spins fastest of all', () {
      final moon = spinAfter(testPlanet(id: 'moon', isMoon: true), 1);

      expect(moon, closeTo(0.18, 1e-7));
    });

    test('accumulates across frames', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [testPlanet()]);

      animator.tick(0.5);
      animator.tick(0.5);

      expect(yAngle(body.spinNode.rotation), closeTo(0.12, 1e-7));
    });

    test('a swipe adds momentum', () {
      final spun = spinAfter(
        testPlanet(),
        1,
        boost: (a) => a.addSpinBoost(0.08),
      );

      // The decay runs at the top of the tick, so a boost applied since the
      // last frame already contributes 95% of its value.
      expect(spun, closeTo(0.12 + 0.08 * 0.95, 1e-7));
    });

    test('momentum decays by five percent per frame', () {
      final builder = makeSceneBuilder();
      final body = addBody(builder, 'earth');
      final animator = animatorFor(builder, [testPlanet()]);

      animator.addSpinBoost(0.2);
      animator.tick(1);
      final first = yAngle(body.spinNode.rotation);
      expect(first, closeTo(0.12 + 0.2 * 0.95, 1e-7));

      animator.tick(1);
      // Each tick multiplies the boost by 0.95 before applying it.
      expect(
        yAngle(body.spinNode.rotation),
        closeTo(first + 0.12 + 0.2 * 0.95 * 0.95, 1e-7),
      );
    });

    test('boost is capped in both directions', () {
      final capped = spinAfter(
        testPlanet(),
        1,
        boost: (a) => a.addSpinBoost(99),
      );
      final floored = spinAfter(
        testPlanet(),
        1,
        boost: (a) => a.addSpinBoost(-99),
      );

      expect(capped, closeTo(0.12 + 0.2 * 0.95, 1e-7));
      expect(floored, closeTo(0.12 - 0.2 * 0.95, 1e-7));
    });

    test('boosts accumulate up to the cap', () {
      final spun = spinAfter(
        testPlanet(),
        1,
        boost: (a) {
          a.addSpinBoost(0.15);
          a.addSpinBoost(0.15);
        },
      );

      expect(spun, closeTo(0.12 + 0.2 * 0.95, 1e-7));
    });
  });

  group('attach', () {
    test('is safe to call more than once', () {
      final animator = animatorFor(makeSceneBuilder(), [testPlanet()]);

      expect(() {
        animator.attach();
        animator.attach();
      }, returnsNormally);
    });
  });
}
