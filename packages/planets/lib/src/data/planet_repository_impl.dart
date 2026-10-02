import '../domain/entities/planet.dart';
import '../domain/repositories/planet_repository.dart';
import 'datasources/solar_system_local_datasource.dart';

/// Repository implementation over the static local datasource (DIP).
class PlanetRepositoryImpl implements PlanetRepository {
  PlanetRepositoryImpl(this._dataSource);

  final SolarSystemLocalDataSource _dataSource;

  @override
  List<Planet> getPlanets() => _dataSource.getPlanets();

  @override
  Planet planetById(String id) => _dataSource.planetById(id);
}
