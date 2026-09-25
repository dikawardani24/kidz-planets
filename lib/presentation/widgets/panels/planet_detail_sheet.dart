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
    if (!ui.detailCardVisible) {
      return _MinimizedDetailPill(planet: planet, onTap: notifier.toggleDetailCard);
    }
    return AppTheme.glass(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(planet.isSun ? '☀️' : planet.id == 'saturn' ? '🪐' : '🌍', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ui.detailTitleOverride ?? planet.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2), Text(planet.tag, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFA5B4FC))),
          ])),
          GestureDetector(onTap: notifier.toggleDetailCard, child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.gamepad, size: 12, color: AppTheme.accentAmber), SizedBox(width: 4), Text('Play Mode', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFFFE7A3)))]))),
          const SizedBox(width: 5),
          GestureDetector(onTap: notifier.closeDetail, child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.all(7), child: const Icon(Icons.close, size: 14, color: Color(0xFFC7D2FE)))),
        ]),
        const SizedBox(height: 9),
        Text(ui.detailDescriptionOverride ?? planet.fact, style: const TextStyle(fontSize: 10.5, height: 1.45, color: Color(0xFFE0E7FF))),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(child: _Stat(icon: Icons.straighten, title: 'Diameter', value: planet.diameter)),
          const SizedBox(width: 7), Expanded(child: _Stat(icon: Icons.thermostat, title: 'Avg Temp', value: planet.temperature)),
        ]),
        const SizedBox(height: 9),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final h in planet.hotspots)
            GestureDetector(onTap: () => notifier.showHotspot(h), child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Text(h.icon, style: const TextStyle(fontSize: 11)), const SizedBox(width: 4), Text(h.title, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white))]))),
        ]),
        const SizedBox(height: 8),
        Text('👆 Drag to spin  •  🤏 Pinch to zoom  •  Zoom ' + ui.detailZoom.toStringAsFixed(1) + 'x', style: const TextStyle(fontSize: 9, color: Colors.white38)),
      ])),
    );
  }
}

class _MinimizedDetailPill extends StatelessWidget {
  const _MinimizedDetailPill({required this.planet, required this.onTap});
  final Planet planet; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(planet.isSun ? '☀️' : planet.id == 'saturn' ? '🪐' : '🌍', style: const TextStyle(fontSize: 15)),
      const SizedBox(width: 7), Text(planet.name + ' Facts', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(width: 7), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: AppTheme.accentIndigo.withValues(alpha: .8), borderRadius: BorderRadius.circular(999)),
        child: const Text('ⓘ Show', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFFE0E7FF)))),
    ]),
  ));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.title, required this.value});
  final IconData icon; final String title; final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(color: AppTheme.space800.withValues(alpha: .80), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: .05))),
    child: Row(children: [
      Icon(icon, size: 14, color: AppTheme.accentAmber),
      const SizedBox(width: 7),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFFA5B4FC))),
          const SizedBox(height: 1),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      )),
    ]),
  );
}
}
