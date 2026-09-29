import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/planet.dart';

class PlanetSoundService {
  PlanetSoundService({AudioPlayer? player})
      : _players = [player ?? AudioPlayer(), AudioPlayer()];

  final List<AudioPlayer> _players;
  int _activeIndex = 0;
  int _generation = 0;

  Future<void> playBody(Planet body) =>
      _play(PlanetSoundCatalog.body(body.id));

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

  Future<void> _fadeOut(int generation) async {
    const duration = Duration(milliseconds: 220);
    const steps = 11;
    const stepDuration = Duration(milliseconds: 20);
    final player = _players[_activeIndex];
    final startedAt = DateTime.now();

    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(stepDuration);
      if (generation != _generation) return;
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      final t = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = 1 - (t * t * (3 - 2 * t));
      await player.setVolume(0.42 * eased);
    }

    if (generation != _generation) return;
    for (final p in _players) {
      try {
        await p.stop();
        await p.setVolume(0);
      } catch (_) {}
    }
  }

  Future<void> _play(String path) async {
    final generation = ++_generation;

    final incomingIndex = 1 - _activeIndex;
    final outgoingIndex = _activeIndex;
    final incoming = _players[incomingIndex];
    final outgoing = _players[outgoingIndex];

    try {
      await incoming.stop();
      await incoming.setVolume(0);
      await incoming.setLoopMode(LoopMode.one);
      if (generation != _generation) return;

      await incoming.setAsset(path);
      if (generation != _generation) return;

      _activeIndex = incomingIndex;
      // `play()` remains pending until playback finishes, so it must not be
      // awaited here or the crossfade would never start during a transition.
      unawaited(_startPlayback(incoming, path));
      if (generation != _generation) return;

      const duration = Duration(milliseconds: 220);
      const steps = 11;
      for (var step = 1; step <= steps; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (generation != _generation) return;

        final t = step / steps;
        final eased = t * t * (3 - 2 * t);
        await incoming.setVolume(0.42 * eased);
        await outgoing.setVolume(0.42 * (1 - eased));
      }

      if (generation != _generation) return;
      await outgoing.stop();
      await outgoing.setVolume(0);
      await incoming.setVolume(0.42);
    } catch (error) {
      if (generation == _generation) {
        debugPrint('Planet sound unavailable: $path ($error)');
      }
    }
  }
}

abstract final class PlanetSoundCatalog {
  static String body(String id) => 'assets/audio/sfx/planets/$id.wav';
}

  Future<void> _startPlayback(AudioPlayer player, String path) async {
    try {
      await player.play();
    } catch (error) {
      debugPrint('Planet sound playback failed: $path ($error)');
    }
  }
