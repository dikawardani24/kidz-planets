import 'dart:async';

import 'package:core/startup.dart';

import 'intro_copy.dart' show SolarSystemStartupTaskId;

/// A [StartupTask] over an inline function.
///
/// The app composes six of these rather than growing six classes: each task's
/// real work is one call into a feature-owned API, so the class would carry
/// nothing but the id, the weight and the copy. Retrying a function task
/// re-invokes the function, which is what the coordinator's retry path needs;
/// idempotency itself belongs to the callee (the scene controller memoizes,
/// the players are lazy singletons, the catalogue read is pure).
class FunctionStartupTask implements StartupTask {
  const FunctionStartupTask({
    required this.id,
    required this.message,
    required this.title,
    required this.failureMessage,
    required this.weight,
    required this.criticality,
    required Future<void> Function(StartupTaskContext context) execute,
    this.dependsOn = const {},
  }) : run = execute;

  @override
  final String id;

  @override
  final StartupMessage message;

  @override
  final String title;

  @override
  final String failureMessage;

  @override
  final double weight;

  @override
  final StartupCriticality criticality;

  @override
  final Set<String> dependsOn;

  final Future<void> Function(StartupTaskContext context) run;

  @override
  Future<void> execute(StartupTaskContext context) => run(context);
}

/// Relative bar shares for the startup tasks.
///
/// Estimates, not decoration: the solar system decodes the texture bulk, so it
/// owns the bar's middle; the catalogue read is microseconds and owns almost
/// nothing. Moons are lazy (warmed after Explorer is interactive) and do not
/// contribute to the required-task total that drives the Intro bar.
abstract final class SolarSystemStartupWeights {
  static const double core = 0.6;
  static const double solarSystem = 3.4;
  static const double missions = 0.2;
  static const double companion = 0.8;
  static const double sounds = 0.6;
  static const double moons = 1.4;

  /// Sum of **required** task weights the coordinator normalizes against.
  /// Asserted in tests so a weight edit that silently rescales the bar fails.
  static const double total = 5.6;
}

/// How long each startup task may run before its hang becomes a failure.
///
/// A task that never returns (an audio session the OS never grants on a TV,
/// a texture decode stalled on a weak GPU) would otherwise strand the child
/// on a full-looking bar forever: the bar reflects reported work, not a
/// timer. Timing out converts the hang into the coordinator's normal failure
/// path — kid-friendly error dialog plus retry — instead of a dead screen.
/// Budgets are generous on purpose: slow is fine, silent forever is not.
abstract final class StartupTimeouts {
  static const session = Duration(seconds: 30);
  static const solarSystem = Duration(minutes: 4);
  static const missions = Duration(seconds: 30);
  static const companion = Duration(seconds: 30);
  static const sounds = Duration(seconds: 60);
  static const moons = Duration(minutes: 3);

  static Duration? forTask(String id) => switch (id) {
    SolarSystemStartupTaskId.core => session,
    SolarSystemStartupTaskId.solarSystem => solarSystem,
    SolarSystemStartupTaskId.missions => missions,
    SolarSystemStartupTaskId.companion => companion,
    SolarSystemStartupTaskId.sounds => sounds,
    SolarSystemStartupTaskId.moons => moons,
    _ => null,
  };
}

Future<void> _withTimeout(Future<void> work, Duration limit, String taskId) =>
    work.timeout(
      limit,
      onTimeout: () =>
          throw TimeoutException('Startup task "$taskId" timed out', limit),
    );

