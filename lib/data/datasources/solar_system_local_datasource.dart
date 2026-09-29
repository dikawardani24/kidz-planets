import '../../domain/entities/mission.dart';
import '../../domain/entities/planet.dart';
import 'planet_catalog.dart';

/// Static solar-system content ported 1:1 from `prototype/index.html`.
class SolarSystemLocalDataSource {
  List<Planet> getPlanets() => PlanetCatalog.planets;

  List<Mission> getMissions() => const [
        Mission(
          id: 1,
          title: 'Find Planet Earth',
          description: 'Start at the Sun and count outward to our blue home world.',
          targetPlanetId: 'earth',
          startPoint: 'the Sun',
          direction: 'Count outward from the Sun',
          hint: 'Look for a blue world with bright oceans and visible land.',
        ),
        Mission(
          id: 2,
          title: 'Find Mars',
          description: 'Look for the small reddish rocky planet.',
          targetPlanetId: 'mars',
          startPoint: 'the Sun',
          direction: 'Count outward',
          hint: 'Look for a small reddish rocky world.',
        ),
        Mission(
          id: 3,
          title: 'Find Saturn',
          description: 'Find the planet surrounded by a bright ring system.',
          targetPlanetId: 'saturn',
          startPoint: 'the Sun',
          direction: 'Count outward',
          hint: 'Look for the planet with a spectacular ring system.',
        ),
        Mission(
          id: 4,
          title: 'Visit Jupiter',
          description: 'Find the giant planet with a famous storm.',
          targetPlanetId: 'jupiter',
          startPoint: 'the Sun',
          direction: 'Count outward',
          hint: 'Look for the largest planet with a giant storm.',
        ),
      ];
}
