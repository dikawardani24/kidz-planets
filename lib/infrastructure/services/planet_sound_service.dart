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
  Future<void> _queue = Future<void>.value();

  Future<void> playBody(Planet body) {
    final path = PlanetSoundCatalog.body(body.id);
    _queue = _queue.then((_) async {
      try {
        await _player.stop();
        await _player.setLoopMode(LoopMode.one);
        await _player.setVolume(0.42);
        await _player.setAsset(path);
        await _player.play();
      } catch (error) {
        debugPrint('Planet sound unavailable: $path ($error)');
      }
    }).catchError((_) {});
    return _queue;
  }

  Future<void> stop() {
    _queue = _queue.then((_) => _player.stop()).catchError((_) {});
    return _queue;
  }

  Future<void> dispose() async {
    try {
      await _player.stop();
    } catch (_) {}
    await _player.dispose();
  }
}

abstract final class PlanetSoundCatalog {
  static String body(String id) => 'assets/audio/sfx/planets/$id.wav';
}
