import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/solar_system_local_datasource.dart';
import '../../data/repositories/solar_system_repository_impl.dart';
import '../../domain/entities/planet.dart';
import '../../domain/repositories/solar_system_repository.dart';
import '../../domain/usecases/get_missions_usecase.dart';
import '../../domain/usecases/get_planets_usecase.dart';
import '../controllers/explorer_controller.dart';
import 'explorer_state.dart';
import 'simulation_clock.dart';

// --- Data layer (DIP: UI depends on abstractions) ---

final _dataSourceProvider = Provider<SolarSystemLocalDataSource>((ref) {
  return SolarSystemLocalDataSource();
});

final solarSystemRepositoryProvider = Provider<SolarSystemRepository>((ref) {
  return SolarSystemRepositoryImpl(ref.watch(_dataSourceProvider));
});

final planetsProvider = Provider<List<Planet>>((ref) {
  return GetPlanetsUseCase(ref.watch(solarSystemRepositoryProvider)).call();
});

final planetByIdProvider = Provider.family<Planet, String>((ref, id) {
  return ref.watch(planetsProvider).firstWhere((p) => p.id == id);
});

// --- Application layer ---

final simulationClockProvider = Provider<SimulationClock>((ref) {
  final clock = SimulationClock();
  ref.onDispose(clock.dispose);
  return clock;
});

final explorerControllerProvider =
    StateNotifierProvider<ExplorerController, ExplorerState>((ref) {
  final missions =
      GetMissionsUseCase(ref.watch(solarSystemRepositoryProvider)).call();
  final controller = ExplorerController(
    clock: ref.watch(simulationClockProvider),
    initialMissions: missions,
  );
  ref.onDispose(controller.dispose);
  return controller;
});
