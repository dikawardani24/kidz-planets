import '../../domain/entities/planet.dart';
import 'planet_catalog.dart';

/// Static solar-system content ported 1:1 from `prototype/index.html`.
class SolarSystemLocalDataSource {
  List<Planet> getPlanets() => PlanetCatalog.planets;

  Planet planetById(String id) =>
      PlanetCatalog.planets.firstWhere((p) => p.id == id);
}
