/// TEMPORARY TV INPUT PROBE — DO NOT BUILD ON TOP OF THIS.
///
/// Purpose: prove the most basic remote pipeline on real hardware before any
/// further TV navigation work:
///
/// ```text
/// Android TV Remote → Flutter KeyEvent → Focus → D-pad → widget → OK → callback
/// ```
///
/// Shows two focusable buttons (TEST A / TEST B) plus live readouts of the
/// last key, focus state and activations. Rendered only on TV, above the
/// scene and below the companion. Delete this file (and its single usage in
/// `ExplorerScreen`) once the hardware report below is filled in:
///
/// ```text
/// REMOTE INPUT: Left / Right / Up / Down / OK / Back: PASS/FAIL each
/// FOCUS: Explorer focus / TEST A focus / TEST B focus: PASS/FAIL each
/// NAVIGATION: TEST A → RIGHT → TEST B: PASS/FAIL
/// ACTIVATION: TEST B → OK → callback: PASS/FAIL
/// ```
library;

import 'package:flutter/material.dart';

import 'package:core/platform.dart';

/// Temporary probe overlay: two buttons plus raw input/focus readouts.
class TvInputProbe extends StatefulWidget {
  const TvInputProbe({super.key});

  @override
  State<TvInputProbe> createState() => _TvInputProbeState();
}

class _TvInputProbeState extends State<TvInputProbe> {
  String _selected = 'TEST A';
  String _lastKey = '—';
  String _lastKeyEvent = '—';
  String _lastAction = '—';
  String _focusLabel = '—';

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_refreshFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFocus());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_refreshFocus);
    super.dispose();
  }

  void _refreshFocus() {
    if (!mounted) return;
    final primary = FocusManager.instance.primaryFocus;
    final label = primary == null
        ? 'NO (nothing focused)'
        : 'YES (${primary.debugLabel ?? primary.runtimeType})';
    if (label != _focusLabel) setState(() => _focusLabel = label);
  }

  KeyEventResult _sniff(FocusNode node, KeyEvent event) {
    final label = event.logicalKey.keyLabel.isEmpty
        ? event.logicalKey.debugName ?? '?'
        : event.logicalKey.keyLabel;
    setState(() {
      _lastKey = label;
      _lastKeyEvent = event.runtimeType.toString();
    });
    // ignore: avoid_print
    debugPrint('TvProbe: key=$label event=${event.runtimeType}');
    // Never consume: the normal pipeline must behave exactly as without us.
    return KeyEventResult.ignored;
  }

  void _activate(String name) {
    setState(() {
      _selected = name;
      _lastAction = '$name ACTIVATED';
    });
    // ignore: avoid_print
    debugPrint('TvProbe: action=$name ACTIVATED');
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Focus(
        onKeyEvent: _sniff,
        child: Center(
          child: Container(
            margin: const EdgeInsets.only(top: 96),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red, width: 4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TV INPUT PROBE (temporary)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProbeButton(
                      label: 'TEST A',
                      autofocus: true,
                      selected: _selected == 'TEST A',
                      onSelect: () => _activate('TEST A'),
                    ),
                    const SizedBox(width: 16),
                    _ProbeButton(
                      label: 'TEST B',
                      selected: _selected == 'TEST B',
                      onSelect: () => _activate('TEST B'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _line('Selected: $_selected'),
                _line('Last Key: $_lastKey'),
                _line('Last Key Event: $_lastKeyEvent'),
                _line('Last Action: $_lastAction'),
                _line('Primary Focus: $_focusLabel'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

class _ProbeButton extends StatelessWidget {
  const _ProbeButton({
    required this.label,
    required this.selected,
    required this.onSelect,
    this.autofocus = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      scaleOnFocus: false,
      builder: (_, focused, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade800 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focused ? Colors.yellow : Colors.white,
            width: focused ? 8 : 2,
          ),
          boxShadow: focused
              ? [
                  const BoxShadow(
                    color: Colors.yellow,
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
      child: const SizedBox.shrink(),
    );
  }
}
