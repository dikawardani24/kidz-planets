/// How much of the screen the app's own chrome covers.
///
/// The top bar and the bottom nav are drawn by the planets package, but the
/// companion avatar shares their stack and has to stay clear of both. If the
/// avatar asked planets for these numbers it would depend on a feature package,
/// so the measurements live here instead and both sides read them from one
/// place. That is what stops a change to the nav's padding from silently
/// leaving the avatar parked underneath it.
library;

import 'package:flutter/widgets.dart' show EdgeInsets;

/// The top bar's own height, excluding the status-bar inset above it.
const double kTopBarExtent = 50;

/// The gap between the bottom of the nav and the bottom of the screen.
const double kBottomNavMargin = 18;

/// Y offset for banners that must sit below the top bar, so they stay clear of
/// it on devices with a status bar or notch.
///
/// Takes the resolved inset rather than the context so that callers cannot
/// disagree about which padding applies.
double bannerTopFor(EdgeInsets padding) => padding.top + kTopBarExtent;

/// Vertical padding inside the nav's glass surface.
const double kNavVerticalPadding = 7;

/// Vertical padding inside one nav item.
const double kNavItemVerticalPadding = 10;

/// The icon size a nav item reserves height for.
const double kNavItemIconSize = 18;

/// The border width of a glass surface, which the nav includes in its height.
const double kGlassBorderWidth = 1;

/// The nav's own height, excluding [kBottomNavMargin].
///
/// Derived from the nav's own numbers rather than written as a single literal,
/// so the reserved space cannot drift from the widget that occupies it.
///
/// Assumes the default text scale. A larger one makes the labels taller than
/// the icons and the nav grows; that would need the height measured at runtime
/// rather than reserved.
const double kBottomNavExtent =
    kNavVerticalPadding * 2 +
    kNavItemVerticalPadding * 2 +
    kNavItemIconSize +
    kGlassBorderWidth * 2;
