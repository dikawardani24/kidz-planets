import '../entities/planet.dart';
import '../repositories/solar_system_repository.dart';

/// Returns planets scaled down for the kid-friendly 3D view (OCP: scaling
/// constants live here so the datasource stays in prototype units).
class GetPlanetsUseCase {
  GetPlanetsUseCase(this._repository);

  final SolarSystemRepository _repository;

  List<Planet> call() => _repository.getPlanets();
}
