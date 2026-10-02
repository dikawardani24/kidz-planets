import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:avatar/state.dart';
import 'package:avatar/audio.dart';

/// Stands in for a real [AudioPlayer] and records what it was asked to do.
///
/// A real player needs a platform, and the interesting questions here are
/// about transitions and gating — one cue per expression change, no replays
/// while the expression lasts, ducking under narration — all decided before
/// any audio is loaded.
class _FakeExpressionPlayer extends AudioPlayer {
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
  // A real player's constructor reaches for the platform's audio session,
  // which needs a binary messenger even though none of these tests play
  // anything.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvatarExpressionSound transitions', () {
    test('plays once per expression change, not per frame', () async {
      final player = _FakeExpressionPlayer();
      final sound = AvatarExpressionSound(playerFactory: () => player);
      addTearDown(sound.dispose);

      expect(await sound.play(AvatarReaction.happy), isTrue);
      // Same expression again: no replay while it remains current.
      expect(await sound.play(AvatarReaction.happy), isFalse);
      expect(player.assets.length, 1);
    });

    test('a new expression fades the old one and plays the new cue', () async {
      final players = [_FakeExpressionPlayer(), _FakeExpressionPlayer()];
      var next = 0;
      final sound = AvatarExpressionSound(
        playerFactory: () => players[next++ % players.length],
      );
      addTearDown(sound.dispose);

      expect(await sound.play(AvatarReaction.happy), isTrue);
      expect(await sound.play(AvatarReaction.sad), isTrue);
      expect(
        players.expand((p) => p.assets),
        contains('assets/audio/sfx/avatar/avatar_sad.mp3'),
      );
    });

    test('returning to rest resets the dedupe key', () async {
      final player = _FakeExpressionPlayer();
      final sound = AvatarExpressionSound(playerFactory: () => player);
      addTearDown(sound.dispose);

      expect(await sound.play(AvatarReaction.happy), isTrue);
      expect(await sound.play(AvatarReaction.none), isFalse);
      // A second tap after rest is a second tap: it must be heard again.
      expect(await sound.play(AvatarReaction.happy), isTrue);
      expect(
        player.assets.where((a) => a.endsWith('avatar_happy.mp3')).length,
        2,
      );
    });

    test(
      'mission beats play their own cue under the mission result cue',
      () async {
        final player = _FakeExpressionPlayer();
        final sound = AvatarExpressionSound(playerFactory: () => player);
        addTearDown(sound.dispose);

        expect(await sound.playMission(AvatarMood.success), isTrue);
        expect(
          player.assets.single,
          'assets/audio/sfx/avatar/avatar_success.mp3',
        );
        // Quieter than a bare reaction: the long mission cue is already up.
        expect(
          player.volumes.single,
          lessThan(AvatarExpressionSound.baseVolume),
        );

        expect(await sound.playMission(AvatarMood.searching), isFalse);
      },
    );

    test('expression SFX duck under narration', () async {
      final player = _FakeExpressionPlayer();
      final sound = AvatarExpressionSound(
        playerFactory: () => player,
        voiceActive: true,
      );
      addTearDown(sound.dispose);

      expect(await sound.play(AvatarReaction.happy), isTrue);
      final expected =
          AvatarExpressionSound.baseVolume * AvatarExpressionSound.duckedVolume;
      expect(player.volumes.single, closeTo(expected, 0.001));
    });

    test('throw whoosh is rate-limited to one cue per flick', () async {
      final player = _FakeExpressionPlayer();
      final sound = AvatarExpressionSound(playerFactory: () => player);
      addTearDown(sound.dispose);

      final at = DateTime.utc(2026, 1, 1);
      expect(await sound.playThrowWhoosh(now: at), isTrue);
      expect(
        await sound.playThrowWhoosh(
          now: at.add(const Duration(milliseconds: 50)),
        ),
        isFalse,
      );
      expect(
        await sound.playThrowWhoosh(
          now: at.add(AvatarExpressionSound.throwCooldown * 2),
        ),
        isTrue,
      );
    });

    test('a disposed sound plays nothing rather than throwing', () async {
      final player = _FakeExpressionPlayer();
      final sound = AvatarExpressionSound(playerFactory: () => player);
      await sound.dispose();

      expect(await sound.play(AvatarReaction.happy), isFalse);
      expect(await sound.playMission(AvatarMood.success), isFalse);
      expect(await sound.playThrowWhoosh(), isFalse);
      expect(player.plays, 0);
    });
  });
}
