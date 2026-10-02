import 'package:planets/domain.dart';

/// Returns planets scaled down for the kid-friendly 3D view (OCP: scaling
/// constants live here so the datasource stays in prototype units).
class GetPlanetsUseCase {
  GetPlanetsUseCase(this._repository);

  final PlanetRepository _repository;

  List<Planet> call() => _repository.getPlanets();
}
