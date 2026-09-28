import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/planet.dart';

class PlanetNarrationService {
  PlanetNarrationService({AudioPlayer? player})
      : _players = [player ?? AudioPlayer(), AudioPlayer()];

  final List<AudioPlayer> _players;
  int _activeIndex = 0;
  int _generation = 0;
  Timer? _fadeTimer;

  Future<void> speakPlanet(Planet planet) =>
      _play(NarrationAudioCatalog.planet(planet.id));

  Future<void> speakHotspot(Hotspot hotspot) =>
      _play(NarrationAudioCatalog.hotspot(hotspot.title));

  Future<void> replay(Planet planet) => speakPlanet(planet);

  Future<void> stop() async {
    ++_generation;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    for (final player in _players) {
      try {
        await player.stop();
        await player.setVolume(0);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    ++_generation;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    for (final player in _players) {
      try {
        await player.stop();
      } catch (_) {}
      await player.dispose();
    }
  }

  Future<void> _play(String path) async {
    // Two players allow the outgoing narration to fade down while the new
    // narration fades up. This avoids the hard stop/start feeling of a
    // single AudioPlayer.
    final generation = ++_generation;
    _fadeTimer?.cancel();
    _fadeTimer = null;

    final incomingIndex = 1 - _activeIndex;
    final outgoingIndex = _activeIndex;
    final incoming = _players[incomingIndex];
    final outgoing = _players[outgoingIndex];

    try {
      await incoming.stop();
      await incoming.setVolume(0);
      if (generation != _generation) return;

      await incoming.setAsset(path);
      if (generation != _generation) return;

      _activeIndex = incomingIndex;
      await incoming.play();
      if (generation != _generation) return;

      await _crossfade(
        generation: generation,
        incoming: incoming,
        outgoing: outgoing,
      );
    } catch (error) {
      if (generation == _generation) {
        debugPrint('Narration asset unavailable: $path ($error)');
      }
    }
  }

  Future<void> _crossfade({
    required int generation,
    required AudioPlayer incoming,
    required AudioPlayer outgoing,
  }) async {
    const duration = Duration(milliseconds: 260);
    const steps = 13;
    const stepDuration = Duration(milliseconds: 20);

    final startedAt = DateTime.now();
    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(stepDuration);
      if (generation != _generation) return;

      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      final t = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
      // Smoothstep gives the transition a softer, less mechanical curve.
      final eased = t * t * (3 - 2 * t);
      await incoming.setVolume(0.92 * eased);
      await outgoing.setVolume(0.92 * (1 - eased));
    }

    if (generation != _generation) return;
    await outgoing.stop();
    await outgoing.setVolume(0);
    await incoming.setVolume(0.92);
    _fadeTimer = null;
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
