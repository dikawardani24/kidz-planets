import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/l10n.dart';
import 'package:core/startup.dart';

import 'package:kidz_planets/application/startup/startup_providers.dart';
import 'package:kidz_planets/presentation/screens/intro/intro_copy_resolver.dart';
import 'package:kidz_planets/presentation/screens/intro/widgets/intro_planets.dart';

import 'fake_startup_hooks.dart';

/// The startup wiring, checked where it lives: the task table, the copy that
/// describes it, and the coordinator behaviour the intro's progress bar is
/// built on. Nothing here touches a GPU or a platform channel — the hooks
/// seam exists so this file can run the real pipeline.
void main() {
  List<StartupTask> tasksWith(FakeStartupHooks hooks) =>
      buildSolarSystemStartupTasks(hooks: hooks);

  StartupCoordinatorImpl coordinatorWith(FakeStartupHooks hooks) =>
      StartupCoordinatorImpl(tasks: tasksWith(hooks));

  group('task table', () {
    test('has the six expected tasks; moons are lazy', () {
      final tasks = buildSolarSystemStartupTasks();

      expect(tasks.map((t) => t.id), [
        SolarSystemStartupTaskId.core,
        SolarSystemStartupTaskId.solarSystem,
        SolarSystemStartupTaskId.missions,
        SolarSystemStartupTaskId.companion,
        SolarSystemStartupTaskId.sounds,
        SolarSystemStartupTaskId.moons,
      ]);
      final byId = {for (final task in tasks) task.id: task};
      // Required tasks gate the Intro CTA; moons warm after Explorer presents.
      expect(byId[SolarSystemStartupTaskId.moons]!.criticality,
          StartupCriticality.lazy);
      for (final id in [
        SolarSystemStartupTaskId.core,
        SolarSystemStartupTaskId.solarSystem,
        SolarSystemStartupTaskId.missions,
        SolarSystemStartupTaskId.companion,
        SolarSystemStartupTaskId.sounds,
      ]) {
        expect(
          byId[id]!.criticality,
          StartupCriticality.required,
          reason: id,
        );
      }
    });

    test('required weights sum to the declared total', () {
      final sum = buildSolarSystemStartupTasks()
          .where((t) => t.criticality == StartupCriticality.required)
          .fold<double>(0, (total, task) => total + task.weight);
      expect(sum, SolarSystemStartupWeights.total);
    });

    test('scene waits for session; moons wait for scene; sounds wait for session',
        () {
      final byId = {
        for (final task in buildSolarSystemStartupTasks()) task.id: task,
      };
      expect(byId[SolarSystemStartupTaskId.moons]!.dependsOn, {
        SolarSystemStartupTaskId.solarSystem,
      });
      expect(byId[SolarSystemStartupTaskId.sounds]!.dependsOn, {
        SolarSystemStartupTaskId.core,
      });
      expect(byId[SolarSystemStartupTaskId.solarSystem]!.dependsOn, {
        SolarSystemStartupTaskId.core,
      });
      // The remaining required tasks stay independent so they can overlap.
      for (final id in [
        SolarSystemStartupTaskId.core,
        SolarSystemStartupTaskId.missions,
        SolarSystemStartupTaskId.companion,
      ]) {
        expect(byId[id]!.dependsOn, isEmpty, reason: id);
      }
    });

    test('each task announces a distinct phase', () {
      // Two tasks sharing a phase line is the "Loading… Loading…" screen the
      // core contract warns about, and `ready` belongs to completion alone —
      // a task claiming it would show the child the finished state early.
      final messages = buildSolarSystemStartupTasks()
          .map((task) => task.message)
          .toList();

      expect(messages.toSet(), hasLength(messages.length));
      expect(messages, isNot(contains(StartupMessage.ready)));
    });
  });

  group('pipeline', () {
    test('runs every required task once and ends ready at 100%', () async {
      final hooks = FakeStartupHooks();
      final coordinator = coordinatorWith(hooks);
      addTearDown(coordinator.dispose);

      await coordinator.start();
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.progress.status, StartupStatus.ready);
      expect(coordinator.progress.progress, 1.0);
      expect(coordinator.progress.errorMessage, isNull);
      expect(hooks.calls.toSet(), {
        SolarSystemStartupTaskId.core,
        SolarSystemStartupTaskId.solarSystem,
        SolarSystemStartupTaskId.missions,
        SolarSystemStartupTaskId.companion,
        SolarSystemStartupTaskId.sounds,
      });
      // Moons are lazy: not part of the CTA barrier.
      expect(hooks.calls, isNot(contains(SolarSystemStartupTaskId.moons)));

      coordinator.warmLater(SolarSystemStartupTaskId.moons);
      await Future<void>.delayed(Duration.zero);
      expect(hooks.calls, contains(SolarSystemStartupTaskId.moons));
      expect(
        hooks.calls.indexOf(SolarSystemStartupTaskId.solarSystem),
        lessThan(hooks.calls.indexOf(SolarSystemStartupTaskId.moons)),
      );
    });

    test('progress never reaches 1.0 while one task is unfinished', () async {
      final hooks = FakeStartupHooks()
        ..gateOn(SolarSystemStartupTaskId.solarSystem);
      final coordinator = coordinatorWith(hooks);
      addTearDown(coordinator.dispose);

      unawaited(coordinator.start());
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.progress.status, StartupStatus.loading);
      expect(coordinator.progress.progress, lessThan(1.0));
      expect(coordinator.progress.isReady, isFalse);

      hooks.openGate(SolarSystemStartupTaskId.solarSystem);
      await coordinator.start();
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.progress.status, StartupStatus.ready);
      expect(coordinator.progress.progress, 1.0);
    });

    test('a failed task surfaces child copy and a retry recovers', () async {
      final hooks = FakeStartupHooks()
        ..failing.add(SolarSystemStartupTaskId.solarSystem);
      final coordinator = coordinatorWith(hooks);
      addTearDown(coordinator.dispose);

      await coordinator.start();
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.progress.status, StartupStatus.failed);
      // The task's child sentence, never the thrown exception.
      expect(
        coordinator.progress.errorMessage,
        'We could not load the planets.',
      );
      expect(coordinator.progress.failedTasks, [
        SolarSystemStartupTaskId.solarSystem,
      ]);

      hooks.failing.clear();
      await coordinator.retry();
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.progress.status, StartupStatus.ready);
      expect(coordinator.progress.progress, 1.0);
      expect(coordinator.progress.errorMessage, isNull);
      // Retry re-ran the failure only: everything else stayed succeeded.
      expect(
        hooks.calls.where((id) => id == SolarSystemStartupTaskId.solarSystem),
        hasLength(2),
      );
      expect(
        hooks.calls.where((id) => id == SolarSystemStartupTaskId.core),
        hasLength(1),
      );
    });
  });

  group('notifier bridge', () {
    test('publishes coordinator emissions as Riverpod state', () async {
      final hooks = FakeStartupHooks();
      final notifier = StartupCoordinatorNotifier(tasks: tasksWith(hooks));
      addTearDown(notifier.disposeCoordinator);

      expect(notifier.state.status, StartupStatus.idle);

      await notifier.start();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, StartupStatus.ready);
      expect(notifier.state.progress, 1.0);
    });
  });

  group('milestone schedule', () {
    test('reveals Earth, Moon and Saturn at the prototype beats', () {
      expect(milestonesForProgress(0), isEmpty);
      expect(milestonesForProgress(0.24), isEmpty);
      expect(milestonesForProgress(0.25), {IntroMilestone.earth});
      expect(milestonesForProgress(0.5), {
        IntroMilestone.earth,
        IntroMilestone.moon,
      });
      expect(milestonesForProgress(0.7), {
        IntroMilestone.earth,
        IntroMilestone.moon,
        IntroMilestone.saturn,
      });
      expect(milestonesForProgress(1.0), IntroMilestone.values.toSet());
    });

    test('reveal thresholds are ordered and inside the bar', () {
      expect(IntroPlanets.earthAt, lessThan(IntroPlanets.moonAt));
      expect(IntroPlanets.moonAt, lessThan(IntroPlanets.saturnAt));
      expect(IntroPlanets.saturnAt, lessThan(1.0));
    });
  });

  group('intro copy', () {
    test('has the rotating space facts from the prototype', () {
      expect(IntroCopy.spaceFacts, hasLength(6));
      expect(
        IntroCopy.spaceFacts.first,
        contains('Jupiter is the biggest planet'),
      );
    });

    test('every message resolves phase, message and subtitle copy', () async {
      // The three resolvers are exhaustive switch expressions — a new
      // StartupMessage fails this at compile time — and this proves they
      // produce non-empty strings for every case in the shipped locale.
      final t = await AppLocalizations.delegate.load(const Locale('en'));
      for (final message in StartupMessage.values) {
        expect(introPhaseFor(message, t), isNotEmpty, reason: '$message');
        expect(introMessageFor(message, t), isNotEmpty, reason: '$message');
        expect(introSubtitleFor(message, t), isNotEmpty, reason: '$message');
      }
    });
  });
}
