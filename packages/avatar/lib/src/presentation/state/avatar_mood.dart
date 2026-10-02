/// What the mission companion avatar is doing and saying right now.
///
/// The companion is always on screen, so the mood is the only thing that
/// changes; the character identity and its home on screen do not. It is stored
/// in state rather than derived, because "retry" and "searching" look the same
/// but mean different things to the child: retry follows a miss and earns an
/// encouraging line, searching is just the calm default.
///
/// The avatar owns this vocabulary because the pose, expression and sound are
/// all chosen from it. Whatever else decides a mood, it decides it in the
/// avatar's own terms.
enum AvatarMood {
  /// A mission is being explained. Talking, excited pose.
  instruction,

  /// The child is looking around. Curious, quiet, does not interrupt.
  searching,

  /// The child picked the wrong object. Disappointed but never cross.
  wrong,

  /// Immediately after a miss, once the failure pose has been seen.
  retry,

  /// A mission was completed. Celebrating.
  success,
}
