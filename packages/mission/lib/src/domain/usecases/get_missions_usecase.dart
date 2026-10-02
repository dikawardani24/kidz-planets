import 'package:mission/domain.dart';

import '../../data/mission_catalog.dart';

/// Returns the starter mission list.
///
/// The curriculum is bundled content rather than something remote, so there is
/// no repository to abstract: the use case exists to give callers one named
/// entry point and to be the seam where a remote or authored catalogue would
/// be swapped in later.
class GetMissionsUseCase {
  const GetMissionsUseCase();

  List<Mission> call() => MissionCatalog.missions;
}
