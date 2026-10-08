import 'dart:ui' show Offset;

import 'package:flutter/widgets.dart' show FocusNode, VoidCallback;

/// Kind of chrome control participating in the Explorer spatial navigator.
enum TvChromeControl {
  zoomIn,
  zoomOut,
  rotate,
  playPause,
  quickSelect,
  help,
  other,
}

/// Registration payload for one interactive target (3D body or widget).
///
/// Lives in core so feature packages (which cannot import the app) can still
/// publish their controls into the app-owned spatial registry. The app's
/// [TvNavTarget] wraps this with focus + layout plumbing; the controller
/// owns the actual registry keyed by [TvRegisteredTarget.id].
class TvSpatialTarget {
  const TvSpatialTarget({
    required this.id,
    required this.center,
    this.control = TvChromeControl.other,
    this.focusNode,
    this.onActivate,
    this.enabled = true,
  });

  final String id;
  final Offset center;
  final TvChromeControl control;
  final FocusNode? focusNode;
  final VoidCallback? onActivate;
  final bool enabled;
}

/// One registered interactive target: a 3D body or a Flutter chrome control.
typedef TvRegisteredTarget = TvSpatialTarget;

/// One candidate for TV spatial D-pad navigation.
typedef TvSpatialCandidate = ({String id, Offset center});

/// Picks the nearest enabled candidate in [direction] from [origin].
///
/// Scoring matches the Explorer body cursor: prefer candidates roughly in the
/// requested direction, then break ties by distance with a mild angular
/// penalty. Returns null when nothing lies in that half-plane.
String? nearestInDirection({
  required Offset origin,
  required Offset direction,
  required Iterable<TvSpatialCandidate> candidates,
  String? excludeId,
  double minDot = -0.2,
  double angularPenaltyScale = 350,
}) {
  final dirLen = direction.distance;
  if (dirLen < 1e-6) return null;
  final targetDir = direction / dirLen;

  String? bestId;
  var bestScore = double.infinity;
  for (final candidate in candidates) {
    if (candidate.id == excludeId) continue;
    final vec = candidate.center - origin;
    final dist = vec.distance;
    if (dist < 1.0) continue;
    final norm = vec / dist;
    final dot = norm.dx * targetDir.dx + norm.dy * targetDir.dy;
    if (dot <= minDot) continue;
    final score = dist + (1.0 - dot) * angularPenaltyScale;
    if (score < bestScore) {
      bestScore = score;
      bestId = candidate.id;
    }
  }
  return bestId;
}

/// Unit screen-space direction for a D-pad arrow.
Offset tvDirectionForKey(String keyName) => switch (keyName) {
  'left' => const Offset(-1, 0),
  'right' => const Offset(1, 0),
  'up' => const Offset(0, -1),
  'down' => const Offset(0, 1),
  _ => Offset.zero,
};
