import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/providers.dart';
import '../../../domain/entities/planet.dart';
import '../../theme/app_theme.dart';

class PlanetDetailSheet extends ConsumerWidget {
  const PlanetDetailSheet({super.key, required this.planet});
  final Planet planet;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    return Container(
      decoration: BoxDecoration(color: AppTheme.space800.withValues(alpha: 0.94), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.16), width: 1.2))),
      child: SafeArea(top: false, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(planet.colorValue), Color(planet.colorValue).withValues(alpha: 0.5)]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            boxShadow: [BoxShadow(color: Color(planet.colorValue).withValues(alpha: 0.5), blurRadius: 18)])),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(planet.name, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0)),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(999)),
              child: Text(planet.tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70))),
          ])),
          GestureDetector(onTap: notifier.closeDetail, child: Container(width: 34, height: 34, alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
            child: const Icon(Icons.close, size: 17, color: Colors.white70))),
        ]),
        const SizedBox(height: 12),
        Text(planet.fact, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Colors.white)),
        const SizedBox(height: 12),
        Row(children: [
          _FactChip(icon: Icons.straighten, title: 'Diameter', value: planet.diameter),
          const SizedBox(width: 8),
          _FactChip(icon: Icons.thermostat, title: 'Temp', value: planet.temperature),
          const SizedBox(width: 8),
          _FactChip(icon: Icons.schedule, title: 'Day', value: planet.dayLength),
        ]),
        const SizedBox(height: 12),
        for (final h in planet.hotspots)
          Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 36, height: 36, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppTheme.accentAmber.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.star, size: 18, color: AppTheme.accentAmber)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text(h.description, style: const TextStyle(fontSize: 12, height: 1.45, color: Colors.white70)),
              ])),
            ])),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.touch_app, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Expanded(child: Text('Drag to spin • Pinch to zoom • Zoom ${ui.detailZoom.toStringAsFixed(1)}x',
            style: const TextStyle(fontSize: 11, color: Colors.white38))),
        ]),
      ]))));
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.title, required this.value});
  final IconData icon; final String title; final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Column(children: [
        Icon(icon, size: 15, color: AppTheme.accentSky),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white38)),
        const SizedBox(height: 1),
        Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
      ])));
  }
}
