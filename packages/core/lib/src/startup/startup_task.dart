import 'startup_message.dart';
import 'startup_status.dart';

/// One unit of startup work.
///
/// Features own their own tasks; `core` owns the contract they are written
/// against, and the coordinator sees nothing else. That is what keeps the
/// startup pipeline from growing an `if (task is PlanetTask)` in it: a new
/// feature adds a class here and is never edited into the coordinator.
abstract interface class StartupTask {
  /// Stable identity, used for dependency wiring and retry bookkeeping.
  ///
  /// Dotted and snake-cased (`planets.scene`) so a log line says which part of
  /// which feature produced it.
  String get id;

  /// The typed phase this task starts in.
  ///
  /// [StartupTaskContext.reportProgress] changes it as the task moves through
  /// its work, which is why a long task can say "Waking up the Sun…" and then
  /// "Painting the planets…" instead of repeating one line for four seconds.
  StartupMessage get message;

  /// The task's own English sentence, used for logs and as the copy fallback
  /// when no [message] has been reported yet.
  String get title;

  /// What the child is told if this task fails.
  ///
  /// A sentence about their experience, never an exception: "We couldn't load
  /// the planets." The technical error goes to the log through the
  /// coordinator's diagnostic callback instead, because a stack trace in front
  /// of a seven-year-old helps nobody.
  String get failureMessage;

  /// Share of the total progress bar this task is worth.
  ///
  /// Weights are cost estimates, not decoration: the solar system decodes about
  /// eight megabytes of texture and gets a large share, while building a
  /// constant catalogue of missions costs microseconds and gets a small one.
  /// [weight] of 0 is legal and means "report progress, move the bar not at
  /// all".
  double get weight;

  /// Whether startup can survive this task failing.
  StartupCriticality get criticality;

  /// Ids of tasks that must finish before this one starts.
  ///
  /// The coordinator runs independent tasks together and only imposes an order
  /// that is written down here, so concurrency is the default and sequencing is
  /// the exception that has to be justified. `const {}` therefore means "I
  /// have thought about it and need nothing first" — which is a claim worth
  /// making out loud, and the reason this is abstract rather than defaulted.
  Set<String> get dependsOn;

  /// Does the work.
  ///
  /// Must be idempotent. Startup can be asked to retry, and a task that
  /// half-finished must be safe to run again: building a scene graph twice is
  /// wasteful, creating a second audio player is a bug, and a child seeing the
  /// loading screen twice must not hear the sounds twice.
  ///
  /// [context] is how the task reports what it is doing. Tasks must not emit
  /// progress after returning, and must tolerate being cancelled by the app
  /// going away mid-await.
  Future<void> execute(StartupTaskContext context);
}

/// What a running task is handed to report progress.
///
/// Deliberately tiny. A task that could reach the coordinator directly could
/// set any value it liked, including a status; a callback can only move its own
/// slice of the bar, and the coordinator still decides what the overall number
/// means.
abstract interface class StartupTaskContext {
  /// Reports how much of *this* task is done, `0..1`, and what it is doing.
  ///
  /// Out-of-range fractions are ignored rather than clamped, because a task that
  /// reports backwards is a bug and a silently clamped bar would hide it. The
  /// message is optional so the common case stays short.
  void reportProgress(double fraction, {StartupMessage? message});
}

/// The default [StartupTaskContext]: a task that reports into a callback.
class CallbackStartupTaskContext implements StartupTaskContext {
  CallbackStartupTaskContext(this._onReport);

  final void Function(double fraction, StartupMessage? message) _onReport;

  @override
  void reportProgress(double fraction, {StartupMessage? message}) {
    if (fraction.isNaN) return;
    if (fraction < 0.0 || fraction > 1.0) return;
    _onReport(fraction, message);
  }
}
