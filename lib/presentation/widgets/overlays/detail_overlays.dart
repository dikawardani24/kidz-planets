import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/providers.dart';
import '../../theme/app_theme.dart';

/// Swipe-to-spin / pinch-to-zoom hint banner (auto-hides after 4s like the
/// prototype's `#detail-spin-hint`).
class DetailSpinHint extends ConsumerWidget {
  const DetailSpinHint({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    if (!ui.hasSelection) return const SizedBox.shrink();
    return const Positioned(
      top: 74,
      left: 0,
      right: 0,
      child: IgnorePointer(child: Center(child: _HintPill())),
    );
  }
}

class _HintPill extends StatefulWidget {
  const _HintPill();
  @override
  State<_HintPill> createState() => _HintPillState();
}

class _HintPillState extends State<_HintPill> {
  bool _visible = true;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.4)),
        ),
        child: const Text('👆 Swipe to spin • 🤏 Pinch or +/- to zoom',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFFDE68A))),
      ),
    );
  }
}

/// Compact pill shown when the facts dialog is hidden (Play Mode).
/// Prototype parity with `#detail-minimized-pill`.
class DetailMinimizedPill extends ConsumerWidget {
  const DetailMinimizedPill({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    if (!ui.hasSelection || ui.isDetailCardVisible) return const SizedBox.shrink();
    final notifier = ref.read(explorerControllerProvider.notifier);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 118,
      child: Center(
        child: GestureDetector(
          onTap: notifier.toggleDetailCard,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.space800.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.visibility, size: 14, color: AppTheme.accentAmber),
              const SizedBox(width: 6),
              Text('${_planetEmoji(ui.selectedPlanetId)} ${ui.selectedPlanetId ?? ''} Facts',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
            ]),
          ),
        ),
      ),
    );
  }

  String _planetEmoji(String? id) {
    switch (id) {
      case 'sun':
        return '☀️';
      case 'saturn':
        return '🪐';
      default:
        return '🌍';
    }
  }
}
