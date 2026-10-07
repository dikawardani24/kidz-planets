import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/startup.dart';

import 'solar_system_startup_tasks.dart';
import 'startup_hooks.dart';

export 'package:core/startup.dart' show StartupProgress, StartupStatus;

export 'intro_copy.dart';
export 'solar_system_startup_tasks.dart' hide SolarSystemStartupHooks;
export 'startup_hooks.dart';

/// The coordinator, owned as process-wide state.
///
/// A state notifier rather than a bare provider so the widget tree can watch
/// [StartupProgress] reactively.
final startupCoordinatorProvider =
    StateNotifierProvider<StartupCoordinatorNotifier, StartupProgress>((ref) {
      final notifier = StartupCoordinatorNotifier(
        tasks: buildSolarSystemStartupTasks(
          hooks: RealSolarSystemStartupHooks(startupRef: ref),
        ),
      );
      ref.onDispose(notifier.disposeCoordinator);
      return notifier;
    });

/// Drives the [StartupCoordinatorImpl] and publishes each emission.
class StartupCoordinatorNotifier extends StateNotifier<StartupProgress> {
  StartupCoordinatorNotifier({
    required List<StartupTask> tasks,
    StartupCoordinator Function(List<StartupTask> tasks)? coordinatorFactory,
  }) : _coordinator = coordinatorFactory != null
           ? coordinatorFactory(tasks)
           : StartupCoordinatorImpl(tasks: tasks),
       super(const StartupProgress()) {
    _subscription = _coordinator.watch().listen((progress) {
      state = progress;
    });
  }

  final StartupCoordinator _coordinator;
  late final StreamSubscription<StartupProgress> _subscription;

  /// Runs every required task; safe to call twice (the coordinator collapses
  /// concurrent runs, and the gate also guards with its own flag).
  Future<void> start() => _coordinator.start();

  /// Re-runs only the tasks that failed; wired to the error screen's button.
  Future<void> retry() => _coordinator.retry();

  /// Best-effort warm of a lazy startup task (e.g. moons after first frame).
  void warmLater(String taskId) => _coordinator.warmLater(taskId);

  /// Releases the progress subscription and the coordinator's stream.
  ///
  /// Called from the provider's `onDispose`, which is the composition root
  /// going away — never during a normal run, where the coordinator outlives
  /// every screen.
  Future<void> disposeCoordinator() async {
    await _subscription.cancel();
    final coordinator = _coordinator;
    if (coordinator is StartupCoordinatorImpl) {
      await coordinator.dispose();
    }
  }
}
