import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/planet.dart';

/// Plays subtle, stylized planetary ambience for the detail experience.
///
/// These are intentionally educational sound-design assets, not literal
/// recordings of planets. Sound cannot propagate through the vacuum of space;
/// NASA also uses sonification to translate space data into audible form.
class PlanetSoundService {
  PlanetSoundService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  int _generation = 0;

  Future<void> playBody(Planet body) async {
    // Invalidate the previous request immediately. Do not serialize playback:
    // selecting another body must interrupt the current sound right away.
    final generation = ++_generation;
    final path = PlanetSoundCatalog.body(body.id);

    try {
      await _player.stop();
      if (generation != _generation) return;

      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(0.42);
      if (generation != _generation) return;

      await _player.setAsset(path);
      if (generation != _generation) return;

      await _player.play();
    } catch (error) {
      if (generation == _generation) {
        debugPrint('Planet sound unavailable: $path ($error)');
      }
    }
  }

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
}

abstract final class PlanetSoundCatalog {
  static String body(String id) => 'assets/audio/sfx/planets/$id.wav';
}
