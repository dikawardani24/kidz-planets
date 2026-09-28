import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/planet.dart';

class PlanetNarrationService {
  PlanetNarrationService({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  int _generation = 0;

  Future<void> speakPlanet(Planet planet) =>
      _play(NarrationAudioCatalog.planet(planet.id));

  Future<void> speakHotspot(Hotspot hotspot) =>
      _play(NarrationAudioCatalog.hotspot(hotspot.title));

  Future<void> replay(Planet planet) => speakPlanet(planet);

  Future<void> stop() async {
    ++_generation;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    ++_generation;
    try {
      await _player.stop();
    } catch (_) {}
    await _player.dispose();
  }

  Future<void> _play(String path) async {
    // Do not queue narration. Selecting another object must interrupt
    // the current narration immediately; the latest selection wins.
    final generation = ++_generation;

    try {
      await _player.stop();
      if (generation != _generation) return;

      await _player.setAsset(path);
      if (generation != _generation) return;

      await _player.play();
    } catch (error) {
      if (generation == _generation) {
        debugPrint('Narration asset unavailable: $path ($error)');
      }
    }
  }
}

abstract final class NarrationAudioCatalog {
  static String planet(String planetId) =>
      'assets/audio/narration/planets/$planetId.mp3';

  static String hotspot(String title) =>
      'assets/audio/narration/hotspots/' + _slugify(title) + '.mp3';

  static String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
