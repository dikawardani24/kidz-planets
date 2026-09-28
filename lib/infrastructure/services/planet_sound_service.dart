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
  int _generation = 0;

  Future<void> playBody(Planet body) {
    // Generation counter so a rapid tap A -> B cancels A's pending load
    // instead of queueing stale sounds behind it. Latest selection wins.
    final generation = ++_generation;
    final path = PlanetSoundCatalog.body(body.id);
    _queue = _queue.then((_) => _run(generation, path)).catchError((_) {});
    return _queue;
  }

  Future<void> _run(int generation, String path) async {
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

  Future<void> stop() {
    _generation++;
    _queue = _queue.then((_) => _player.stop()).catchError((_) {});
    return _queue;
  }

  Future<void> dispose() async {
    _generation++;
    try {
      await _player.stop();
    } catch (_) {}
    await _player.dispose();
  }
}

abstract final class PlanetSoundCatalog {
  static String body(String id) => 'assets/audio/sfx/planets/$id.wav';
}
