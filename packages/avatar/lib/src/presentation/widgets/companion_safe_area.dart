import 'package:flutter/widgets.dart';

import 'package:avatar/state.dart';
import 'package:core/layout.dart';

/// The toy's rendered size, and the gap it keeps from the edge of the screen.
///
/// These live here rather than in the companion widget because the throwable
/// area has to be computed by something that cannot depend on the widget that
/// renders the toy: the widget needs the area in order to lay the toy out, so
/// deriving the area from the widget would be a cycle. `mission_companion.dart`
/// re-exports them, so existing importers of that file are unaffected.
const double kCompanionBoxWidth = 132;
const double kCompanionBoxHeight = 148;
const double kCompanionEdge = 8;

/// The rectangle the companion may be thrown around inside.
///
/// The toy is the last child of a full-viewport stack, so its own layout box
/// covers the whole screen, including the strip behind the top bar and the one
/// behind the bottom nav. Left alone, a throw therefore ends with the toy
/// parked behind the nav or under the status bar, and a bounced toy disappears
/// under a bar the child is trying to tap on.
///
/// This is the one place that knows how much of the screen is not available.
/// Both edges are derived rather than assumed: the top from [kTopBarExtent],
/// which the top bar itself uses to position itself, and the bottom from the
/// nav's own constants. Insets come from [MediaQuery.paddingOf] rather than
/// from a guess about which platform is running, since a notched phone, a
/// gesture bar and a desktop window all disagree.
@immutable
class CompanionSafeArea {
  const CompanionSafeArea({
    required this.viewport,
    required this.min,
    required this.max,
  });

  /// Derives the area for a [viewport] under the given [padding] insets.
  ///
  /// When [compact] is set the chrome allowances are dropped, for layouts that
  /// are not the explorer stack and so have no bars to avoid.
  factory CompanionSafeArea.forViewport(
    Size viewport,
    EdgeInsets padding, {
    bool compact = false,
  }) {
    // The safe area can be wider than the toy, or taller than the viewport, on
    // a very small window. In that case there is no room to throw at all and
    // the area collapses to a point rather than inverting.
    final minX = (padding.left + kCompanionEdge).clamp(
      0.0,
      (viewport.width - kCompanionBoxWidth).clamp(0.0, double.infinity),
    );
    final minY = (compact ? padding.top : padding.top + kTopBarExtent).clamp(
      0.0,
      (viewport.height - kCompanionBoxHeight).clamp(0.0, double.infinity),
    );

    final reservedBottom = compact ? 0.0 : kBottomNavMargin + kBottomNavExtent;
    final maxX =
        (viewport.width - kCompanionBoxWidth - padding.right - kCompanionEdge)
            .clamp(minX, double.infinity);
    final maxY =
        (viewport.height -
                kCompanionBoxHeight -
                padding.bottom -
                reservedBottom -
                kCompanionEdge)
            .clamp(minY, double.infinity);

    return CompanionSafeArea(
      viewport: viewport,
      min: Offset(minX, minY),
      max: Offset(maxX, maxY),
    );
  }

  /// The whole screen the companion is laid out over.
  final Size viewport;

  /// The top-left corner of the toy, as close to the origin as it may go.
  final Offset min;

  /// The bottom-right corner of the toy, as far from the origin as it may go.
  final Offset max;

  /// This area as the throw simulation's bounds.
  ///
  /// Converted here rather than at every call site, so the widget layer keeps
  /// deciding what the usable area is and the simulation keeps knowing nothing
  /// about bars, insets or windows.
  AvatarBounds get bounds => AvatarBounds(min: min, max: max);

  /// Whether the throwable area is wide and tall enough to be worth using.
  ///
  /// A point-sized area means the window is too small for the toy to move, and
  /// a throw into it would only ever be an instant snap to a corner.
  bool get isUsable => max.dx - min.dx > 1 && max.dy - min.dy > 1;

  /// Clamps a toy position into this area, both edges this time.
  ///
  /// The controller's own clamp only knows a maximum, because the flight path
  /// it was written for started at the origin. A throw needs both: with only a
  /// maximum, a toy released near the top bar would be clamped down to it.
  Offset clamp(Offset position) => Offset(
    position.dx.clamp(min.dx, max.dx),
    position.dy.clamp(min.dy, max.dy),
  );
}
