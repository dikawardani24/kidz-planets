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
    final progress = ui.missions.isEmpty ? 0.0 : completed / ui.missions.length;
    return AppTheme.glass(radius: BorderRadius.circular(24), padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.rocket_launch, color: AppTheme.accentSky, size: 18), SizedBox(width: 7), Text('Space Missions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))]),
            SizedBox(height: 3), Text('Explore and verify NASA worlds!', style: TextStyle(fontSize: 10.5, color: Color(0xFF9CA9D8))),
          ])),
          AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star, size: 11, color: AppTheme.accentAmber), const SizedBox(width: 5), Text(completed.toString() + ' / ' + ui.missions.length.toString(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.accentAmber))])),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: Container(height: 9, color: AppTheme.space800, child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: progress, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppTheme.accentIndigo, AppTheme.accentAmber])))))),
        const SizedBox(height: 10),
        ...ui.missions.map((m) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: m.completed ? const Color(0x1A22C55E) : AppTheme.space800.withValues(alpha: .82), borderRadius: BorderRadius.circular(15), border: Border.all(color: m.completed ? const Color(0x6622C55E) : Colors.white.withValues(alpha: .10))),
          child: Row(children: [
            Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: m.completed ? const Color(0x3322C55E) : const Color(0x334F46E5), borderRadius: BorderRadius.circular(11), border: Border.all(color: m.completed ? const Color(0x6622C55E) : const Color(0x664F46E5))),
              child: m.completed ? const Icon(Icons.check, size: 15, color: Color(0xFF86EFAC)) : Text(m.id.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFC7D2FE)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 2), Text(m.description, style: const TextStyle(fontSize: 9.5, color: Colors.white60)),
            ])),
            GestureDetector(onTap: () { notifier.setTab(ExplorerTab.explore); notifier.selectPlanet(m.targetPlanetId); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: m.completed ? const Color(0x3322C55E) : AppTheme.accentIndigo, borderRadius: BorderRadius.circular(999)),
                child: Text(m.completed ? 'Done' : 'Find →', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: m.completed ? const Color(0xFF86EFAC) : Colors.white)))),
          ]),
        ))),
      ])));
  }
}
