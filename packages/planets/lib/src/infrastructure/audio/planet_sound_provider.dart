import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'planet_sound_service.dart';

final planetSoundServiceProvider = Provider<PlanetSoundService>((ref) {
  final service = PlanetSoundService();
  ref.onDispose(service.dispose);
  return service;
});
