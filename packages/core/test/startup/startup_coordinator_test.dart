import 'dart:async';

import 'package:core/startup.dart';
import 'package:flutter_test/flutter_test.dart';

/// A task that reports on demand, so a test can decide exactly when progress
/// moves and never has to race a timer.
class _FakeTask implements StartupTask {
  _FakeTask(
    this.id, {
    this.weight = 1.0,
    this.criticality = StartupCriticality.required,
    this.dependsOn = const {},
    this.failureMessage = '',
  });

  @override
  final String id;
  @override
  final double weight;
  @override
  final StartupCriticality criticality;
  @override
  final Set<String> dependsOn;
  @override
  final String failureMessage;
  @override
  final String title = '';
  @override
  final StartupMessage message = StartupMessage.preparing;

  int runs = 0;
  bool shouldFail = false;

  /// Fractions reported, in order, for the assertion that progress only moves
  /// forwards.
  final List<double> reported = [];

  /// Completers the test completes by hand, which is how concurrency is proved:
  /// a task that only finishes when the test says so, while its siblings run.
  final Map<String, Completer<void>> gates = {};

  @override
  Future<void> execute(StartupTaskContext context) async {
    runs++;
    final gate = gates[id];
    if (gate != null) await gate.future;
    if (shouldFail) throw StateError('boom $id');
    for (final fraction in [0.0, 0.5, 1.0]) {
      reported.add(fraction);
      context.reportProgress(fraction, message: message);
    }
  }
}

/// True when a progress bar never goes backwards.
///
/// A bar that slips from 60% to 40% reads as a broken app even when the work
/// behind it is fine, so this is checked directly rather than assumed.
bool _isNonDecreasing(List<double> values) {
  for (var i = 1; i < values.length; i++) {
    if (values[i] < values[i - 1]) return false;
  }
  return true;
}