/// The startup tasks for a cold start, in dependency order.
///
/// Required tasks block the Intro CTA. Moons are lazy: they warm after the
/// Explorer presents its first frame so weak TVs are not asked to decode
/// eighteen moon textures before the child can explore.
///
/// [planets.scene] waits on [core.session] so audio-session setup and megabyte
/// texture decode do not race on constrained GPUs.
///
/// [timeoutFor] overrides the per-task hang guard ([StartupTimeouts.forTask]
/// by default). Tests with scripted hooks that intentionally never finish
/// pass `(_) => null` so no watchdog timer outlives the test — a pending
/// `Future.timeout` timer fails a widget test at teardown.
List<StartupTask> buildSolarSystemStartupTasks({
  SolarSystemStartupHooks? hooks,
  Duration? Function(String taskId)? timeoutFor,
}) {
  final resolved = hooks ?? const SolarSystemStartupHooks();
  final limits = timeoutFor ?? StartupTimeouts.forTask;

  Future<void> Function(StartupTaskContext) guard(
    Future<void> Function(StartupTaskContext) run,
    String id,
  ) {
    final limit = limits(id);
    if (limit == null) return run;
    return (context) => _withTimeout(run(context), limit, id);
  }

  return [
    FunctionStartupTask(
      id: SolarSystemStartupTaskId.core,
      message: StartupMessage.preparing,
      title: 'Preparing the launch pad',
      failureMessage: 'We could not start your spaceship.',
      weight: SolarSystemStartupWeights.core,
      criticality: StartupCriticality.required,
      execute: guard(resolved.configureSession, SolarSystemStartupTaskId.core),
    ),
    FunctionStartupTask(
      id: SolarSystemStartupTaskId.solarSystem,
      message: StartupMessage.solarSystem,
      title: 'Building the solar system',
      failureMessage: 'We could not load the planets.',
      weight: SolarSystemStartupWeights.solarSystem,
      criticality: StartupCriticality.required,
      // Serialize GPU texture decode after the audio session is ready so weak
      // Android TV devices are not asked to do both at once.
      dependsOn: const {SolarSystemStartupTaskId.core},
      execute: guard(
        resolved.buildSolarSystem,
        SolarSystemStartupTaskId.solarSystem,
      ),
    ),
    FunctionStartupTask(
      id: SolarSystemStartupTaskId.missions,
      message: StartupMessage.missions,
      title: 'Reading the missions',
      failureMessage: 'We could not read your missions.',
      weight: SolarSystemStartupWeights.missions,
      criticality: StartupCriticality.required,
      execute: guard(resolved.loadMissions, SolarSystemStartupTaskId.missions),
    ),
    FunctionStartupTask(
      id: SolarSystemStartupTaskId.companion,
      message: StartupMessage.companion,
      title: 'Waking the rocket buddy',
      failureMessage: 'We could not wake your rocket buddy.',
      weight: SolarSystemStartupWeights.companion,
      criticality: StartupCriticality.required,
      execute: guard(
        resolved.primeCompanion,
        SolarSystemStartupTaskId.companion,
      ),
    ),
    FunctionStartupTask(
      id: SolarSystemStartupTaskId.sounds,
      message: StartupMessage.sounds,
      title: 'Tuning the space sounds',
      failureMessage: 'We could not tune the space sounds.',
      weight: SolarSystemStartupWeights.sounds,
      criticality: StartupCriticality.required,
      // The players are created before the session is configured only if the
      // two race, which would undo what `main` used to guarantee by awaiting
      // the session first. One edge in `dependsOn` keeps that order written
      // down instead of assumed.
      dependsOn: const {SolarSystemStartupTaskId.core},
      execute: guard(resolved.prepareSounds, SolarSystemStartupTaskId.sounds),
    ),
    FunctionStartupTask(
      id: SolarSystemStartupTaskId.moons,
      message: StartupMessage.moons,
      title: 'Painting the moons',
      failureMessage: 'We could not paint the moons.',
      weight: SolarSystemStartupWeights.moons,
      // Deferred: warm after first Explorer frame via warmLater. Does not gate
      // the Intro CTA; children cannot see moons until they zoom in anyway.
      criticality: StartupCriticality.lazy,
      dependsOn: const {SolarSystemStartupTaskId.solarSystem},
      execute: guard(resolved.buildMoons, SolarSystemStartupTaskId.moons),
    ),
  ];
}

/// The seam between the startup table and the real feature work.
///
/// Default hooks report completion and nothing else, so unit tests can run the
/// whole table (ordering, weights, retry, copy) without a GPU, a
/// platform-channel audio session, or the app's Riverpod container. The
/// composition root passes the real hooks (see `startup_hooks.dart`), which
/// call into the scene controller, the audio DI and the catalogue use case.
class SolarSystemStartupHooks {
  const SolarSystemStartupHooks();

  Future<void> configureSession(StartupTaskContext context) async {
    context.reportProgress(1.0, message: StartupMessage.preparing);
  }

  Future<void> buildSolarSystem(StartupTaskContext context) async {
    context.reportProgress(1.0, message: StartupMessage.planets);
  }

  Future<void> loadMissions(StartupTaskContext context) async {
    context.reportProgress(1.0, message: StartupMessage.missions);
  }

  Future<void> primeCompanion(StartupTaskContext context) async {
    context.reportProgress(1.0, message: StartupMessage.companion);
  }

  Future<void> prepareSounds(StartupTaskContext context) async {
    context.reportProgress(1.0, message: StartupMessage.sounds);
  }

  Future<void> buildMoons(StartupTaskContext context) async {
    context.reportProgress(1.0, message: StartupMessage.moons);
  }
}

/// Frame yields a long task inserts so the intro animation keeps its cadence.
///
/// Texture decodes and catalogue loops run on the UI isolate; without a yield
/// the rocket's float timer cannot fire until the whole task returns, which is
/// the freeze this screen exists to prevent.
Future<void> yieldToIntro() async {
  // Awaiting a zero timer posts to the event queue behind the vsync callback,
  // which is what lets a frame land between two chunks of work.
  await Future<void>.delayed(Duration.zero);
}

/// Reports one slice of a task's progress and yields to the intro.
///
/// Wraps the two lines every staged task repeats (`reportProgress` + yield)
/// so a task reads as its stages rather than as its plumbing.
void reportStage(
  StartupTaskContext context,
  double fraction, {
  StartupMessage? message,
}) {
  context.reportProgress(fraction, message: message);
  // `unawaited` on purpose: the stage is done, and the next stage must not
  // wait for the frame it just made room for.
  unawaited(yieldToIntro());
}
