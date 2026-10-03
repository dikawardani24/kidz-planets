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

/// Whether the Explorer's 3D scene has presented at least one frame.
///
/// The startup gate waits for this (together with the rocket beat) before
/// revealing the Explorer, so the crossfade never exposes a half-compiled
/// first frame or the scene view's loading fallback. Defaults to true —
/// "nothing to wait for" — so tests and plain feature-hosts without a scene
/// view proceed exactly as before; the real scene view flips it to false on
/// mount and back to true on its first presented tick.
final explorerScenePresentedProvider = StateProvider<bool>((ref) => true);
