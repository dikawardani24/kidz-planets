import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kidz_planets/application/state/avatar_physics_config.dart';
import 'package:kidz_planets/infrastructure/services/avatar_impact_sound.dart';

/// Stands in for a real [AudioPlayer] and records what it was asked to do.
///
/// A real player needs a platform, and the interesting questions here are about
/// the volume mapping and the gating, both of which are decided before any
/// audio is loaded.
class _FakePlayer extends AudioPlayer {
  final List<String> assets = [];
  final List<double> volumes = [];
  int plays = 0;
  int stops = 0;
  bool disposed = false;

  @override
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async {
    assets.add(assetPath);
    return const Duration(milliseconds: 100);
  }

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> play() async {
    plays++;
    return Future<void>.value();
  }

  @override
  Future<void> stop() async {
    stops++;
    return Future<void>.value();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    return Future<void>.value();
  }
}

void main() {
  // A real player's constructor reaches for the platform's audio session, which
  // needs a binary messenger even though none of these tests play anything.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('volumeForImpact', () {
    test('is silent below the impact threshold', () {
      expect(AvatarImpactSound.volumeForImpact(0), 0);
      expect(
        AvatarImpactSound.volumeForImpact(AvatarPhysicsConfig.impactVelocity),
        0,
      );
    });

    test('never exceeds the configured ceiling', () {
      for (final speed in [
        AvatarPhysicsConfig.impactVelocity,
        500.0,
        1500.0,
        AvatarPhysicsConfig.maxThrowVelocity,
        AvatarPhysicsConfig.maxThrowVelocity * 10,
      ]) {
        expect(
          AvatarImpactSound.volumeForImpact(speed),
          lessThanOrEqualTo(AvatarPhysicsConfig.impactVolume),
          reason: 'speed $speed',
        );
      }
    });

    test('rises with the speed of the hit', () {
      var previous = 0.0;
      for (final speed in [100.0, 300.0, 800.0, 1600.0, 3000.0]) {
        final volume = AvatarImpactSound.volumeForImpact(speed);
        expect(volume, greaterThan(previous), reason: 'speed $speed');
        previous = volume;
      }
    });

    test('keeps the quiet end quiet', () {
      // A linear ramp would play a gentle nudge at most of the volume, which
      // reads as the toy being broken rather than lightly touched.
      final justAboveThreshold = AvatarImpactSound.volumeForImpact(
        AvatarPhysicsConfig.impactVelocity + 1,
      );
      expect(
        justAboveThreshold,
        lessThan(AvatarPhysicsConfig.impactVolume * 0.3),
      );
    });
  });

  group('playBounce', () {
    test('does not load the asset for an impact too soft to hear', () async {
      final player = _FakePlayer();
      final sound = AvatarImpactSound(playerFactory: () => player);

      final played = await sound.playBounce(
        impactSpeed: AvatarPhysicsConfig.impactVelocity - 1,
      );

      expect(played, isFalse);
      expect(player.assets, isEmpty);
    });

    test('plays the bounce asset at the mapped volume', () async {
      final player = _FakePlayer();
      final sound = AvatarImpactSound(playerFactory: () => player);

      final played = await sound.playBounce(impactSpeed: 1500.0);

      expect(played, isTrue);
      expect(player.assets, [AvatarImpactSoundCatalog.bounce]);
      expect(
        player.volumes.last,
        closeTo(AvatarImpactSound.volumeForImpact(1500.0), 0.0001),
      );
      expect(player.plays, 1);
    });

    test('reduced motion plays it more quietly', () async {
      final loud = _FakePlayer();
      final calm = _FakePlayer();

      await AvatarImpactSound(playerFactory: () => loud)
          .playBounce(impactSpeed: 1500.0);
      await AvatarImpactSound(playerFactory: () => calm)
          .playBounce(impactSpeed: 1500.0, reducedMotion: true);

      expect(calm.volumes.last, lessThan(loud.volumes.last));
      // The sound still happens; only its level changes, because a child who
      // asked for calmer interaction should still get the feedback.
      expect(calm.plays, 1);
    });

    test('a second impact inside the cooldown is dropped', () async {
      // A hard throw can cross a small window in a few frames, and without a
      // floor the bounces would overlap into a buzz.
      final player = _FakePlayer();
      final sound = AvatarImpactSound(playerFactory: () => player);

      expect(await sound.playBounce(impactSpeed: 2000.0), isTrue);
      expect(await sound.playBounce(impactSpeed: 2000.0), isFalse);
      expect(await sound.playBounce(impactSpeed: 2000.0), isFalse);
      expect(player.plays, 1);
    });

    test('the pool lets impacts overlap once the cooldown has passed', () async {
      // The cooldown is the limiter, not the pool, so a sound shorter than the
      // cooldown never needs a fourth player. A pool of one would cut the
      // second impact off mid-play.
      final players = List.generate(3, (_) => _FakePlayer());
      var next = 0;
      final sound = AvatarImpactSound(
        playerFactory: () => players[next++ % players.length],
        cooldown: Duration.zero,
      );

      expect(await sound.playBounce(impactSpeed: 2000.0), isTrue);
      expect(await sound.playBounce(impactSpeed: 2000.0), isTrue);
      expect(await sound.playBounce(impactSpeed: 2000.0), isTrue);

      expect(players.every((p) => p.plays == 1), isTrue);
    });

    test('a disposed sound plays nothing rather than throwing', () async {
      final player = _FakePlayer();
      final sound = AvatarImpactSound(playerFactory: () => player);
      await sound.dispose();

      expect(await sound.playBounce(impactSpeed: 2000.0), isFalse);
      expect(player.plays, 0);
    });

    test('dispose releases every player and is safe to repeat', () async {
      final players = List.generate(3, (_) => _FakePlayer());
      var next = 0;
      final sound = AvatarImpactSound(
        playerFactory: () => players[next++ % players.length],
      );

      await sound.dispose();
      await sound.dispose();

      expect(players.every((p) => p.disposed), isTrue);
    });
  });
}
