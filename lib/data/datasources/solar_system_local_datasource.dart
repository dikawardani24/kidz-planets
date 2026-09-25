import '../../domain/entities/mission.dart';
import '../../domain/entities/planet.dart';
import 'planet_catalog.dart';

/// Static solar-system content ported 1:1 from `prototype/index.html`.
class SolarSystemLocalDataSource {
  List<Planet> getPlanets() => PlanetCatalog.planets;

  List<Mission> getMissions() => const [
        Mission(
          id: 1,
          title: 'Find Earth',
          description: 'Locate our blue home world with liquid oceans.',
          targetPlanetId: 'earth',
        ),
        Mission(
          id: 2,
          title: 'Find Mars',
          description: 'Locate the Red Planet with polar ice caps.',
          targetPlanetId: 'mars',
        ),
        Mission(
          id: 3,
          title: 'Find Saturn',
          description: 'Inspect the tilted 3D ice ring system.',
          targetPlanetId: 'saturn',
        ),
        Mission(
          id: 4,
          title: 'Visit Jupiter',
          description: 'Inspect the Great Red Spot storm.',
          targetPlanetId: 'jupiter',
        ),
      ];
}
