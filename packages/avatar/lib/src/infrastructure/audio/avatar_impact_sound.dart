import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:avatar/state.dart';

/// The soft thud a thrown companion makes when it hits something.
///
/// A bounce is the one moment in a throw that deserves a sound: it is the
/// feedback that tells a child the toy actually reached the wall rather than
/// silently stopping, which is exactly the moment the original flick felt
/// broken. It is short and it has a ceiling, because a throw can produce
/// several in a second and a toy that clatters is a toy that gets muted.
///
/// The volume scales with how hard the toy was moving, from a soft tap to a
/// hard thud. Playing one asset at a varying volume is what keeps this to a
/// single sound file; a bank of separately recorded impacts would cost several
/// assets to express the same range, and impacts of differing loudness tend to
/// read as different objects rather than as the same toy being hit harder.
///
/// Every level in that range is chosen to be audible on a phone speaker. That
/// is worth stating plainly, because the first version of this curve was
/// smooth, monotonic and well-behaved by every measure except the one that
/// matters: normalised against the throw cap, a real wall hit asked for a
/// volume of about 0.1, which is silence, so the toy landed without a sound
/// and the feature read as broken.
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
       ) {
    // Applied here rather than in a factory, so that it is a property of the
    // sound rather than of how this happens to build its players. A no-op that
    // returns immediately off Android.
    for (final player in _players) {
      unawaited(player.setAndroidAudioAttributes(_sonification));
    }
  }

  /// How many players to keep for overlapping impacts.
  ///
  /// Three, because the sound is longer than the cooldown: a toy pinned in a
  /// corner can re-trigger faster than the sample finishes, and a single player
  /// would cut the new bounce off at the moment it starts.
  static const int _poolSize = 3;

  /// How an impact declares itself to the platform.
  ///
  /// The app keeps a looping planetary bed and a narration voice alive at the
  /// same time as this sound, and a player with no attributes of its own
  /// inherits the session's, which is whatever the last configured sound asked
  /// for. An impact is a UI sound: `sonification` content, meant to mix with the
  /// music and the voice rather than take the session over from them. Set per
  /// player rather than by configuring the session, so it cannot change the
  /// behaviour of the services that already work and survives a session
  /// reconfigured elsewhere.
  static const AndroidAudioAttributes _sonification = AndroidAudioAttributes(
    contentType: AndroidAudioContentType.sonification,
    usage: AndroidAudioUsage.assistanceSonification,
  );

  final List<AudioPlayer> _players;
  final Duration cooldown;

  int _next = 0;
  DateTime _lastPlayedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  /// The volume an impact of [impactSpeed] plays at, from `0` to `1`.
  ///
  /// Exposed because the mapping is the part that decides whether the toy
  /// sounds like it is hitting something rather than clicking, and because
  /// being inaudible is not something a test can notice on its own: the whole
  /// play path can be correct and still be far too quiet to hear.
  static double volumeForImpact(double impactSpeed) {
    final audible = AvatarPhysicsConfig.impactVelocity;
    if (impactSpeed <= audible) return 0;
    // Normalised against the speed a hard fling really reaches a wall at, then
    // square-rooted. The root is what keeps the quiet end audible: a steeper
    // curve spends almost the whole range below the level a phone speaker
    // reproduces, so a real bounce asks for a volume that never comes out.
    final t =
        ((impactSpeed - audible) /
                (AvatarPhysicsConfig.impactReferenceSpeed - audible))
            .clamp(0.0, 1.0);
    final shaped = math.sqrt(t);
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
