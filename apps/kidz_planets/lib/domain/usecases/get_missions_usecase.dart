import '../entities/mission.dart';
import '../repositories/solar_system_repository.dart';

/// Returns the starter mission list.
class GetMissionsUseCase {
  GetMissionsUseCase(this._repository);

  final SolarSystemRepository _repository;

  List<Mission> call() => _repository.getMissions();
}
