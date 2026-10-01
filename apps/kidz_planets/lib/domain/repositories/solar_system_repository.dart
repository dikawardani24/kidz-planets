import '../entities/mission.dart';
import '../entities/planet.dart';

/// Read-only catalogue of solar-system content (SRP).
abstract class SolarSystemRepository {
  List<Planet> getPlanets();
  List<Mission> getMissions();
  Planet planetById(String id);
}
