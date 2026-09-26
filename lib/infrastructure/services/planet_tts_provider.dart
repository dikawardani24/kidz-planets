import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'planet_tts_service.dart';

final planetTtsServiceProvider = Provider<PlanetTtsService>((ref) {
  final service = PlanetTtsService();
  ref.onDispose(() { service.stop(); });
  return service;
});
