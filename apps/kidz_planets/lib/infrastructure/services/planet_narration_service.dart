import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/planet.dart';

class PlanetNarrationService {
  /// [playerFactory] builds each half of the crossfade pair. It is injectable
  /// because both players are load-bearing: a test that substitutes only one
  /// still gets a real [AudioPlayer] on the other side, whose missing platform
  /// channel throws inside the crossfade and is then swallowed, so the call
  /// under test never happens.
  PlanetNarrationService({AudioPlayer Function()? playerFactory})
      : _players = List.generate(2, (_) => (playerFactory ?? AudioPlayer.new)());

  final List<AudioPlayer> _players;
  int _activeIndex = 0;
  int _generation = 0;

  Future<void> speakPlanet(Planet planet) =>
      _play(NarrationAudioCatalog.planet(planet.id));

  Future<void> speakHotspot(Hotspot hotspot) =>
      _play(NarrationAudioCatalog.hotspot(hotspot.title));

  Future<void> replay(Planet planet) => speakPlanet(planet);

  Future<void> stop() async {
    final generation = ++_generation;
    await _fadeOut(generation);
  }

  Future<void> dispose() async {
    ++_generation;
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
      // Start playback without awaiting completion. `play()` stays pending until
      // the narration finishes; awaiting it here would prevent the crossfade
      // from starting until the old narration had already ended.
      unawaited(_startPlayback(incoming, path));
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

  Future<void> _fadeOut(int generation) async {
    const duration = Duration(milliseconds: 260);
    const steps = 13;
    const stepDuration = Duration(milliseconds: 20);
    final player = _players[_activeIndex];
    final startedAt = DateTime.now();

    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(stepDuration);
      if (generation != _generation) return;
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      final t = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = 1 - (t * t * (3 - 2 * t));
      await player.setVolume(0.92 * eased);
    }

    if (generation != _generation) return;
    for (final p in _players) {
      try {
        await p.stop();
        await p.setVolume(0);
      } catch (_) {}
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
  }
}

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

  Future<void> _startPlayback(AudioPlayer player, String path) async {
    try {
      await player.play();
    } catch (error) {
      debugPrint('Narration playback failed: $path ($error)');
    }
  }
