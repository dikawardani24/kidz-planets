import 'package:avatar/state.dart';

/// The companion's answer to a mission beat: what it does and for how long.
///
/// Mission moods and companion reactions are two different vocabularies. A mood
/// is what the *mission* is doing to the child (a clue is being given, a pick
/// was wrong, the target was found); a reaction is what the *body* does about
/// it (talking, drooping, laughing). Keeping the translation in one pure
/// function means the widget never invents a reaction of its own and the
/// mapping is testable without a widget tree or a GPU.
///
/// [AvatarMood.searching] maps to [AvatarReaction.none] on purpose: looking
/// around is the calm default, and the companion must not celebrate at a child
/// who is simply exploring. The caller plays [none] by clearing any reaction
/// rather than by timing one out.
({AvatarReaction reaction, Duration duration}) companionBeatFor(
  AvatarMood mood,
) {
  return switch (mood) {
    // Being told what to look for: the companion talks it through, and needs
    // longer than a tap reaction because a child is reading while it plays.
    AvatarMood.instruction => (
      reaction: AvatarReaction.talking,
      duration: const Duration(milliseconds: 2600),
    ),
    AvatarMood.searching => (
      reaction: AvatarReaction.none,
      duration: Duration.zero,
    ),
    // A wrong pick earns disappointment, never crossness. Long enough for the
    // droop to be read, short enough that trying again feels encouraged.
    AvatarMood.wrong => (
      reaction: AvatarReaction.sad,
      duration: const Duration(milliseconds: 2200),
    ),
    // Tapping the companion after a miss is the child asking to try again, so
    // the answer is energy rather than another apology.
    AvatarMood.retry => (
      reaction: AvatarReaction.excited,
      duration: const Duration(milliseconds: 1800),
    ),
    // Success is the loudest beat: repeated bounces and a laugh, long enough to
    // cover the celebration dialog opening.
    AvatarMood.success => (
      reaction: AvatarReaction.laughing,
      duration: const Duration(milliseconds: 2600),
    ),
  };
}

/// How fast the companion flies while [reaction] plays, as a multiplier.
///
/// This is the "reduced energy" half of the reaction model: a sleepy companion
/// drifts, a sad one trudges, and an excited one races. The multiplier scales
/// the flight *rate* rather than the position, so a reaction starting or ending
/// mid-flight never teleports the companion along its path.
double reactionSpeedFactor(AvatarReaction reaction) {
  return switch (reaction) {
    AvatarReaction.sleepy => 0.35,
    AvatarReaction.sad => 0.6,
    AvatarReaction.excited => 1.4,
    AvatarReaction.laughing => 1.2,
    AvatarReaction.dizzy => 1.15,
    AvatarReaction.happy => 1.1,
    AvatarReaction.none ||
    AvatarReaction.surprised ||
    AvatarReaction.confused ||
    AvatarReaction.talking => 1.0,
  };
}

/// Reactions that come with floating hearts above the companion.
///
/// Only the cheerful ones: hearts over a sad or dizzy companion would read as
/// the toy being pleased about the child's mistake.
bool reactionShowsHearts(AvatarReaction reaction) {
  return switch (reaction) {
    AvatarReaction.happy ||
    AvatarReaction.laughing ||
    AvatarReaction.excited => true,
    AvatarReaction.none ||
    AvatarReaction.surprised ||
    AvatarReaction.sad ||
    AvatarReaction.dizzy ||
    AvatarReaction.sleepy ||
    AvatarReaction.confused ||
    AvatarReaction.talking => false,
  };
}
