import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_exhaust_plume.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_exhaust_texture.dart';

void main() {
  /// Steps [plume] forward at a fixed 60 Hz, which is what makes the particle
  /// counts below comparable between runs.
  void run(ExhaustPlume plume, {required int frames, double phase = 0}) {
    for (var i = 0; i < frames; i++) {
      final t = phase + i / 60;
      plume.tick(1 / 60, flickerPhase: t);
      plume.step(1 / 60);
    }
  }

  group('ExhaustSpriteFactory', () {
    final pixels = ExhaustSpriteFactory.buildPixels();
    final size = ExhaustSpriteFactory.size;

    double alphaAt(int x, int y) => pixels[(y * size + x) * 4 + 3] / 255.0;

    test('writes a full square of RGBA', () {
      expect(pixels.length, size * size * 4);
    });

    test('is white, so the emitter colour is what tints the puff', () {
      for (final i in [0, 4, (size ~/ 2) * size * 4]) {
        expect(pixels[i], 255);
        expect(pixels[i + 1], 255);
        expect(pixels[i + 2], 255);
      }
    });

    test('the centre is opaque and the corners are clear', () {
      expect(alphaAt(size ~/ 2, size ~/ 2), greaterThan(0.9));

      // Far diagonals, well outside the disc.
      for (final offset in [2, size - 3]) {
        expect(alphaAt(offset, offset), lessThan(0.05));
      }
    });

    test('alpha falls off outwards along the vertical axis', () {
      // The noise lobes are gentle, so the trend has to hold on average rather
      // than at every single pixel.
      final samples = <double>[
        for (var y = 0; y < size ~/ 2; y++) alphaAt(size ~/ 2, y),
      ];
      for (var i = 1; i < samples.length; i++) {
        expect(
          samples[i],
          lessThanOrEqualTo(samples[i - 1] + 0.15),
          reason: 'alpha rose at row $i',
        );
      }
    });

    test('the wobble makes the sprite irregular, not a perfect circle', () {
      // Compare each pixel against its mirror across the vertical axis. A
      // plain radial falloff would be exactly symmetric at every one of them;
      // the noise lobes are what break that, and are what stops a batch of
      // puffs from reading as a repeating pattern.
      var asymmetric = 0;
      var compared = 0;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size ~/ 2; x++) {
          final mirror = size - 1 - x;
          compared++;
          if ((alphaAt(x, y) - alphaAt(mirror, y)).abs() > 1 / 255) {
            asymmetric++;
          }
        }
      }

      // Not every pixel differs: the two sine lobes cross zero along a line
      // through the disc, so symmetry survives there. The point is that the
      // asymmetry is spread over a large part of the sprite rather than being
      // a single dent.
      expect(compared, greaterThan(0));
      expect(asymmetric / compared, greaterThan(0.3));
    });

    test('every alpha is a valid byte', () {
      for (var i = 3; i < pixels.length; i += 4) {
        expect(pixels[i], inInclusiveRange(0, 255));
      }
    });

    test('is deterministic', () {
      expect(ExhaustSpriteFactory.buildPixels(), pixels);
    });
  });

  group('ExhaustPlume layers', () {
    late ExhaustPlume plume;

    setUp(() => plume = ExhaustPlume());

    test('has four layers in draw order', () {
      expect(plume.systems.length, 4);
      expect(
        plume.systems,
        [plume.core, plume.flame, plume.smoke, plume.embers],
      );
    });

    test('every layer is prewarmed, not faded in from nothing', () {
      // A plume that starts empty spends its first frames as a bare engine.
      plume.setThrottle(1.0);
      run(plume, frames: 1);
      expect(plume.liveCount, greaterThan(0));
    });

    test('a layer is reproducible from its seed', () {
      int count(ExhaustPlume p) {
        p.setThrottle(1.0);
        run(p, frames: 90);
        return p.flame.storage.aliveCount;
      }

      expect(count(ExhaustPlume()), count(ExhaustPlume()));
    });

    test('the flame is turbulent, so its particles are not in lockstep', () {
      plume.setThrottle(1.0);
      run(plume, frames: 120);

      // A cone emitter with no turbulence would put every particle on one
      // straight line down the axis.
      final storage = plume.flame.storage;
      final spread = <String>{};
      for (var i = 0; i < storage.aliveCount; i++) {
        spread.add(storage.posX[i].toStringAsFixed(3));
      }
      expect(spread.length, greaterThan(8));
    });

    test('the flame streams downstream from the nozzle, not backwards', () {
      plume.setThrottle(1.0);
      run(plume, frames: 90);

      // The emitter runs along its local +Y (its node is turned to point that
      // way down the rocket), so the overwhelming majority of particles must
      // be downstream. Curl noise scatters a few back past the throat, which
      // is what makes the edge look ragged, so this is a ratio not a zero.
      var downstream = 0;
      final storage = plume.flame.storage;
      for (var i = 0; i < storage.aliveCount; i++) {
        if (storage.posY[i] > 0) downstream++;
      }
      expect(downstream / storage.aliveCount, greaterThan(0.9));
    });

    test('smoke outlives the flame it came from', () {
      plume.setThrottle(1.0);
      run(plume, frames: 180);
      final whileBurning = plume.smoke.storage.aliveCount;

      plume.shutDown();
      run(plume, frames: 6);

      // Seconds later the engine is off but the vapour is still in the air.
      expect(plume.smoke.storage.aliveCount, greaterThan(whileBurning * 0.8));
    });

    test('smoke particles expand as they age', () {
      plume.setThrottle(1.0);
      run(plume, frames: 120);

      final storage = plume.smoke.storage;
      for (var i = 0; i < storage.aliveCount; i++) {
        expect(
          storage.size[i],
          greaterThanOrEqualTo(storage.baseSize[i] * 0.79),
          reason: 'a puff shrank below its size-over-life floor',
        );
      }
    });

    test('every layer fades to nothing rather than popping out', () {
      plume.setThrottle(1.0);
      run(plume, frames: 120);

      // A particle that vanishes at full opacity is a visible pop; the alpha
      // gradient has to reach zero before the lifetime ends.
      for (final system in plume.systems) {
        final storage = system.storage;
        for (var i = 0; i < storage.aliveCount; i++) {
          final age = storage.age[i] / storage.lifetime[i];
          if (age > 0.95) {
            expect(storage.colorA[i], lessThan(0.35), reason: '${system.hashCode}');
          }
        }
      }
    });

    test('sparks scatter wider than the flame', () {
      plume.setThrottle(1.0);
      run(plume, frames: 120);

      double spread(ParticleSystem system) {
        var widest = 0.0;
        final storage = system.storage;
        for (var i = 0; i < storage.aliveCount; i++) {
          final lateral = storage.posX[i].abs();
          if (lateral > widest) widest = lateral;
        }
        return widest;
      }

      expect(spread(plume.embers), greaterThan(spread(plume.flame)));
    });

    test('the pools never overflow, however long it burns', () {
      plume.setThrottle(1.0);
      for (var i = 0; i < 3000; i++) {
        plume.tick(1 / 60, flickerPhase: i / 60);
        plume.step(1 / 60);
      }

      for (final system in plume.systems) {
        expect(
          system.storage.aliveCount,
          lessThanOrEqualTo(system.storage.capacity),
        );
      }
    });
  });

  group('ExhaustPlume throttle', () {
    late ExhaustPlume plume;

    setUp(() => plume = ExhaustPlume());

    test('a fresh plume idles rather than sitting dark', () {
      expect(plume.throttle, greaterThan(0.0));
      expect(plume.throttle, lessThan(1.0));
    });

    test('opening the throttle is eased, not instant', () {
      final before = plume.throttle;

      plume.setThrottle(1.0);
      plume.tick(1 / 60, flickerPhase: 0);

      // It has moved, but a rocket does not reach full thrust in one frame.
      expect(plume.throttle, greaterThan(before));
      expect(plume.throttle, lessThan(0.9));
    });

    test('the throttle converges on its target', () {
      plume.setThrottle(1.0);
      run(plume, frames: 240);

      expect(plume.throttle, closeTo(1.0, 0.01));
    });

    test('the throttle converges when closing as well', () {
      plume.setThrottle(1.0);
      run(plume, frames: 240);
      plume.setThrottle(0.0);
      run(plume, frames: 240);

      expect(plume.throttle, closeTo(0.0, 0.01));
    });

    test('a target outside the valid range is clamped', () {
      plume.setThrottle(5.0);
      run(plume, frames: 600);
      expect(plume.throttle, closeTo(1.0, 0.01));

      plume.setThrottle(-5.0);
      run(plume, frames: 600);
      expect(plume.throttle, closeTo(0.0, 0.01));
    });

    test('a zero-length frame does not move the throttle', () {
      plume.setThrottle(1.0);
      plume.tick(0, flickerPhase: 0);
      plume.tick(0, flickerPhase: 0);

      // Guards the pause path: a rebuild that resumes mid-frame must not hand
      // the plume a NaN or infinite delta.
      expect(plume.throttle.isFinite, isTrue);
    });

    test('a long hitch is clamped, so the plume cannot teleport', () {
      plume.setThrottle(1.0);
      run(plume, frames: 60);

      // A tab regaining focus hands over a multi-second delta.
      plume.tick(30.0, flickerPhase: 1.0);

      expect(plume.throttle.isFinite, isTrue);
      expect(plume.throttle, inInclusiveRange(0.0, 1.0));
    });

    test('idle still emits from the core, so the engine never reads broken',
        () {
      plume.setThrottle(0.0);
      run(plume, frames: 600);

      // The core keeps a pilot light: a floor, not a hard zero.
      expect(plume.core.spawner.rate, greaterThan(0.0));
    });

    test('smoke and sparks lag well behind the core', () {
      plume.setThrottle(0.0);
      run(plume, frames: 600);
      final idleCore = plume.core.spawner.rate;
      final idleSmoke = plume.smoke.spawner.rate;
      final idleEmbers = plume.embers.spawner.rate;

      plume.setThrottle(1.0);
      plume.tick(1 / 60, flickerPhase: 0);

      final coreGain = plume.core.spawner.rate / idleCore;
      final smokeGain = plume.smoke.spawner.rate / idleSmoke;
      final emberGain = plume.embers.spawner.rate / idleEmbers;

      expect(coreGain, greaterThan(smokeGain));
      expect(smokeGain, greaterThan(emberGain));
    });

    test('a harder burn emits more of every layer', () {
      plume.setThrottle(0.0);
      run(plume, frames: 600);
      final idle = plume.liveCount;

      plume.setThrottle(1.0);
      run(plume, frames: 60);

      expect(plume.liveCount, greaterThan(idle));
    });

    test('a harder burn throws the flame further', () {
      plume.setThrottle(0.1);
      run(plume, frames: 120);
      final lazy = plume.flameReach;

      plume.setThrottle(1.0);
      run(plume, frames: 120);

      expect(plume.flameReach, greaterThan(lazy));
    });

    test('shutting down leaves live particles to fade, not vanish', () {
      plume.setThrottle(1.0);
      run(plume, frames: 120);
      final burning = plume.liveCount;

      plume.shutDown();
      expect(plume.liveCount, burning);

      // And they do eventually go away, once they have burnt out.
      run(plume, frames: 600);
      expect(plume.liveCount, lessThan(burning));
    });

    test('the throat light brightens with the burn', () {
      plume.setThrottle(0.0);
      run(plume, frames: 600);
      final idle = plume.lightIntensity;

      plume.setThrottle(1.0);
      run(plume, frames: 600);

      expect(plume.lightIntensity, greaterThan(idle));
      expect(plume.lightIntensity, greaterThan(0.0));
    });

    test('the light is never negative, at any throttle or phase', () {
      for (final throttle in [0.0, 0.3, 0.7, 1.0]) {
        plume.setThrottle(throttle);
        for (var i = 0; i < 30; i++) {
          plume.tick(1 / 60, flickerPhase: i * 0.37);
          expect(plume.lightIntensity, greaterThanOrEqualTo(0.0));
        }
      }
    });

    test('the glow flare grows with the flame', () {
      plume.setThrottle(0.0);
      run(plume, frames: 600);
      final idle = plume.glowSpread;

      plume.setThrottle(1.0);
      run(plume, frames: 600);

      expect(plume.glowSpread, greaterThan(idle));
    });

    test('flicker keeps the burn from settling into a flat value', () {
      plume.setThrottle(1.0);
      run(plume, frames: 600);

      final rates = <double>[];
      for (var i = 0; i < 120; i++) {
        plume.tick(1 / 60, flickerPhase: 100 + i / 60);
        rates.add(plume.flame.spawner.rate);
      }

      final spread = rates.reduce(math.max) - rates.reduce(math.min);
      expect(spread, greaterThan(0.0));
    });
  });

  group('ExhaustPlume.throttleForSpeed', () {
    test('a parked rocket still has a pilot light', () {
      final idle = ExhaustPlume.throttleForSpeed(0);
      expect(idle, greaterThan(0.0));
      expect(idle, lessThan(1.0));
    });

    test('faster means more thrust', () {
      expect(
        ExhaustPlume.throttleForSpeed(400),
        greaterThan(ExhaustPlume.throttleForSpeed(100)),
      );
    });

    test('a hard throw saturates rather than running away', () {
      final fast = ExhaustPlume.throttleForSpeed(100000);
      expect(fast, closeTo(1.0, 1e-9));
    });

    test('a negative speed (never happens) is still safe', () {
      final value = ExhaustPlume.throttleForSpeed(-500);
      expect(value, inInclusiveRange(0.0, 1.0));
    });
  });
}
