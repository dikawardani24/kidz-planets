import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:planets/domain.dart';

class PlanetSoundService {
  /// [playerFactory] builds each half of the crossfade pair, for the same
  /// reason as in [PlanetNarrationService]: only one substituted player still
  /// leaves a real one in the pair.
  PlanetSoundService({AudioPlayer Function()? playerFactory})
    : _newPlayer = playerFactory ?? AudioPlayer.new,
      _players = List.generate(2, (_) => (playerFactory ?? AudioPlayer.new)());

  static const double _ambientVolume = 0.42;

  final AudioPlayer Function() _newPlayer;
  final List<AudioPlayer> _players;
  int _activeIndex = 0;
  int _generation = 0;
  double _activeVolume = _ambientVolume;

  Future<void> playBody(Planet body) => _play(PlanetSoundCatalog.body(body.id));

  /// Loops the success cue until [stop] or [dispose] is called.
  ///
  /// A mission keeps its celebration dialog on screen for as long as the
  /// player wants, and a jingle is easy to miss in the middle of a tap, so the
  /// cue repeats for as long as the celebration lasts. It runs louder than the
  /// planetary beds because there is no voice competing with it here.
  Future<void> startMissionSuccess() =>
      _play(PlanetSoundCatalog.missionSuccess, volume: 0.7);

  Future<void> playMissionFailure() =>
      _playOneShot(PlanetSoundCatalog.missionFailure);

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
      await player.setVolume(_activeVolume * eased);
    }

    if (generation != _generation) return;
    for (final p in _players) {
      try {
        await p.stop();
        await p.setVolume(0);
      } catch (_) {}
    }
  }

  Future<void> _playOneShot(String path) async {
    try {
      final player = _newPlayer();
      await player.setVolume(0.65);
      await player.setAsset(path);
      unawaited(player.play().whenComplete(player.dispose));
    } catch (error) {
      debugPrint('Mission sound unavailable: $path ($error)');
    }
  }

  Future<void> _play(String path, {double volume = _ambientVolume}) async {
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

      const steps = 11;
      for (var step = 1; step <= steps; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (generation != _generation) return;

        final t = step / steps;
        final eased = t * t * (3 - 2 * t);
        await incoming.setVolume(volume * eased);
        await outgoing.setVolume(_activeVolume * (1 - eased));
      }

      if (generation != _generation) return;
      await outgoing.stop();
      await outgoing.setVolume(0);
      await incoming.setVolume(volume);
      _activeVolume = volume;
    } catch (error) {
      if (generation == _generation) {
        debugPrint('Planet sound unavailable: $path ($error)');
      }
    }
  }
}

abstract final class PlanetSoundCatalog {
  static String body(String id) => 'assets/audio/sfx/planets/$id.wav';

  /// MP3 rather than WAV, matching the narration in
  /// `assets/audio/narration`, which is the only audio path confirmed to play
  /// on every target. The cues were authored as 24 kHz mono PCM WAV and match
  /// the narration's rate and channel count; the container was the only
  /// difference, so WAV was the thing to rule out and it is now ruled out.
  static const missionSuccess = 'assets/audio/sfx/missions/mission_success.mp3';
  static const missionFailure = 'assets/audio/sfx/missions/mission_failure.mp3';
}

Future<void> _startPlayback(AudioPlayer player, String path) async {
  try {
    await player.play();
  } catch (error) {
    debugPrint('Planet sound playback failed: $path ($error)');
  }
}
