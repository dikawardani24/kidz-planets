import 'package:flutter/rendering.dart';
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
///
/// Registration is lifecycle-safe and usability-gated, which is what makes
/// "every *visible, actionable* control is reachable" true instead of
/// aspirational:
///
/// - a target registers only once it is laid out with a real, non-empty box;
/// - [onSelect] == null (disabled) never registers;
/// - an ignoring `IgnorePointer` ancestor or a fully transparent opacity
///   ancestor (the fading controller chrome, for example) unregisters it —
///   invisible controls drop out of the navigation graph;
/// - the id is re-reported every frame, so screen-space centers track layout
///   movement (scroll, rotation, sibling animation) without a rebuild;
/// - dispose unregisters the id that was actually last registered, so a widget
///   whose id changed across rebuilds cannot leak a stale entry.
///
/// One focus owner: this widget holds the single [FocusNode] (external via
/// [focusNode] or owned) and hands it to the one [TvFocusable] below it. There
/// is no second focus system between the registry and the button.
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
    this.focusNode,
    this.onFocusChange,
    this.participates = true,
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

  /// Externally owned node (the companion keeps its own for its layer handoff).
  /// Owned by the caller then; this widget only reads and reports it.
  final FocusNode? focusNode;

  /// Notified when focus arrives at or leaves this target.
  final ValueChanged<bool>? onFocusChange;

  /// Whether this control takes part in TV D-pad navigation right now.
  ///
  /// When false the target leaves (or never joins) the spatial registry and
  /// renders unfocusable, while touch and mouse taps keep working unchanged.
  /// The Explore screen drives this from its Planet/Menu focus mode: chrome
  /// controls sit out Planet Mode and rejoin Menu Mode, except the single
  /// mode-toggle button which participates in both. Defaults to true so
  /// standalone hosts keep today's behavior without passing anything.
  final bool participates;

  @override
  State<TvSpatialTargetWidget> createState() => _TvSpatialTargetWidgetState();
}

class _TvSpatialTargetWidgetState extends State<TvSpatialTargetWidget> {
  final GlobalKey _key = GlobalKey();
  FocusNode? _ownedNode;
  bool _disposed = false;

  /// The id currently present in the registry, if any. Dispose and id changes
  /// unregister *this*, never a freshly assigned [TvSpatialTargetWidget.id].
  String? _registeredId;

  FocusNode get _node =>
      widget.focusNode ??
      (_ownedNode ??= FocusNode(debugLabel: 'tvTarget:${widget.id}'));

  @override
  void initState() {
    super.initState();
    // Re-report on every frame while mounted: positions and usability change
    // through layout and ancestor state (fade, scroll, rotation) without this
    // widget rebuilding, and a stale center would aim the D-pad at nothing.
    // The loop only runs when frames already happen — it schedules none.
    _scheduleReport();
  }

  @override
  void dispose() {
    _disposed = true;
    _unregister();
    _ownedNode?.dispose();
    super.dispose();
  }

  void _scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      _report();
      _scheduleReport();
    });
  }

  void _unregister() {
    final id = _registeredId;
    if (id == null) return;
    _registeredId = null;
    try {
      widget.onUnregister(id);
    } catch (_) {}
  }

  /// Whether the control may participate in TV navigation right now:
  /// laid out with a real box, actionable, and not hidden by an ancestor.
  bool _usable(RenderBox box) {
    if (widget.onSelect == null) return false;
    if (!box.hasSize || box.size.isEmpty) return false;
    RenderObject? node = box;
    while (node != null) {
      if (node is RenderIgnorePointer && node.ignoring) return false;
      if (node is RenderOpacity && node.opacity <= 0.0) return false;
      if (node is RenderAnimatedOpacity && node.opacity.value <= 0.0) {
        return false;
      }
      node = node.parent;
    }
    return true;
  }

  void _report() {
    if (!mounted) return;
    if (!widget.participates) {
      _unregister();
      return;
    }
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !_usable(box)) {
      _unregister();
      return;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    // An id change on the same state must not leave the old id behind.
    if (_registeredId != null && _registeredId != widget.id) {
      _unregister();
    }
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
      _registeredId = widget.id;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: TvFocusable(
        focusNode: _node,
        autofocus: widget.autofocus,
        onSelect: widget.onSelect,
        onFocusChange: widget.onFocusChange,
        builder: widget.builder,
        scaleOnFocus: widget.scaleOnFocus,
        focusable: widget.participates,
        consumeDirectionalKeys: false,
        child: widget.child,
      ),
    );
  }
}
