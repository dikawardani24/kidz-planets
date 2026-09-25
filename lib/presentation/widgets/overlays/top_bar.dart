import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/providers.dart';
import '../../theme/app_theme.dart';

class ExplorerTopBar extends ConsumerWidget {
  const ExplorerTopBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.black.withValues(alpha: 0.72), Colors.transparent])),
      child: SafeArea(bottom: false, child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF97316)]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x66FBBF24), blurRadius: 14, spreadRadius: 1)]),
          alignment: Alignment.center, child: const Text('P', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white))),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Space Explorer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, height: 1.0)),
          SizedBox(height: 2),
          Text('Tap a planet to explore!', style: TextStyle(fontSize: 12, color: Colors.white70)),
        ])),
        _RoundIconButton(icon: ui.running ? Icons.pause : Icons.play_arrow,
          onTap: () => ref.read(explorerControllerProvider.notifier).toggleRunning()),
      ])),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: AppTheme.space800.withValues(alpha: 0.85), shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
      child: Icon(icon, color: Colors.white, size: 20)));
  }
}

class ExplorerControlPills extends ConsumerWidget {
  const ExplorerControlPills({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    return Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
      _SpeedPill(speed: ui.speed, onChanged: notifier.setSpeed),
      _TogglePill(label: 'Orbits', active: ui.showOrbits, onTap: notifier.toggleOrbits),
      _TogglePill(label: 'Labels', active: ui.showLabels, onTap: notifier.toggleLabels),
    ]);
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({required this.label, required this.active, required this.onTap});
  final String label; final bool active; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: active ? AppTheme.accentViolet.withValues(alpha: 0.9) : AppTheme.space700.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
      child: Text('$label ${active ? "ON" : "OFF"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))));
  }
}

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({required this.speed, required this.onChanged});
  final double speed; final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.space700.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.rocket_launch, size: 14, color: AppTheme.accentAmber),
        SizedBox(width: 110, child: Slider(value: speed, min: 0, max: 3, divisions: 6,
          activeColor: AppTheme.accentAmber, inactiveColor: Colors.white24, onChanged: onChanged)),
        Text('${speed.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      ]));
  }
}
