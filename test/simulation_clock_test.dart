import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/simulation_clock.dart';

void main() {
  late SimulationClock clock;

  setUp(() => clock = SimulationClock());
  // A tear-off would read the late variable while main is still running.
  tearDown(() => clock.dispose());

  group('speed', () {
    test('defaults to one', () {
      expect(clock.speed, 1.0);
      expect(clock.running, isTrue);
      expect(clock.elapsedSeconds, 0.0);
    });

    test('accepts a value inside the range', () {
      clock.setSpeed(2.5);
      expect(clock.speed, 2.5);
    });

    test('clamps above the maximum', () {
      clock.setSpeed(100);
      expect(clock.speed, 8.0);
    });

    test('clamps below zero', () {
      clock.setSpeed(-4);
      expect(clock.speed, 0.0);
    });

    test('a speed of zero freezes the simulation', () {
      clock.setSpeed(0);
      clock.tick(5);

      expect(clock.elapsedSeconds, 0.0);
    });
  });

  group('tick', () {
    test('advances by the scaled delta', () {
      clock.setSpeed(2);
      clock.tick(1);

      expect(clock.elapsedSeconds, 2.0);
    });

    test('accumulates across frames', () {
      clock.tick(0.5);
      clock.tick(0.25);
      clock.tick(0.25);

      expect(clock.elapsedSeconds, 1.0);
    });

    test('is ignored while paused', () {
      clock.pause();
      clock.tick(5);

      expect(clock.elapsedSeconds, 0.0);
      expect(clock.running, isFalse);
    });

    test('resumes from where it stopped', () {
      clock.tick(1);
      clock.pause();
      clock.tick(5);
      clock.resume();
      clock.tick(1);

      expect(clock.running, isTrue);
      expect(clock.elapsedSeconds, 2.0);
    });

    test('a zero delta still emits', () async {
      final seen = <double>[];
      clock.ticks.listen(seen.add);

      clock.tick(0);
      await pumpEventQueue();

      expect(clock.elapsedSeconds, 0.0);
      expect(seen, [0.0]);
    });
  });

  group('ticks stream', () {
    test('emits the running total on every frame', () async {
      final seen = <double>[];
      clock.ticks.listen(seen.add);

      clock.tick(0.5);
      clock.tick(0.5);
      await pumpEventQueue();

      expect(seen, [0.5, 1.0]);
    });

    test('emits the scaled total, not the raw delta', () async {
      clock.setSpeed(3);
      final seen = <double>[];
      clock.ticks.listen(seen.add);

      clock.tick(1);
      await pumpEventQueue();

      expect(seen, [3.0]);
    });

    test('stays silent while paused', () {
      final seen = <double>[];
      clock.ticks.listen(seen.add);

      clock.pause();
      clock.tick(5);

      expect(seen, isEmpty);
    });

    test('is a broadcast stream, so every listener sees every tick', () async {
      final a = <double>[];
      final b = <double>[];
      clock.ticks.listen(a.add);
      clock.ticks.listen(b.add);

      clock.tick(1);
      clock.tick(1);
      await pumpEventQueue();

      expect(a, [1.0, 2.0]);
      expect(b, [1.0, 2.0]);
    });

    test('a late listener only sees subsequent ticks', () async {
      clock.tick(1);

      final seen = <double>[];
      clock.ticks.listen(seen.add);
      clock.tick(1);
      await pumpEventQueue();

      expect(seen, [2.0]);
    });
  });

  group('dispose', () {
    test('closes the stream', () async {
      var done = false;
      clock.ticks.listen(null, onDone: () => done = true);

      clock.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });

    test('a tick after dispose does not throw on the closed stream', () {
      clock.dispose();

      // The isClosed guard only protects the emit; the clock itself keeps
      // counting, because nothing reads it after teardown.
      expect(() => clock.tick(1), returnsNormally);
    });

    test('a disposed clock can still be read', () {
      clock.tick(2);
      clock.dispose();

      expect(clock.elapsedSeconds, 2.0);
      expect(clock.speed, 1.0);
      expect(clock.running, isTrue);
    });
  });
}
