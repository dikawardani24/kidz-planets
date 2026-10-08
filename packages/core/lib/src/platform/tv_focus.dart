import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:core/theme.dart';

/// Reusable D-pad focus primitives for the TV presentation layer.
///
/// Mobile widgets keep their `GestureDetector`s untouched; TVchrome wraps its
/// actionable controls in [TvFocusable] so every remote interaction flows
/// through one focus treatment ([tvFocusDecoration]) instead of each screen
/// inventing its own ring.
///
/// Key handling relies on the framework defaults: `FocusableActionDetector`
/// already maps `ActivateIntent` (Enter, Space, game-button-A and the D-pad
/// `select` key) to [onSelect], and `Navigator` already pops on BACK, so there
/// is no per-screen key-event plumbing.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.onSelect,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.builder,
    this.scaleOnFocus = true,
    this.consumeDirectionalKeys = true,
  });

  /// What happens on SELECT/OK (remote) or tap (touch/mouse fallback).
  final VoidCallback? onSelect;

  /// The content, drawn with the Planetaria focus ring when focused.
  final Widget child;

  /// External node for custom traversal order. Owned by the caller then.
  final FocusNode? focusNode;

  /// Whether this grabs focus when the scope first appears.
  final bool autofocus;

  /// Notified when focus arrives or leaves (e.g. to yield remote input).
  final ValueChanged<bool>? onFocusChange;

  /// Optional custom focused rendering; defaults to [tvFocusFrame].
  final Widget Function(BuildContext context, bool focused, Widget child)?
  builder;

  /// Slightly grows the control while focused. Off for full-bleed cards.
  final bool scaleOnFocus;

  /// When false, arrow keys bubble to the Explorer spatial navigator instead
  /// of Flutter's [DirectionalFocusIntent] traversal. OK/Activate still works.
  ///
  /// Explorer chrome and detail controls set this false so widgets and 3D
  /// bodies share one D-pad model. Panels/dialogs outside that model keep the
  /// default (true).
  final bool consumeDirectionalKeys;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  FocusNode? _ownedNode;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void dispose() {
    _ownedNode?.dispose();
    super.dispose();
  }

  void _invoke() => widget.onSelect?.call();

  @override
  Widget build(BuildContext context) {
    final frame =
        widget.builder ??
        (_, focused, child) => tvFocusFrame(
          focused: focused,
          scale: widget.scaleOnFocus,
          child: child,
        );
    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      enabled: widget.onSelect != null,
      onFocusChange: (focused) {
        if (mounted && focused != _focused) setState(() => _focused = focused);
        widget.onFocusChange?.call(focused);
      },
      shortcuts: widget.consumeDirectionalKeys
          ? const {
              SingleActivator(LogicalKeyboardKey.arrowLeft):
                  DirectionalFocusIntent(TraversalDirection.left),
              SingleActivator(LogicalKeyboardKey.arrowRight):
                  DirectionalFocusIntent(TraversalDirection.right),
              SingleActivator(LogicalKeyboardKey.arrowUp):
                  DirectionalFocusIntent(TraversalDirection.up),
              SingleActivator(LogicalKeyboardKey.arrowDown):
                  DirectionalFocusIntent(TraversalDirection.down),
            }
          : const <ShortcutActivator, Intent>{},
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            _invoke();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: _invoke,
        child: Builder(
          builder: (context) => frame(context, _focused, widget.child),
        ),
      ),
    );
  }
}

/// Groups TV controls into one traversal scope with a sensible first focus.
///
/// Wrap each TV screen/panel/dialog in this so focus can never be lost: the
/// scope owns the traversal policy and [autofocusFirst] guarantees an initial
/// focus.
///
/// Pass [scopeNode] when the rest of the app needs to find this scope again
/// (e.g. the BACK shuttle returning focus to the controller cluster): an
/// external node is owned by the caller and must outlive this widget — a
/// provider is the usual home.
class TvFocusContainer extends StatelessWidget {
  const TvFocusContainer({
    super.key,
    required this.child,
    this.autofocusFirst = true,
    this.scopeNode,
  });

  final Widget child;
  final bool autofocusFirst;
  final FocusScopeNode? scopeNode;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: FocusScope(
        node: scopeNode,
        autofocus: autofocusFirst,
        child: child,
      ),
    );
  }
}

/// The consistent Planetaria TV focus treatment.
///
/// Focused: amber ring + soft amber glow + slight scale, on the existing
/// `space700` glass language. Unfocused: the child untouched, so screens do
/// not pay for a decoration they are not showing.
Widget tvFocusFrame({
  required bool focused,
  required Widget child,
  bool scale = true,
}) {
  return AnimatedScale(
    scale: focused && scale ? 1.04 : 1.0,
    duration: const Duration(milliseconds: 140),
    curve: Curves.easeOutCubic,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      decoration: focused
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accentAmber, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentAmber.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            )
          : const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
      child: child,
    ),
  );
}

/// Border color a TV card should draw for its own internal highlight.
///
/// For cards that bake the ring into a custom layout instead of using
/// [tvFocusFrame] (e.g. planet cards with per-planet accent colors).
Color tvCardBorder({required bool focused}) {
  return focused ? AppTheme.accentAmber : Colors.white.withValues(alpha: 0.16);
}
