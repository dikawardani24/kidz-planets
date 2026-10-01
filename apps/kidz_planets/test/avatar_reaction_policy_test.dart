import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/avatar_reaction_policy.dart';
import 'package:kidz_planets/application/state/avatar_state.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';

/// The mission state and the companion state speak different languages: a
/// mission says "wrong pick", the body says "droop". These tests pin that
/// translation, because it is the only wiring between the two and it is
/// otherwise invisible: nothing in the widget tree would show a beat that had
/// been dropped.
void main() {
  group('mission mood to companion reaction', () {
    test('every mission beat has an answer', () {
      for (final mood in AvatarMood.values) {
        if (mood == AvatarMood.searching) continue;
        final beat = companionBeatFor(mood);
        expect(beat.reaction, isNot(AvatarReaction.none),
            reason: 'a real beat must move the body');
        expect(beat.duration.inMilliseconds, greaterThan(0),
            reason: '$mood needs a playing window');
      }
    });

    test('looking around is the calm default', () {
      expect(
        companionBeatFor(AvatarMood.searching).reaction,
        AvatarReaction.none,
        reason: 'a child exploring should not be celebrated at',
      );
    });

    test('the mission beats read as themselves', () {
      expect(companionBeatFor(AvatarMood.instruction).reaction,
          AvatarReaction.talking);
      expect(companionBeatFor(AvatarMood.wrong).reaction, AvatarReaction.sad);
      expect(companionBeatFor(AvatarMood.retry).reaction,
          AvatarReaction.excited);
      expect(companionBeatFor(AvatarMood.success).reaction,
          AvatarReaction.laughing);
    });

    test('instructions are read for longer than a tap is', () {
      final instruction = companionBeatFor(AvatarMood.instruction).duration;
      expect(
        instruction.inMilliseconds,
        greaterThan(2000),
        reason: 'a child reads while the companion talks',
      );
    });
  });

  group('reaction energy', () {
    test('sleepy and sad slow the companion down', () {
      expect(reactionSpeedFactor(AvatarReaction.sleepy), lessThan(1));
      expect(reactionSpeedFactor(AvatarReaction.sad), lessThan(1));
    });

    test('excited and laughing speed it up', () {
      expect(reactionSpeedFactor(AvatarReaction.excited), greaterThan(1));
      expect(reactionSpeedFactor(AvatarReaction.laughing), greaterThan(1));
    });

    test('a neutral or surprised companion keeps the normal pace', () {
      expect(reactionSpeedFactor(AvatarReaction.none), 1);
      expect(reactionSpeedFactor(AvatarReaction.surprised), 1);
      expect(reactionSpeedFactor(AvatarReaction.talking), 1);
    });
  });

  group('hearts', () {
    test('only the cheerful reactions send hearts', () {
      final hearts = AvatarReaction.values
          .where(reactionShowsHearts)
          .toSet();
      expect(
        hearts,
        {
          AvatarReaction.happy,
          AvatarReaction.laughing,
          AvatarReaction.excited,
        },
        reason: 'hearts over a sad companion would read as a joke',
      );
    });
  });
}
