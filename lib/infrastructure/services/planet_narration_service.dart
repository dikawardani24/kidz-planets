import 'package:just_audio/just_audio.dart';

import '../../domain/entities/planet.dart';
import 'planet_tts_service.dart';

/// Plays pre-generated neural narration bundled with the app.
///
/// Audio files are treated as content assets rather than being synthesized
/// on-device. This keeps the voice natural, deterministic, and independent
/// of the device TTS engine. Until a neural audio asset exists, the service
/// falls back to [PlanetTtsService].
class PlanetNarrationService {
  PlanetNarrationService({
    AudioPlayer? player,
    PlanetTtsService? fallback,
  })  : _player = player ?? AudioPlayer(),
        _fallback = fallback ?? PlanetTtsService();

  final AudioPlayer _player;
  final PlanetTtsService _fallback;

  Future<void> _queue = Future<void>.value();
  int _generation = 0;

  Future<void> speakPlanet(Planet planet) {
    return _playOrFallback(
      path: NarrationAudioCatalog.planet(planet.id),
      fallback: () => _fallback.speakPlanet(planet),
    );
  }

  Future<void> speakHotspot(Hotspot hotspot) {
    return _playOrFallback(
      path: NarrationAudioCatalog.hotspot(hotspot.title),
      fallback: () => _fallback.speakHotspot(hotspot),
    );
  }

  Future<void> replay(Planet planet) => speakPlanet(planet);

  Future<void> stop() {
    _generation++;
    _queue = _queue.then((_) async {
      try {
        await _player.stop();
      } catch (_) {}
      await _fallback.stop();
    }).catchError((Object _) {});
    return _queue;
  }

  Future<void> dispose() async {
    _generation++;
    try {
      await _player.stop();
    } catch (_) {}
    await _player.dispose();
    await _fallback.stop();
  }

  Future<void> _playOrFallback({
    required String path,
    required Future<void> Function() fallback,
  }) {
    final generation = ++_generation;
    _queue = _queue
        .then((_) => _run(generation, path, fallback))
        .catchError((Object _) {});
    return _queue;
  }

  Future<void> _run(
    int generation,
    String path,
    Future<void> Function() fallback,
  ) async {
    try {
      await _player.stop();
      if (generation != _generation) return;

      try {
        await _player.setAsset(path);
      } catch (_) {
        if (generation != _generation) return;
        await fallback();
        return;
      }

      if (generation != _generation) return;
      await _player.play();
    } catch (_) {
      if (generation == _generation) {
        await fallback();
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