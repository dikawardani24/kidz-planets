import 'package:flutter/material.dart';

import '../../../application/state/explorer_state.dart';
import '../../theme/app_theme.dart';

/// Bubble metrics. Top-level so the edge rules below are testable on their own
/// and the widget does not have to reach into a private state class.
const double kBubbleWidth = 190;
const double kBubbleHeight = 54;
const double kBubbleGap = 10;
const double kBubbleEdge = 8;

/// Horizontal side the bubble takes, chosen so it stays fully on screen.
enum BubbleSide { left, right }

/// Where the bubble goes for a companion at [avatarTop] in [viewport].
///
/// Prefers above the companion, drops below when there is no room, and slides
/// to whichever side has room. This depends only on the avatar's *position*,
/// never its rotation, so spinning the character can never fling the text off
/// the edge of the screen.
({double top, BubbleSide side, bool below}) bubblePlacement({
  required double avatarTop,
  required double avatarLeft,
  required double avatarWidth,
  required double avatarHeight,
  required Size viewport,
}) {
  final below = avatarTop - kBubbleHeight - kBubbleGap < kBubbleEdge;
  final top = below
      ? avatarTop + avatarHeight + kBubbleGap
      : avatarTop - kBubbleHeight - kBubbleGap;

  final centerX = avatarLeft + avatarWidth / 2;
  final fitsCentered =
      centerX - kBubbleWidth / 2 >= kBubbleEdge &&
      centerX + kBubbleWidth / 2 <= viewport.width - kBubbleEdge;

  // When the companion is far enough from both edges, the bubble is simply
  // centred over it. Otherwise it slides to whichever side has room, which is
  // what keeps it readable when the child parks the character in a corner.
  final side = fitsCentered
      ? BubbleSide.left
      : (centerX < viewport.width / 2
          ? BubbleSide.right
          : BubbleSide.left);

  return (top: top, side: side, below: below);
}

/// The bubble's left edge for a chosen [side], always clamped on screen.
///
/// The clamp is applied to both sides, not just the sliding one: a companion
/// parked hard against the right edge would otherwise put a "left" bubble
/// straight off the screen. Clamping after the choice, rather than choosing
/// from clamped candidates, keeps the side that has the most room.
double bubbleLeft({
  required BubbleSide side,
  required double avatarLeft,
  required double avatarWidth,
  required Size viewport,
}) {
  final preferred = side == BubbleSide.left
      ? avatarLeft
      : avatarLeft + avatarWidth - kBubbleWidth;
  final maxLeft = (viewport.width - kBubbleWidth - kBubbleEdge)
      .clamp(kBubbleEdge, double.infinity);
  return preferred.clamp(kBubbleEdge, maxLeft);
}

/// The line the companion says for [mood].
///
/// Visual-only communication was chosen, so this text is the companion's only
/// actual voice; the 3D motion is the emphasis, not a substitute for it.
String avatarLine(AvatarMood mood, String? targetName) {
  final target = targetName ?? 'the planet';
  return switch (mood) {
    AvatarMood.instruction => 'Ready? Find $target and tap it!',
    AvatarMood.searching => 'Take your time — I\'ll wait right here.',
    AvatarMood.wrong => 'Close! Let\'s read the clue together.',
    AvatarMood.retry => 'You\'ve got this — try one more!',
    AvatarMood.success => 'You found $target! Amazing flying!',
  };
}

/// Bubble accent per mood, so colour reinforces the pose.
Color avatarAccent(AvatarMood mood) {
  return switch (mood) {
    AvatarMood.instruction => AppTheme.accentSky,
    AvatarMood.searching => AppTheme.accentIndigo,
    AvatarMood.wrong => AppTheme.accentViolet,
    AvatarMood.retry => AppTheme.accentViolet,
    AvatarMood.success => AppTheme.accentAmber,
  };
}
