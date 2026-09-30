import 'dart:ui' show Offset;

/// The shape a companion takes for the moment after it hits something.
///
/// Shared by the 3D body and the 2D face painted over its window, because the
/// two have to be deformed by exactly the same amount. If they were not, a
/// squashing body with an undeformed face would look like the face was floating
/// in front of the toy rather than sitting in its window, which is a mistake
/// that is very obvious at full size and invisible in a screenshot.
abstract final class AvatarSquash {
  /// The horizontal and vertical scale for a [scale] of `1` meaning undeformed.
  ///
  /// The horizontal stretch is what makes it read as a squash rather than as a
  /// shrunken toy: anything pressed between two things gets wider as well as
  /// shorter, and a body that only got smaller would read as being further away
  /// rather than as being hit.
  ///
  /// The stretch is deliberately not the reciprocal of the vertical scale.
  /// Volume would be preserved, but a near-cubic body squashed to 0.86 would
  /// then stretch to 1.16 tall, which pops out of its box and looks like an
  /// error rather than like an impact.
  static Offset axes(double scale) {
    final horizontal = 1 + (1 - scale) * _widening;
    return Offset(horizontal, scale);
  }

  /// How much wider a squashed body gets, per unit of height it loses.
  static const double _widening = 0.7;
}
