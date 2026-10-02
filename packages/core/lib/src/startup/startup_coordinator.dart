import 'dart:async';
import 'dart:developer' as developer;

import 'startup_message.dart';
import 'startup_progress.dart';
import 'startup_status.dart';
import 'startup_task.dart';

/// Orchestrates the tasks that make the app explorable.
///
/// The coordinator is the only thing the loading screen talks to, and it knows
/// nothing about planets, moons, avatars or missions: it runs whatever
/// [StartupTask]s it is handed, in dependency order, and reports real progress.
/// A feature that wants to join startup adds a task and nothing else changes
/// here.
abstract interface class StartupCoordinator {
  /// The latest progress, for a widget that is not subscribed.
  StartupProgress get progress;

  /// Progress updates as they happen.
  ///
  /// A broadcast stream, so the gate, a test and a future telemetry sink can
  /// all listen without the coordinator tracking listeners.
  Stream<StartupProgress> watch();

  /// Runs every required task that has not succeeded yet.
  ///
  /// Idempotent by design: calling it twice, or calling it after a successful
  /// startup, returns immediately rather than rebuilding the solar system.
  /// Concurrent callers share one run.
  Future<void> start();

  /// Runs whatever is still unfinished, leaving finished work alone.
  ///
  /// This is what a child's "Try Again" press calls. Re-preparing eight
  /// megabytes of already-decoded planets because one catalogue failed would
  /// make a retry slower than the first attempt.
  Future<void> retry();

  /// Warms a lazy task after startup, without blocking anything.
  ///
  /// Best effort by definition: nothing is awaited, nothing is shown, and a
  /// failure is logged and remembered. This is how the moons get painted
  /// during the first moments of exploration instead of during the wait the
  /// child is already sitting through.
  void warmLater(String taskId);
}

/// The default [StartupCoordinator].
///
/// Tasks are grouped into dependency levels and each level runs together, so
/// unrelated work overlaps by default: the solar system, the companion and the
/// mission catalogue all decode and build at the same time, because none of
/// them needs another. Only dependencies that are actually written down
/// serialise, and those are ordered before the first task runs rather than
/// discovered by throwing at runtime.
class StartupCoordinatorImpl implements StartupCoordinator {
  StartupCoordinatorImpl({
    required List<StartupTask> tasks,
    void Function(String message)? onDiagnostic,
  }) : _onDiagnostic = onDiagnostic ?? _defaultDiagnostic {
    for (final task in tasks) {
      if (_tasks.containsKey(task.id)) {
        throw ArgumentError('Two startup tasks share the id "${task.id}"');
      }
      _tasks[task.id] = task;
    }
    _levels = _buildLevels();
  }

  /// Ids of lazy tasks, by feature, for [warmLater].
  ///
  /// Kept as a plain set because the coordinator's job is to run work, not to
  /// know which feature asked for it.
  final Map<String, StartupTask> _tasks = {};
  final void Function(String message) _onDiagnostic;

  late final List<List<StartupTask>> _levels;
  final StreamController<StartupProgress> _controller =
      StreamController<StartupProgress>.broadcast();

  /// Required tasks already finished, kept across retries.
  final Set<String> _succeeded = {};

  /// Tasks that failed and are worth another attempt.
  final Set<String> _retryable = {};

  final Map<String, double> _reported = {};

  /// Tasks currently running, so a duplicate request joins instead of racing.
  final Map<String, Future<_TaskFailure?>> _inFlight = {};

  StartupProgress _progress = const StartupProgress();
  Future<void>? _running;
  bool _disposed = false;

  @override
  StartupProgress get progress => _progress;

  @override
  Stream<StartupProgress> watch() => _controller.stream;

  static void _defaultDiagnostic(String message) =>
      developer.log(message, name: 'startup');

  @override
  Future<void> start() => _run(retryOnly: false);

  @override
  Future<void> retry() => _run(retryOnly: true);

