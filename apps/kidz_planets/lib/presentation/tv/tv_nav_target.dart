import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/platform.dart';

import 'tv_providers.dart';

/// Registers a Flutter control as an interactive target beside 3D bodies.
///
/// Thin app wrapper over [TvSpatialTargetWidget]: layout + activation report
/// into the `TvExplorerController` registry, arrows bubble to the unified
/// spatial navigator, OK activates [onSelect] through the controller. It owns
/// no focus system of its own — the [TvSpatialTargetWidget] below it holds the
/// single [FocusNode] and the single focus ring, so there is exactly one owner
/// of registration, rendering, directional handling and OK activation.
class TvNavTarget extends ConsumerWidget {
  const TvNavTarget({
    super.key,
    required this.id,
    required this.onSelect,
    required this.child,
    this.control = TvChromeControl.other,
    this.autofocus = false,
    this.builder,
    this.scaleOnFocus = true,
    this.focusNode,
    this.onFocusChange,
  });

  final String id;
  final VoidCallback? onSelect;
  final Widget child;
  final TvChromeControl control;
  final bool autofocus;
  final Widget Function(BuildContext context, bool focused, Widget child)?
  builder;
  final bool scaleOnFocus;

  /// Externally owned node, kept for controls that drive their own focus
  /// handoff (the companion's avatar layer).
  final FocusNode? focusNode;

  /// Notified when focus arrives at or leaves this target.
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tvExplorerControllerProvider.notifier);
    return TvSpatialTargetWidget(
      id: id,
      onSelect: onSelect,
      control: control,
      autofocus: autofocus,
      builder: builder,
      scaleOnFocus: scaleOnFocus,
      focusNode: focusNode,
      onFocusChange: onFocusChange,
      onTarget: notifier.registerTarget,
      onUnregister: notifier.unregisterTarget,
      child: child,
    );
  }
}
