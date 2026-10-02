import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/time.dart';
import 'package:planets/data.dart';
import 'package:planets/domain.dart';

import '../controllers/explorer_controller.dart';
import '../state/explorer_state.dart';

// --- Data layer (DIP: UI depends on abstractions) ---

final _localDataSourceProvider = Provider<SolarSystemLocalDataSource>((ref) {
  return SolarSystemLocalDataSource();
});

final planetRepositoryProvider = Provider<PlanetRepository>((ref) {
  return PlanetRepositoryImpl(ref.watch(_localDataSourceProvider));
});

final planetsProvider = Provider<List<Planet>>((ref) {
  return GetPlanetsUseCase(ref.watch(planetRepositoryProvider)).call();
});

final planetByIdProvider = Provider.family<Planet, String>((ref, id) {
  return ref.watch(planetsProvider).firstWhere((p) => p.id == id);
});

// --- Application layer ---

/// The single clock every animated body in the app reads.
///
/// Held here rather than in `core` because it is part of the explorer's
/// transport: pausing is a planets action, and nothing else animates on it.
final simulationClockProvider = Provider<SimulationClock>((ref) {
  final clock = SimulationClock();
  ref.onDispose(clock.dispose);
  return clock;
});

/// The explorer.
///
/// The application package does not override this one. It watches it instead,
/// which keeps a single instance of the explorer in the container and leaves the
/// provider graph readable from either side.
final explorerControllerProvider =
    StateNotifierProvider<ExplorerController, ExplorerState>((ref) {
      return ExplorerController(clock: ref.watch(simulationClockProvider));
    });
