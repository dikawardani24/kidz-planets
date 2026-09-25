import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/providers.dart';
import '../../theme/app_theme.dart';

class PlaygroundPanel extends ConsumerWidget {
  const PlaygroundPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);

    return Container(
      decoration: AppTheme.glassPanel,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.science_rounded, color: AppTheme.accentAmber, size: 19),
                SizedBox(width: 7),
                Text('Space Playground', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
              SizedBox(height: 3),
              Text('Physics & orbital experiments in real 3D!', style: TextStyle(fontSize: 11, color: Colors.white60)),
            ])),
            GestureDetector(
              onTap: () {
                notifier.setSpeed(1.0);
                if (!ui.showOrbits) notifier.toggleOrbits();
                if (!ui.showLabels) notifier.toggleLabels();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: AppTheme.glassPill,
                child: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentAmber.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.35)),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🔥', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sandbox Ready!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFFFE7A3))),
                SizedBox(height: 2),
                Text('Run interactive NASA 3D experiments below.', style: TextStyle(fontSize: 10.5, color: Colors.white70)),
              ])),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.space800.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.speed_rounded, color: AppTheme.accentSky, size: 16),
                const SizedBox(width: 6),
                const Text('Orbit Speed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
                const Spacer(),
                Text(ui.speed.toStringAsFixed(1) + 'x', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.accentAmber)),
              ]),
              Slider(
                value: ui.speed.clamp(0, 3),
                min: 0, max: 3, divisions: 6,
                activeColor: AppTheme.accentAmber,
                inactiveColor: Colors.white24,
                onChanged: notifier.setSpeed,
              ),
              Row(children: [
                Expanded(child: _Toggle(label: 'Orbits', active: ui.showOrbits, onTap: notifier.toggleOrbits)),
                const SizedBox(width: 8),
                Expanded(child: _Toggle(label: 'Labels', active: ui.showLabels, onTap: notifier.toggleLabels)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          const Row(children: [
            Icon(Icons.auto_awesome, color: Color(0xFFA78BFA), size: 15),
            SizedBox(width: 6),
            Text('Real NASA 3D Experiments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70)),
          ]),
          const SizedBox(height: 7),
          _Experiment(icon: '☀️', title: 'Inspect Blazing Sun', subtitle: 'Examine solar flares & dynamic corona', onTap: () => notifier.runExperiment('sun')),
          _Experiment(icon: '🔥', title: 'Move Earth Closer', subtitle: 'See extreme thermal radiation', onTap: () => notifier.runExperiment('earth')),
          _Experiment(icon: '🪐', title: 'Inspect Saturn Rings', subtitle: 'Cassini Division & 26.7° axial tilt', onTap: () => notifier.runExperiment('saturn')),
          _Experiment(icon: '🌍', title: 'Explore Earth', subtitle: 'Spin and inspect our home planet', onTap: () => notifier.runExperiment('earth-explore')),
        ]),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: active ? AppTheme.accentViolet.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(active ? Icons.check_circle : Icons.circle_outlined, size: 13, color: active ? AppTheme.accentAmber : Colors.white38),
        const SizedBox(width: 5),
        Text(label + ': ' + (active ? 'On' : 'Off'), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    ),
  );
}

class _Experiment extends StatelessWidget {
  const _Experiment({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.space800.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36, alignment: Alignment.center,
          decoration: BoxDecoration(color: AppTheme.accentAmber.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Text(icon, style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 9.5, color: Colors.white60)),
        ])),
        const Icon(Icons.chevron_right_rounded, size: 17, color: Colors.white38),
      ]),
    ),
  );
}
