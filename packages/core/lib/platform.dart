/// Device-class abstraction shared by every package.
///
/// Features import this (via `core`) instead of checking Android APIs or
/// scattering `if (isTv)` branches: [DeviceFormFactor] names the device class,
/// [isTelevisionProvider] is the single boolean the UI branches on, and
/// [TvFocusable]/[TvFocusContainer]/[tvFocusFrame] are the reusable D-pad
/// focus primitives every TV screen is built from.
library;

export 'src/platform/device_form_factor.dart';
export 'src/platform/tv_explorer_actions.dart';
export 'src/platform/tv_focus.dart';
export 'src/platform/tv_spatial_nav.dart';
export 'src/platform/tv_spatial_target.dart';

