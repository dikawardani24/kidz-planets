import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/startup.dart';

import 'package:kidz_planets/application/startup/startup_providers.dart';
import 'package:kidz_planets/application/startup/solar_system_startup_tasks.dart';

/// Overrides the app's coordinator with one built from [hooks].
///
/// The task table, the coordinator and the progress contract are the real
/// ones; only the feature work behind each hook is scripted. That is exactly
/// the seam the composition root wires real implementations into, so the
/// widget tests exercise the production pipeline end to end minus the GPU.
Override startupWith(FakeStartupHooks hooks) =>
    startupCoordinatorProvider.overrideWith(
      (ref) => StartupCoordinatorNotifier(
        tasks: buildSolarSystemStartupTasks(hooks: hooks),
      ),
    );

/// Controllable stand-ins for the real startup hooks.
///
/// The wiring table in `solar_system_startup_tasks.dart` still builds the six
/// tasks, but the work behind each hook is a script the test decides: block
/// until a gate opens, throw once, then succeed. That is what lets a widget
/// test observe a half-finished bar, a failure and a recovery without a GPU,
/// an audio session or the real scene.
class FakeStartupHooks extends SolarSystemStartupHooks {
  /// Task ids in invocation order, for ordering assertions.
  final List<String> calls = [];

  /// Task ids the test must release with [openGate] before they finish.
  final Map<String, Completer<void>> gates = {};

  /// Task ids that throw — the failure path.
  final Set<String> failing = {};

  /// Task ids reported to [calls]; see [calls].
  void gateOn(String id) => gates[id] = Completer<void>();

  /// Releases one [gateOn] gate; safe to call for an un-gated id.
  void openGate(String id) => gates.remove(id)?.complete();

  Future<void> _stage(
    String id,
    StartupMessage message,
    StartupTaskContext context,
  ) async {
    calls.add(id);
    // Report before the gate so a blocked task still owns its slice of the
    // bar and the child sees which phase is holding the loading screen.
    context.reportProgress(0.0, message: message);
    final gate = gates[id];
    if (gate != null) await gate.future;
    if (failing.contains(id)) throw StateError('startup failure: $id');
    context.reportProgress(1.0, message: message);
  }

  @override
  Future<void> configureSession(StartupTaskContext context) =>
      _stage(SolarSystemStartupTaskId.core, StartupMessage.preparing, context);

  @override
  Future<void> buildSolarSystem(StartupTaskContext context) => _stage(
    SolarSystemStartupTaskId.solarSystem,
    StartupMessage.solarSystem,
    context,
  );

  @override
  Future<void> loadMissions(StartupTaskContext context) => _stage(
    SolarSystemStartupTaskId.missions,
    StartupMessage.missions,
    context,
  );

  @override
  Future<void> primeCompanion(StartupTaskContext context) => _stage(
    SolarSystemStartupTaskId.companion,
    StartupMessage.companion,
    context,
  );

  @override
  Future<void> prepareSounds(StartupTaskContext context) =>
      _stage(SolarSystemStartupTaskId.sounds, StartupMessage.sounds, context);

  @override
  Future<void> buildMoons(StartupTaskContext context) =>
      _stage(SolarSystemStartupTaskId.moons, StartupMessage.moons, context);
}
