import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mission/domain.dart';

import '../controllers/mission_progress_controller.dart';
import '../state/mission_progress_state.dart';

/// The bundled curriculum, projected into playable state.
final missionProgressProvider =
    StateNotifierProvider<MissionProgressController, MissionProgressState>(
      (ref) => MissionProgressController(const GetMissionsUseCase().call()),
    );
