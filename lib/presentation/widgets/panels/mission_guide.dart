import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../infrastructure/services/planet_narration_provider.dart';
import '../../theme/app_theme.dart';

class MissionGuide extends ConsumerWidget {
  const MissionGuide({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final matches = ui.missions.where((m) => m.id == ui.activeMissionId);
    final mission = matches.isEmpty ? null : matches.first;
    if (mission == null || mission.completed) return const SizedBox.shrink();
    final controller = ref.read(explorerControllerProvider.notifier);
    if (!ui.missionGuideVisible) return Align(alignment: Alignment.topCenter, child: GestureDetector(onTap: controller.toggleMissionGuide, child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('🚀 Mission ${mission.id} · ${mission.title}  ⌄', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)))));
    final planet = ref.watch(planetByIdProvider(mission.targetPlanetId));
    final clue = ui.missionHintLevel == 0 ? (mission.hint ?? mission.description) : '${mission.hint ?? mission.description} ${mission.direction ?? 'Count outward from the Sun'}.';
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: AppTheme.glass(radius: BorderRadius.circular(28), padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('🚀', style: TextStyle(fontSize: 22)), const SizedBox(width: 8), Expanded(child: Text('MISSION ${mission.id}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.accentSky))), IconButton(onPressed: controller.toggleMissionGuide, icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white70))]),
      Text(mission.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 8),
      Text(mission.description, style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFFC7D2FE))),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.space800.withValues(alpha: .75), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('START HERE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.accentAmber)),
        const SizedBox(height: 5),
        Text('☀️  Start at ${mission.startPoint ?? 'the Sun'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 7),
        Text('➡️  ${mission.direction ?? 'Count outward'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDDEAFE))),
      ])),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.accentSky.withValues(alpha: .25))), child: Row(children: [
        ClipOval(child: SizedBox(width: 76, height: 76, child: Image.asset(planet.textureAsset, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(planet.isSun ? '☀️' : '🪐', style: const TextStyle(fontSize: 34)))))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('LOOK FOR THIS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.accentAmber)), const SizedBox(height: 5), Text(clue, style: const TextStyle(fontSize: 11, height: 1.4, color: Color(0xFFE0E7FF)))])),
        IconButton(onPressed: () => ref.read(planetNarrationServiceProvider).replay(planet), icon: const Icon(Icons.volume_up_rounded, color: AppTheme.accentSky)),
      ])),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: controller.toggleMissionGuide, icon: const Icon(Icons.explore_rounded), label: const Text('Got it — let’s explore!'))),
    ])));
  }
}
}

class WrongMissionFeedback extends StatelessWidget {
  const WrongMissionFeedback({super.key});
  @override
  Widget build(BuildContext context) => Center(child: TweenAnimationBuilder<double>(tween: Tween(begin: .0, end: 1), duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack, builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: .8 + v * .2, child: child)), child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10), child: const Text('💫 Not this one — let’s check the clue!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)))));
}