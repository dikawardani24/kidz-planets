import '../entities/planet.dart';

/// Read-only catalogue of solar-system bodies (SRP).
///
/// Missions deliberately do not appear here. The curriculum lives in the
/// mission package, which must not depend on planets and which would otherwise
/// drag the whole 3D catalogue into the mission feature.
abstract class PlanetRepository {
  List<Planet> getPlanets();

  Planet planetById(String id);
}
