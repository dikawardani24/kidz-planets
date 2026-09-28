import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/planet.dart';

/// Plays pre-generated neural narration bundled with the app.
///
/// Audio files are treated as content assets rather than being synthesized
/// on-device. This keeps the voice natural, deterministic, and independent of
/// the device TTS engine.
///
/// Assets are generated locally with Kokoro; see
/// `tool/generate_neural_narration.py`. Narration never throws: a missing or
/// unreadable asset is reported in debug builds and ignored, so a content gap
/// can never crash the UI.
class PlanetNarrationService {
  PlanetNarrationService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  Future<void> _queue = Future<void>.value();
  int _generation = 0;

  Future<void> speakPlanet(Planet planet) {
    return _play(NarrationAudioCatalog.planet(planet.id));
  }

  Future<void> speakHotspot(Hotspot hotspot) {
    return _play(NarrationAudioCatalog.hotspot(hotspot.title));
  }

  Future<void> replay(Planet planet) => speakPlanet(planet);

  Future<void> stop() {
    _generation++;
    _queue = _queue.then((_) => _player.stop()).catchError(_ignore);
    return _queue;
  }

  Future<void> dispose() async {
    _generation++;
    try {
      await _player.stop();
    } catch (_) {}
    await _player.dispose();
  }

  static void _ignore(Object _) {}

  Future<void> _play(String path) {
    final generation = ++_generation;
    _queue = _queue.then((_) => _run(generation, path)).catchError(_ignore);
    return _queue;
  }

  Future<void> _run(int generation, String path) async {
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

/// Stable asset naming convention for neural narration.
///
/// Planet: assets/audio/narration/planets/saturn.mp3
/// Hotspot: assets/audio/narration/hotspots/icy_rings.mp3
abstract final class NarrationAudioCatalog {
  static String planet(String planetId) =>
      'assets/audio/narration/planets/$planetId.mp3';

  static String hotspot(String title) =>
      'assets/audio/narration/hotspots/${_slugify(title)}.mp3';

  static String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}