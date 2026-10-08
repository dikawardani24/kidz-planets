import 'package:flutter/widgets.dart';

import 'tv_focus.dart';
import 'tv_spatial_nav.dart';

/// Publishes a feature-package control into the app's TV spatial registry.
///
/// The app owns the registry (dependency rules forbid features importing the
/// app), so this widget reports layout + activation through [onTarget] and
/// [onUnregister] callbacks the app wires to its `TvExplorerController`.
/// Renders [child] with the shared TV focus treatment; arrows bubble to the
/// unified spatial navigator via `consumeDirectionalKeys: false`, OK still
/// activates through [onSelect].
class TvSpatialTargetWidget extends StatefulWidget {
  const TvSpatialTargetWidget({
    super.key,
    required this.id,
    required this.onSelect,
    required this.child,
    required this.onTarget,
    required this.onUnregister,
    this.control = TvChromeControl.other,
    this.autofocus = false,
    this.builder,
    this.scaleOnFocus = true,
  });

  final String id;
  final VoidCallback? onSelect;
  final Widget child;
  final ValueChanged<TvSpatialTarget> onTarget;
  final ValueChanged<String> onUnregister;
  final TvChromeControl control;
  final bool autofocus;
  final Widget Function(BuildContext context, bool focused, Widget child)?
  builder;
  final bool scaleOnFocus;

  @override
  State<TvSpatialTargetWidget> createState() => _TvSpatialTargetWidgetState();
}

class _TvSpatialTargetWidgetState extends State<TvSpatialTargetWidget> {
  final GlobalKey _key = GlobalKey();
  FocusNode? _ownedNode;

  FocusNode get _node => _ownedNode ??= FocusNode();

  @override
  void dispose() {
    try {
      widget.onUnregister(widget.id);
    } catch (_) {}
    _ownedNode?.dispose();
    super.dispose();
  }

  void _report() {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    try {
      widget.onTarget(
        TvSpatialTarget(
          id: widget.id,
          control: widget.control,
          center: rect.center,
          focusNode: _node,
          onActivate: widget.onSelect,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return KeyedSubtree(
      key: _key,
      child: TvFocusable(
        focusNode: _node,
        autofocus: widget.autofocus,
        onSelect: widget.onSelect,
        builder: widget.builder,
        scaleOnFocus: widget.scaleOnFocus,
        consumeDirectionalKeys: false,
        child: widget.child,
      ),
    );
  }
}