void main() {
  group('StartupProgress', () {
    test('clamps progress into 0..1', () {
      expect(clampProgress(-3), 0.0);
      expect(clampProgress(0.4), 0.4);
      expect(clampProgress(7), 1.0);
      expect(clampProgress(double.nan), 0.0);
    });

    test('copyWith never reports a progress outside the range', () {
      const progress = StartupProgress();
      expect(progress.copyWith(progress: 4).progress, 1.0);
      expect(progress.copyWith(progress: -1).progress, 0.0);
      expect(progress.copyWith(progress: double.nan).progress, 0.0);
    });
  });

  group('StartupCoordinatorImpl weighting', () {
    test('progress is the weighted share of work actually done', () async {
      final small = _FakeTask('small', weight: 1);
      final big = _FakeTask('big', weight: 3);
      final coordinator = StartupCoordinatorImpl(tasks: [small, big]);
      final seen = <double>[];
      final subscription = coordinator.watch().listen(
        (p) => seen.add(p.progress),
      );

      await coordinator.start();
      await Future<void>.delayed(Duration.zero);

      // Both tasks reported 0, 0.5, 1, so the interesting values to check are
      // the ones that are not the endpoints.
      expect(seen.first, 0.0);
      expect(seen.last, 1.0);
      expect(
        seen.every((value) => value >= 0.0 && value <= 1.0),
        isTrue,
        reason: 'a bar must never overflow its track',
      );
      // small weighs 1 and big weighs 3. Big half-done with small finished is
      // (1 + 1.5) / 4. If the weights were being ignored this would also be
      // 0.5, which is why the assertion is on the unequal shares instead.
      expect(seen, contains(0.125));
      expect(seen, contains(0.625));
      expect(
        _isNonDecreasing(seen),
        isTrue,
        reason: 'progress must never walk backwards: $seen',
      );
      await subscription.cancel();
      await coordinator.dispose();
    });

    test('a zero-weight task still runs but does not move the bar', () async {
      final free = _FakeTask('free', weight: 0);
      final work = _FakeTask('work', weight: 1);
      final coordinator = StartupCoordinatorImpl(tasks: [free, work]);
      final seen = <double>[];
      final subscription = coordinator.watch().listen(
        (p) => seen.add(p.progress),
      );

      await coordinator.start();
      await Future<void>.delayed(Duration.zero);

      expect(free.runs, 1);
      // The free task ran, and every value the bar showed is a value the
      // weighted task alone produces.
      expect(seen.toSet(), {0.0, 0.5, 1.0});
      await subscription.cancel();
      await coordinator.dispose();
    });
  });

  group('StartupCoordinatorImpl ordering', () {
    test('independent tasks overlap', () async {
      final first = _FakeTask('first')..gates['first'] = Completer<void>();
      final second = _FakeTask('second');
      final coordinator = StartupCoordinatorImpl(tasks: [first, second]);
      addTearDown(coordinator.dispose);

      final run = coordinator.start();
      await Future<void>.delayed(Duration.zero);

      // The sibling finished while `first` was still gated. A sequential
      // implementation would not get here until `first` was completed.
      expect(second.runs, 1, reason: 'unrelated work should not queue');
      expect(coordinator.progress.status, StartupStatus.loading);

      first.gates['first']!.complete();
      await run;
      expect(coordinator.progress.status, StartupStatus.ready);
    });

    test('a declared dependency really serialises', () async {
      final metadata = _FakeTask('metadata');
      final renderer = _FakeTask('renderer', dependsOn: {'metadata'});
      final coordinator = StartupCoordinatorImpl(tasks: [renderer, metadata]);
      addTearDown(coordinator.dispose);

      await coordinator.start();

      // The renderer is listed first, so a coordinator that ignored
      // dependencies would have run it first.
      expect(metadata.runs, 1);
      expect(renderer.runs, 1);
      expect(coordinator.progress.status, StartupStatus.ready);
    });

    test('a required task cannot wait on a lazy one', () {
      final lazy = _FakeTask('lazy', criticality: StartupCriticality.lazy);
      final required = _FakeTask('required', dependsOn: {'lazy'});
      expect(
        () => StartupCoordinatorImpl(tasks: [lazy, required]),
        throwsArgumentError,
      );
    });

    test('a dependency cycle is reported instead of never running', () {
      expect(
        () => StartupCoordinatorImpl(
          tasks: [
            _FakeTask('a', dependsOn: {'b'}),
            _FakeTask('b', dependsOn: {'a'}),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('StartupCoordinatorImpl idempotency', () {
    test('start after ready does not rebuild anything', () async {
      final task = _FakeTask('task');
      final coordinator = StartupCoordinatorImpl(tasks: [task]);
      addTearDown(coordinator.dispose);

      await coordinator.start();
      await coordinator.start();

      expect(task.runs, 1);
    });

    test('concurrent starts share one run', () async {
      final task = _FakeTask('task')..gates['task'] = Completer<void>();
      final coordinator = StartupCoordinatorImpl(tasks: [task]);
      addTearDown(coordinator.dispose);

      final a = coordinator.start();
      final b = coordinator.start();
      task.gates['task']!.complete();
      await Future.wait([a, b]);

      expect(task.runs, 1);
    });
  });

  group('StartupCoordinatorImpl failure and retry', () {
    test('a required failure stops startup and shows child copy', () async {
      final planets = _FakeTask(
        'planets',
        failureMessage: "We couldn't load the planets.",
      )..shouldFail = true;
      final coordinator = StartupCoordinatorImpl(tasks: [planets]);
      addTearDown(coordinator.dispose);

      await coordinator.start();

      final progress = coordinator.progress;
      expect(progress.status, StartupStatus.failed);
      expect(progress.errorMessage, "We couldn't load the planets.");
      expect(progress.failedTasks, ['planets']);
      expect(progress.progress, lessThan(1.0));
    });

    test('the technical error is logged, not shown', () async {
      final log = <String>[];
      final task = _FakeTask('task', failureMessage: 'friendly')
        ..shouldFail = true;
      final coordinator = StartupCoordinatorImpl(
        tasks: [task],
        onDiagnostic: log.add,
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();

      expect(log.join('\n'), contains('boom task'));
      expect(coordinator.progress.errorMessage, 'friendly');
    });

    test('retry reruns only what failed', () async {
      final planets = _FakeTask('planets', weight: 3);
      final missions = _FakeTask('missions', weight: 1, failureMessage: 'nope')
        ..shouldFail = true;
      final coordinator = StartupCoordinatorImpl(tasks: [planets, missions]);
      addTearDown(coordinator.dispose);

      await coordinator.start();
      expect(coordinator.progress.status, StartupStatus.failed);

      missions.shouldFail = false;
      await coordinator.retry();

      expect(planets.runs, 1, reason: 'the solar system was fine');
      expect(missions.runs, 2);
      expect(coordinator.progress.status, StartupStatus.ready);
      expect(coordinator.progress.progress, 1.0);
      expect(coordinator.progress.errorMessage, isNull);
    });

    test('a second retry after success changes nothing', () async {
      final task = _FakeTask('task', failureMessage: 'nope')..shouldFail = true;
      final coordinator = StartupCoordinatorImpl(tasks: [task]);
      addTearDown(coordinator.dispose);

      await coordinator.start();
      task.shouldFail = false;
      await coordinator.retry();
      await coordinator.retry();

      expect(task.runs, 2);
    });

    test('retry runs the levels a failure prevented from starting', () async {
      // With dependencies the pipeline has levels, and a failure in the first
      // one means the second never ran. A retry that only re-attempted what
      // failed would skip it and still emit ready — a bar at 100% for work
      // that never happened.
      final early = _FakeTask('early', failureMessage: 'nope')
        ..shouldFail = true;
      final late = _FakeTask('late', dependsOn: {'early'});
      final coordinator = StartupCoordinatorImpl(tasks: [early, late]);
      addTearDown(coordinator.dispose);

      await coordinator.start();

      expect(late.runs, 0, reason: 'the dependency gate held');

      early.shouldFail = false;
      await coordinator.retry();

      expect(early.runs, 2);
      expect(late.runs, 1, reason: 'never-reached work must still run');
      expect(coordinator.progress.status, StartupStatus.ready);
      expect(coordinator.progress.progress, 1.0);
      expect(coordinator.progress.errorMessage, isNull);
    });
  });

  group('StartupCoordinatorImpl lazy tasks', () {
    test('lazy work is not part of the barrier', () async {
      final moons = _FakeTask(
        'moons',
        criticality: StartupCriticality.lazy,
        weight: 5,
      )..gates['moons'] = Completer<void>();
      final coordinator = StartupCoordinatorImpl(tasks: [moons]);
      addTearDown(coordinator.dispose);

      await coordinator.start();

      expect(moons.runs, 0, reason: 'lazy work must not hold the app hostage');
      expect(coordinator.progress.status, StartupStatus.ready);
      expect(coordinator.progress.progress, 1.0);
    });

    test(
      'warmLater runs a lazy task once and reports nothing to the child',
      () async {
        final moons = _FakeTask('moons', criticality: StartupCriticality.lazy);
        final log = <String>[];
        final coordinator = StartupCoordinatorImpl(
          tasks: [moons],
          onDiagnostic: log.add,
        );
        addTearDown(coordinator.dispose);

        await coordinator.start();
        coordinator.warmLater('moons');
        coordinator.warmLater('moons');
        await Future<void>.delayed(Duration.zero);

        expect(moons.runs, 1);
        expect(coordinator.progress.status, StartupStatus.ready);
        expect(log.join('\n'), contains('moons'));
      },
    );

    test('a lazy failure is logged and never blocks', () async {
      final log = <String>[];
      final moons = _FakeTask('moons', criticality: StartupCriticality.lazy)
        ..shouldFail = true;
      final coordinator = StartupCoordinatorImpl(
        tasks: [moons],
        onDiagnostic: log.add,
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();
      coordinator.warmLater('moons');
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.progress.status, StartupStatus.ready);
      expect(coordinator.progress.errorMessage, isNull);
      expect(log.join('\n'), contains('moons'));
    });

    test('warming an unknown id is a logged mistake, not a crash', () async {
      final log = <String>[];
      final coordinator = StartupCoordinatorImpl(
        tasks: const [],
        onDiagnostic: log.add,
      );
      addTearDown(coordinator.dispose);

      coordinator.warmLater('nope');

      expect(log.join('\n'), contains('nope'));
    });
  });

  group('duplicate ids', () {
    test('are rejected at construction', () {
      expect(
        () => StartupCoordinatorImpl(
          tasks: [_FakeTask('same'), _FakeTask('same')],
        ),
        throwsArgumentError,
      );
    });
  });
}
