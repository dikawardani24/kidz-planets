import '../../domain/entities/mission.dart';
import '../../domain/entities/planet.dart';
import '../../domain/repositories/solar_system_repository.dart';
import '../datasources/planet_catalog.dart';
import '../datasources/solar_system_local_datasource.dart';

/// Repository implementation over the static local datasource (DIP).
class SolarSystemRepositoryImpl implements SolarSystemRepository {
  SolarSystemRepositoryImpl(this._dataSource);

  final SolarSystemLocalDataSource _dataSource;

  @override
  List<Planet> getPlanets() => _dataSource.getPlanets();

  @override
  List<Mission> getMissions() => _dataSource.getMissions();

  @override
  Planet planetById(String id) =>
      PlanetCatalog.planets.firstWhere((p) => p.id == id);
}
