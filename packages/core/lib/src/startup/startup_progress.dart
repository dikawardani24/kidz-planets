import 'package:equatable/equatable.dart';

import 'startup_message.dart';
import 'startup_status.dart';

/// An immutable snapshot of startup progress.
///
/// Every value that reaches the loading screen goes through this, so the
/// screen never has to defend against a progress of 1.4 or a negative one from
/// a task that finished early. Clamping is done once, here, rather than in
/// every widget that draws a bar.
class StartupProgress extends Equatable {
  const StartupProgress({
    this.status = StartupStatus.idle,
    this.progress = 0.0,
    this.currentTask,
    this.message = StartupMessage.preparing,
    this.failedTasks = const [],
    this.errorMessage,
  });

  /// The state of the whole pipeline.
  final StartupStatus status;

  /// Real completion in `0..1`.
  ///
  /// This is work actually done: the weighted sum of finished tasks plus the
  /// reported share of the running ones. It is not a timer, and it does not
  /// creep towards 100% while something is still loading.
  final double progress;

  /// Id of the task currently running, for diagnostics and tests.
  final String? currentTask;

  /// What is being done right now.
  ///
  /// Typed rather than written out, because the app resolves it through its
  /// translation table. Three consecutive tasks reporting [preparing] is the
  /// "Loading… Loading… Loading…" screen, and it is reachable from here — which
  /// is why the phases below it are worth having.
  final StartupMessage message;

  /// Ids of tasks that did not finish, in the order they failed.
  ///
  /// A retry uses this to skip everything that already worked.
  final List<String> failedTasks;

  /// What to show a child when startup failed. Never an exception message.
  final String? errorMessage;

  /// True once the app is safe to show the solar system.
  bool get isReady => status == StartupStatus.ready;

  bool get hasFailed => status == StartupStatus.failed;

  StartupProgress copyWith({
    StartupStatus? status,
    double? progress,
    String? currentTask,
    StartupMessage? message,
    List<String>? failedTasks,
    String? errorMessage,
    bool clearError = false,
  }) => StartupProgress(
    status: status ?? this.status,
    progress: clampProgress(progress ?? this.progress),
    currentTask: currentTask ?? this.currentTask,
    message: message ?? this.message,
    failedTasks: failedTasks ?? this.failedTasks,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    progress,
    currentTask,
    message,
    failedTasks,
    errorMessage,
  ];
}

/// Keeps a progress value inside `0..1`.
///
/// A task that reports 1.2 because it finished while its last await resolved
/// twice, or a retry that adds a completed task's weight twice, would otherwise
/// draw a bar that overflows its track. One clamp, at the boundary, is cheaper
/// to reason about than defensive code in every producer.
double clampProgress(double value) {
  if (value.isNaN) return 0.0;
  if (value < 0.0) return 0.0;
  if (value > 1.0) return 1.0;
  return value;
}