import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:planets/state.dart';
import 'package:core/time.dart';
import 'package:planets/scene.dart';

/// Provides the long-lived imperative scene controller (SRP: wiring only).
final solarSystemSceneControllerProvider = Provider<SolarSystemSceneController>(
  (ref) {
    final SimulationClock clock = ref.watch(simulationClockProvider);
    final controller = SolarSystemSceneControllerImpl(clock: clock);
    ref.onDispose(controller.dispose);
    return controller;
  },
);
