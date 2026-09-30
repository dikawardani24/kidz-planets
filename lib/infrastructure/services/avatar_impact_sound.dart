import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../application/state/avatar_physics_config.dart';

/// The soft thud a thrown companion makes when it hits something.
///
/// A bounce is the one moment in a throw that deserves a sound: it is the
/// feedback that tells a child the toy actually reached the wall rather than
/// silently stopping, which is exactly the moment the original flick felt
/// broken. It is deliberately quiet and short, because a throw can produce
/// several in a second and a toy that clatters is a toy that gets muted.
///
/// The volume scales with how hard the toy was moving, so a toy nudged across
/// the screen is inaudible and a hard fling thuds. Playing one asset at a
/// varying volume is what keeps this to a single sound file; a bank of
/// separately recorded impacts would cost several assets to express the same
/// range, and impacts of differing loudness tend to read as different objects
/// rather than as the same toy being hit harder.
class AvatarImpactSound {
  /// [playerFactory] builds each player in the pool, for the same reason as in
  /// `PlanetSoundService`: only one substituted player still leaves real ones
  /// behind it, so a test cannot prove the pool is needed.
  AvatarImpactSound({
    AudioPlayer Function()? playerFactory,
    this.cooldown = const Duration(
      milliseconds: AvatarPhysicsConfig.impactCooldownMs,
    ),
  }) : _players = List.generate(
         _poolSize,
         (_) => (playerFactory ?? AudioPlayer.new)(),
       );

  /// How many players to keep for overlapping impacts.
  ///
  /// Three is enough for the cooldown to be the limiter: with impacts at least
  /// [cooldown] apart and a sound shorter than the cooldown, one player per
  /// possibly in-flight sound is all that can ever be needed.
  static const int _poolSize = 3;

  /// The speed a full-volume impact corresponds to.
  static const double _loudestSpeed = AvatarPhysicsConfig.maxThrowVelocity;

  final List<AudioPlayer> _players;
  final Duration cooldown;

  int _next = 0;
  DateTime _lastPlayedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  /// The volume an impact of [impactSpeed] plays at, from `0` to `1`.
  ///
  /// Exposed because the mapping is the part that decides whether the toy
  /// sounds like it is hitting something rather than clicking.
  static double volumeForImpact(double impactSpeed) {
    final audible = AvatarPhysicsConfig.impactVelocity;
    if (impactSpeed <= audible) return 0;
    // Normalised against the loudest possible impact, then squared. The square
    // is what makes the quiet end quiet: a linear ramp would play a gentle
    // nudge at most of the volume, which reads as the toy being broken rather
    // than lightly touched.
    final t = ((impactSpeed - audible) / (_loudestSpeed - audible)).clamp(
      0.0,
      1.0,
    );
    final shaped = t * t;
    return AvatarPhysicsConfig.impactVolume *
        (AvatarPhysicsConfig.impactMinVolume +
            (1 - AvatarPhysicsConfig.impactMinVolume) * shaped);
  }

  /// Plays the impact for a bounce of [impactSpeed] pixels per second.
  ///
  /// Does nothing below the audible threshold or within [cooldown] of the last
  /// one. Returns whether it played, which the tests use in place of listening.
  Future<bool> playBounce({
    required double impactSpeed,
    bool reducedMotion = false,
  }) async {
    if (_disposed) return false;

    final volume = volumeForImpact(impactSpeed);
    if (volume <= 0) return false;

    // The caller also gates the squash on a cooldown, because both are two
    // expressions of the same impact; this one is the last line of defence for
    // the audio, in case an impact is reported from a path that did not check.
    final now = DateTime.now();
    if (now.difference(_lastPlayedAt) < cooldown) return false;
    _lastPlayedAt = now;

    // Reduced motion means less startling output as well as less movement,
    // since the child who asked the system for calmer interaction should not
    // be startled by the result of it.
    final scale = reducedMotion
        ? AvatarPhysicsConfig.reducedMotionImpactScale
        : 1.0;

    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    try {
      await player.stop();
      await player.setVolume(math.max(0.0, math.min(1.0, volume * scale)));
      await player.setAsset(AvatarImpactSoundCatalog.bounce);
      unawaited(player.play().catchError((Object _) {}));
      return true;
    } catch (error) {
      debugPrint('Avatar impact sound unavailable ($error)');
      return false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final player in _players) {
      try {
        await player.stop();
      } catch (_) {}
      await player.dispose();
    }
  }
}

/// Asset paths for the companion's own sounds.
abstract final class AvatarImpactSoundCatalog {
  /// MP3, matching the mission cues and the narration, which are the only
  /// audio paths confirmed to play on every target.
  static const bounce = 'assets/audio/sfx/avatar/avatar_bounce.mp3';
}