  /// Runs the pipeline, collapsing concurrent callers onto one run.
  Future<void> _run({required bool retryOnly}) {
    if (_disposed) return Future<void>.value();
    final inFlight = _running;
    if (inFlight != null) return inFlight;
    if (_progress.isReady) return Future<void>.value();

    _reported.clear();
    _emit(
      _progress.copyWith(
        status: StartupStatus.loading,
        progress: 0.0,
        clearError: true,
        failedTasks: const [],
      ),
    );

    final run = _execute(retryOnly: retryOnly);
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  Future<void> _execute({required bool retryOnly}) async {
    for (final level in _levels) {
      final pending = level
          .where((task) => !_succeeded.contains(task.id))
          .toList(growable: false);
      if (pending.isEmpty) continue;

      // Retry runs only what failed. Without this a second press on "Try Again"
      // would re-run the four tasks that already worked.
      if (retryOnly && !_retryable.contains(pending.first.id)) continue;

      for (final task in pending) {
        _emit(
          _progress.copyWith(
            status: StartupStatus.loading,
            currentTask: task.id,
            message: task.message,
          ),
        );
      }

      // Every task in a level is independent by construction, so they overlap.
      // `wait` is used rather than `waitAny` because one level failing must not
      // silently orphan the others that are already running.
      final results = await Future.wait(
        pending.map((task) => _runTask(task)),
      );

      for (final result in results) {
        if (result == null) continue;
        // A required failure stops the pipeline. Continuing would build a solar
        // system without the mission catalogue and call it ready.
        _fail(result);
        return;
      }
    }

    _emit(
      _progress.copyWith(
        status: StartupStatus.ready,
        progress: 1.0,
        currentTask: null,
        message: StartupMessage.ready,
        clearError: true,
      ),
    );
  }

  /// Runs one task, converting a throw into a value.
  ///
  /// Returning a failure instead of rethrowing is what lets a level report a
  /// complete result set: the sibling tasks are never left in the dark about
  /// whether they ran.
  ///
  /// A task already in flight is joined rather than started again. That is the
  /// guard against a second audio player and a second scene graph: two warm-ups
  /// arriving together (a double "Try Again" press, a lazy warm racing a retry)
  /// produce one run and both callers see its result.
  Future<_TaskFailure?> _runTask(StartupTask task) {
    final inFlight = _inFlight[task.id];
    if (inFlight != null) return inFlight;
    // The removal is a block body on purpose. `Map.remove` returns the value it
    // removed, so passing it straight to `whenComplete` would return this very
    // future and make it wait on itself, forever.
    final run = _executeTask(task).whenComplete(() {
      _inFlight.remove(task.id);
    });
    _inFlight[task.id] = run;
    return run;
  }

  Future<_TaskFailure?> _executeTask(StartupTask task) async {
    _reported[task.id] = 0.0;
    try {
      await task.execute(
        CallbackStartupTaskContext((fraction, message) {
          _reported[task.id] = fraction;
          _emit(
            _progress.copyWith(
              message: message ?? _progress.message,
              progress: _fraction(),
            ),
          );
        }),
      );
      _reported[task.id] = 1.0;
      _succeeded.add(task.id);
      _retryable.remove(task.id);
      _emitProgressOnly();
      return null;
    } catch (error, stackTrace) {
      // The child never sees this. It goes to the log for whoever is debugging
      // a device, and the screen gets a sentence instead.
      _onDiagnostic(
        'StartupTask ${task.id} failed:\n$error\n$stackTrace',
      );
      _retryable.add(task.id);
      return _TaskFailure(task);
    }
  }

  void _fail(_TaskFailure failure) {
    final failed = <String>{..._progress.failedTasks, failure.task.id}.toList()
      ..sort();
    _emit(
      _progress.copyWith(
        status: StartupStatus.failed,
        currentTask: failure.task.id,
        message: failure.task.message,
        failedTasks: failed,
        errorMessage: failure.task.failureMessage,
      ),
    );
  }

  @override
  void warmLater(String taskId) {
    final task = _tasks[taskId];
    if (task == null) {
      _onDiagnostic('warmLater("$taskId") has no such startup task');
      return;
    }
    if (_succeeded.contains(taskId)) return;
    // Deliberately untracked and un-awaited: this is the whole point of a lazy
    // task, and a failure here has nowhere to go but the log.
    unawaited(
      _runTask(task).then((failure) {
        if (failure != null) return;
        _onDiagnostic('Lazily warmed "$taskId" after startup');
      }),
    );
  }

  /// Publishes the weighted sum of what has been done so far.
  void _emitProgressOnly() => _emit(_progress.copyWith(progress: _fraction()));

  double _fraction() {
    final total = _totalWeight();
    if (total <= 0) return _succeeded.isEmpty ? 0.0 : 1.0;
    var done = 0.0;
    for (final task in _requiredTasks) {
      if (_succeeded.contains(task.id)) {
        done += task.weight;
      } else {
        done += task.weight * (_reported[task.id] ?? 0.0);
      }
    }
    return clampProgress(done / total);
  }

  double _totalWeight() {
    var total = 0.0;
    for (final task in _requiredTasks) {
      total += task.weight;
    }
    return total;
  }

  List<StartupTask> get _requiredTasks => _tasks.values
      .where((t) => t.criticality == StartupCriticality.required)
      .toList(growable: false);

  void _emit(StartupProgress next) {
    // An equal snapshot is not news. Starting three tasks in a row emits the
    // same progress three times, and a loading screen that rebuilds for an
    // identical value is jank bought for nothing.
    if (next == _progress) return;
    _progress = next;
    if (_disposed) return;
    if (!_controller.isClosed) _controller.add(next);
  }

  /// Orders tasks into levels that can run at the same time.
  ///
  /// A cycle is a configuration mistake and says so here, at startup, rather
  /// than as a task that silently never runs.
  List<List<StartupTask>> _buildLevels() {
    final required = _requiredTasks.toList(growable: false);

    for (final task in required) {
      for (final dependency in task.dependsOn) {
        final target = _tasks[dependency];
        if (target == null) {
          throw ArgumentError(
            'Startup task "${task.id}" depends on "$dependency", '
            'which is not a registered task',
          );
        }
        if (target.criticality != StartupCriticality.required) {
          throw ArgumentError(
            'Startup task "${task.id}" depends on "$dependency", which is '
            'lazy. A required task cannot wait on work that is allowed to fail.',
          );
        }
      }
    }

    final levels = <List<StartupTask>>[];
    final done = <String>{};
    final pending = [...required];

    while (pending.isNotEmpty) {
      final ready = pending
          .where((task) => task.dependsOn.every(done.contains))
          .toList(growable: false);
      if (ready.isEmpty) {
        throw ArgumentError(
          'Startup tasks form a dependency cycle: '
          '${pending.map((t) => t.id).join(', ')}',
        );
      }
      for (final task in ready) {
        pending.remove(task);
        done.add(task.id);
      }
      levels.add(ready);
    }
    return levels;
  }

  /// Releases the progress stream.
  ///
  /// Only called from the composition root when the container goes away;
  /// during a normal run the coordinator outlives every screen.
  Future<void> dispose() async {
    _disposed = true;
    await _controller.close();
  }
}

class _TaskFailure {
  const _TaskFailure(this.task);

  final StartupTask task;
}