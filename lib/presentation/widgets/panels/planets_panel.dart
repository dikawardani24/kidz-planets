import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../domain/entities/planet.dart';
import '../../theme/app_theme.dart';

class PlanetsGridPanel extends ConsumerWidget {
  const PlanetsGridPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planets = ref.watch(planetsProvider);
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    final others = planets.where((p) => !p.isSun).toList();
    return Container(
      decoration: BoxDecoration(color: AppTheme.space900.withValues(alpha: 0.96), borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.14)))),
      child: SafeArea(top: false, child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(children: [const Expanded(child: Text('Choose a Planet', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white))),
            GestureDetector(onTap: () => notifier.setTab(ExplorerTab.explore),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(999)),
                child: const Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70))))])),
        Flexible(child: GridView.builder(padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35),
          itemCount: others.length,
          itemBuilder: (context, i) => _PlanetCard(planet: others[i], selected: ui.selectedPlanetId == others[i].id))),
      ])));
  }
}

class _PlanetCard extends ConsumerWidget {
  const _PlanetCard({required this.planet, required this.selected});
  final Planet planet; final bool selected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(explorerControllerProvider.notifier)
          ..setTab(ExplorerTab.explore)
          ..selectPlanet(planet.id);
      },
      child: Container(padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(planet.colorValue).withValues(alpha: 0.34), AppTheme.space800]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.accentAmber : Colors.white.withValues(alpha: 0.14), width: selected ? 2 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(children: [
            Container(width: 26, height: 26, decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(planet.colorValue), Color(planet.colorValue).withValues(alpha: 0.55)]))),
            const SizedBox(width: 8),
            Expanded(child: Text(planet.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
          ]),
          const SizedBox(height: 5),
          Text(planet.tag, style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(planet.diameter, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        ])));
  }
}
