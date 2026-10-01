import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/state/providers.dart';
import '../../../application/state/simulation_clock.dart';
import '../scene/solar_system_scene_controller.dart';

/// Provides the long-lived imperative scene controller (SRP: wiring only).
final solarSystemSceneControllerProvider =
    Provider<SolarSystemSceneController>((ref) {
  final SimulationClock clock = ref.watch(simulationClockProvider);
  final controller = SolarSystemSceneControllerImpl(clock: clock);
  ref.onDispose(controller.dispose);
  return controller;
});
