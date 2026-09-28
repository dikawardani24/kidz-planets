import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'planet_narration_service.dart';

final planetNarrationServiceProvider = Provider<PlanetNarrationService>((ref) {
  final service = PlanetNarrationService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
