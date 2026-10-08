import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/platform.dart';

import 'tv_providers.dart';

/// Registers a Flutter control as an interactive target beside 3D bodies.
///
/// Thin app wrapper over [TvSpatialTargetWidget]: layout + activation report
/// into the `TvExplorerController` registry, arrows bubble to the unified
/// spatial navigator, OK activates [onSelect].
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
  });

  final String id;
  final VoidCallback? onSelect;
  final Widget child;
  final TvChromeControl control;
  final bool autofocus;
  final Widget Function(BuildContext context, bool focused, Widget child)?
  builder;
  final bool scaleOnFocus;

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
      onTarget: notifier.registerTarget,
      onUnregister: notifier.unregisterTarget,
      child: child,
    );
  }
}
