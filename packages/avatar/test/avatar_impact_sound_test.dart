import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:avatar/state.dart';
import 'package:avatar/audio.dart';

/// Stands in for a real [AudioPlayer] and records what it was asked to do.
///
/// A real player needs a platform, and the interesting questions here are about
/// the volume mapping and the gating, both of which are decided before any
/// audio is loaded.
class _FakePlayer extends AudioPlayer {
  final List<String> assets = [];
  final List<double> volumes = [];
  final List<AndroidAudioAttributes> attributes = [];
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
  Future<void> setAndroidAudioAttributes(
    AndroidAudioAttributes attributes,
  ) async {
    this.attributes.add(attributes);
  }

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

    test('an ordinary bounce is loud enough to actually hear', () {
      // The regression this file exists for: the play path can be entirely
      // correct and the result still inaudible. A volume curve normalised
      // against the throw cap asked for 0.09 at a real bounce speed, which no
      // phone speaker reproduces, and nothing in the play path noticed.
      //
      // 0.65 is the level the mission one-shots play at and are known to be
      // audible at, so an ordinary impact is held to that, with room above it
      // for a hard fling.
      // From a bounce worth hearing upwards. The bare threshold is excluded on
      // purpose: a toy that has barely left the wall is the quietest impact
      // there is, and it is the one the floor exists for.
      for (final speed in [200.0, 300.0, 600.0, 1000.0]) {
        expect(
          AvatarImpactSound.volumeForImpact(speed),
          greaterThanOrEqualTo(0.65),
          reason: 'a bounce at $speed px/s plays too quietly to hear',
        );
      }
    });

    test('a hard fling is audibly heavier than a nudge', () {
      // The range has to mean something, or every impact is the same click and
      // the child cannot tell a nudge from a fling. It is deliberately narrow,
      // because widening it would put the gentle end back below the level a
      // speaker reproduces; see the constant's own note on that trade.
      final gentle = AvatarImpactSound.volumeForImpact(200.0);
      final hard = AvatarImpactSound.volumeForImpact(2000.0);

      expect(hard / gentle, greaterThan(1.4));
    });

    test('keeps the quiet end quiet, and not silent', () {
      // The gentlest impact that is still an impact: quiet enough to read as a
      // graze, loud enough to be heard. Both halves matter, and the earlier
      // curve that this replaced satisfied only the first.
      final graze = AvatarImpactSound.volumeForImpact(
        AvatarPhysicsConfig.impactVelocity + 1,
      );

      expect(graze, greaterThan(0));
      expect(
        graze,
        lessThan(AvatarPhysicsConfig.impactVolume * 0.65),
        reason: 'a graze should be clearly softer than a slam',
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

    test('the players are set up to be heard alongside other audio', () async {
      // The app plays a looping planetary bed and a narration voice at the same
      // time as this. A player with no attributes of its own inherits the
      // session's, so a bounce can end up configured as whatever the last sound
      // to play asked for, and be ducked out of the mix or dropped entirely.
      // Caught here because nothing else fails when that happens: the play path
      // reports success and the device makes no sound.
      final players = <_FakePlayer>[];
      final sound = AvatarImpactSound(
        playerFactory: () {
          final player = _FakePlayer();
          players.add(player);
          return player;
        },
      );
      addTearDown(sound.dispose);

      expect(players, isNotEmpty, reason: 'the pool is empty');

      for (final player in players) {
        expect(
          player.attributes,
          isNotEmpty,
          reason: 'this player would inherit the session\'s attributes',
        );
        final attributes = player.attributes.single;
        expect(
          attributes.contentType,
          AndroidAudioContentType.sonification,
          reason: 'an impact is a UI sound, not a music stream',
        );
        expect(attributes.usage, AndroidAudioUsage.assistanceSonification);
      }
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
