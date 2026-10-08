import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which class of device the app is running on.
///
/// The rest of the application consumes this instead of reaching for Android
/// APIs directly, so there is exactly one place that knows how "is this a TV"
/// is decided.
enum DeviceFormFactor {
  /// A handset driven by touch.
  mobile,

  /// A large touch device. Same interaction model as mobile, roomier layout.
  tablet,

  /// Android TV / Google TV: D-pad remote, focus navigation, 10-foot UI.
  television,
}

extension DeviceFormFactorX on DeviceFormFactor {
  /// True only for [DeviceFormFactor.television].
  bool get isTelevision => this == DeviceFormFactor.television;

  /// Whether the primary interaction model is touch.
  bool get isTouchFirst => !isTelevision;
}

/// Pure classifier, so the breakpoints are unit-testable without a device.
///
/// [isTelevision] always wins: a TV reporting a small window is still a TV.
/// Otherwise the Material 600dp shortest-side breakpoint separates tablets
/// from phones.
DeviceFormFactor classifyFormFactor({
  required Size windowSize,
  required bool isTelevision,
}) {
  if (isTelevision) return DeviceFormFactor.television;
  if (windowSize.shortestSide >= 600) return DeviceFormFactor.tablet;
  return DeviceFormFactor.mobile;
}

/// Resolves the form factor for [context]'s window.
///
/// Call this once per build where the layout branches (the Explorer shell),
/// not inside every leaf widget.
DeviceFormFactor formFactorOf(
  BuildContext context, {
  required bool isTelevision,
}) {
  return classifyFormFactor(
    windowSize: MediaQuery.sizeOf(context),
    isTelevision: isTelevision,
  );
}

/// Answers "is this an Android TV / Google TV device" over a platform channel.
///
/// The native side reads `UiModeManager.currentModeType` (see `MainActivity`);
/// anything missing, failing or timing out means "not a TV", so phones,
/// desktops, web and tests all safely resolve to false.
abstract final class TvEnvironment {
  static const MethodChannel _channel = MethodChannel('kidz_planets/tv');

  static Future<bool> isTelevision() async {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid) return false;
    } on UnsupportedError {
      return false;
    }
    try {
      final result = await _channel
          .invokeMethod<bool>('isTelevision')
          .timeout(const Duration(seconds: 2));
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// Raw platform answer, resolved once per process.
final televisionModeProvider = FutureProvider<bool>((ref) async {
  return TvEnvironment.isTelevision();
});

/// Test/demo escape hatch: when non-null it wins over the platform answer.
///
/// Production code never sets this; widget tests set it to true to exercise
/// the TV layout without a TV.
final tvModeOverrideProvider = StateProvider<bool?>((ref) => null);

/// The single boolean the UI branches on.
///
/// Override first, detected value second, `false` while still loading: the
/// phone layout is the safe default until the TV answer arrives.
final isTelevisionProvider = Provider<bool>((ref) {
  final override = ref.watch(tvModeOverrideProvider);
  if (override != null) return override;
  return ref.watch(televisionModeProvider).valueOrNull ?? false;
});
