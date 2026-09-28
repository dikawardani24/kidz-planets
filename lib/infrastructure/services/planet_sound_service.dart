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
  Timer? _fadeTimer;

  Future<void> playBody(Planet body) =>
      _play(PlanetSoundCatalog.body(body.id));

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
      await incoming.setLoopMode(LoopMode.one);
      if (generation != _generation) return;

      await incoming.setAsset(path);
      if (generation != _generation) return;

      _activeIndex = incomingIndex;
      await incoming.play();
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
