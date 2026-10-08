import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Proportional scaling for the Kidz Planets chrome: one uniform factor from
/// the actual viewport, applied to every dimension of a composition.
///
/// Reference design, scaled to the available viewport:
///
/// ```text
/// reference design  →  available viewport  →  scale factor  →  scaled UI
/// ```
///
/// The factor is *uniform* (a single number for widths, heights, radii and
/// type), so aspect ratios survive scaling: circles stay circles, planet
/// chips keep their proportions, buttons never stretch. Fitting is the
/// layout's job (flexible columns, two-column landscape, scrolling panels) —
/// never a second per-axis factor.
///
/// Two references, one class:
///
/// - [DesignScale.sharedOf] for chrome shared by phones, tablets and TVs,
///   authored at phone sizes. Its factor is the viewport-diagonal ratio
///   against [phoneReference]: orientation-invariant (a landscape phone
///   keeps factor 1.0 instead of collapsing), clamped so tiny phones stay
///   usable and huge screens stay composed. On the reference phone the
///   factor is exactly 1.0, so the existing mobile pixels are preserved.
/// - [DesignScale.tvOf] for TV-only chrome authored at [tvReference]
///   (1920 × 1080). Never rendered on phones, so no dual expression exists.
///
/// Widgets answer "how much space do I have" through these factories — never
/// "which device is this" through per-widget size ternaries.
class DesignScale {
  const DesignScale._(this.factor);

  /// Exact-factor construction for tests.
  @visibleForTesting
  const DesignScale.test(this.factor);

  /// Scale for shared chrome from the ambient viewport.
  factory DesignScale.sharedOf(BuildContext context) =>
      DesignScale._(sharedFactorFor(MediaQuery.sizeOf(context)));

  /// Scale for TV-only chrome (authored at [tvReference]) from the viewport.
  factory DesignScale.tvOf(BuildContext context) =>
      DesignScale._(tvFactorFor(MediaQuery.sizeOf(context)));

  /// Phone portrait the app was authored for: factor 1.0 here reproduces
  /// today's pixels exactly.
  static const Size phoneReference = Size(390, 844);

  /// Landscape baseline TV-only chrome is authored against.
  static const Size tvReference = Size(1920, 1080);

  /// Bounds of the shared factor: below is unreadable, above is
  /// disproportionate (fitting caps it; the composition is unchanged).
  static const double minSharedFactor = 0.85;
  static const double maxSharedFactor = 1.7;

  /// Pure factor function, so the breakpoints are unit-testable.
  ///
  /// Diagonal ratio, clamped: 390×844 → 1.0, landscape phones stay 1.0,
  /// tablets land mid-range, 720p TVs ≈ 1.58, 1080p+ TVs cap at 1.7.
  static double sharedFactorFor(Size viewport) {
    final diag = math.sqrt(
      viewport.width * viewport.width + viewport.height * viewport.height,
    );
    // Diagonal of phoneReference (390×844); a local, not a const, because
    // math.sqrt is not compile-time evaluable.
    final ref = math.sqrt(390 * 390 + 844 * 844);
    return (diag / ref).clamp(minSharedFactor, maxSharedFactor);
  }

  /// Pure factor function for TV-only chrome: 1080p → 1.0, 720p → 0.667,
  /// scaling linearly with the viewport in both axes at once.
  static double tvFactorFor(Size viewport) => math.min(
    viewport.width / tvReference.width,
    viewport.height / tvReference.height,
  );

  /// The uniform scale applied to every dimension.
  final double factor;

  /// Scales a length (width, height, padding, icon size, radius).
  double px(double value) => value * factor;

  /// Scales type proportionally to the surrounding UI.
  ///
  /// [min] is an intentional readability floor (e.g. a primary action that
  /// must stay legible at 720p), not a per-device guess: the size still
  /// derives from the viewport everywhere above the floor.
  double font(double value, {double? min}) {
    final scaled = value * factor;
    return min == null ? scaled : math.max(scaled, min);
  }

  /// Scales a corner radius with the shape it rounds.
  double radius(double value) => value * factor;

  /// Scaled symmetric insets.
  EdgeInsets insets({double horizontal = 0, double vertical = 0}) =>
      EdgeInsets.symmetric(horizontal: px(horizontal), vertical: px(vertical));

  /// Scaled all-sides insets.
  EdgeInsets all(double value) => EdgeInsets.all(px(value));
}
