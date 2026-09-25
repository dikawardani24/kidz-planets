import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../theme/app_theme.dart';

class MissionsPanel extends ConsumerWidget {
  const MissionsPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    final completed = ui.missions.where((m) => m.completed).length;
    return Container(
      decoration: BoxDecoration(color: AppTheme.space900.withValues(alpha: 0.96), borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.14)))),
      child: SafeArea(top: false, child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(children: [Expanded(child: Text('Space Missions  $completed/${ui.missions.length}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white))),
            GestureDetector(onTap: () => notifier.setTab(ExplorerTab.explore),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(999)),
                child: const Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70))))])),
        Flexible(child: ListView.separated(padding: const EdgeInsets.fromLTRB(16, 10, 16, 18), itemCount: ui.missions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final m = ui.missions[i];
            return GestureDetector(onTap: () { notifier.setTab(ExplorerTab.explore); notifier.selectPlanet(m.targetPlanetId); },
              child: Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: m.completed ? const Color(0xFF14532D).withValues(alpha: 0.75) : AppTheme.space800,
                  borderRadius: BorderRadius.circular(18), border: Border.all(color: m.completed ? const Color(0xFF22C55E) : Colors.white.withValues(alpha: 0.12))),
                child: Row(children: [
                  Container(width: 40, height: 40, alignment: Alignment.center,
                    decoration: BoxDecoration(color: m.completed ? const Color(0xFF22C55E) : Colors.white12, shape: BoxShape.circle),
                    child: Text(m.completed ? '✓' : '${i + 1}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(m.description, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ])),
                  const Icon(Icons.chevron_right, color: Colors.white38),
                ])));
          })),
      ])));
  }
}
