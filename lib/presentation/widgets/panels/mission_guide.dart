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
    final mission = ui.missions.where((m) => m.id == ui.activeMissionId).firstOrNull;
    if (mission == null || mission.completed) return const SizedBox.shrink();
    final controller = ref.read(explorerControllerProvider.notifier);
    if (!ui.missionGuideVisible) return Align(alignment: Alignment.topCenter, child: GestureDetector(onTap: controller.toggleMissionGuide, child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('🚀 Mission ${mission.id} · ${mission.title}  ⌄', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)))));
    final planet = ref.watch(planetByIdProvider(mission.targetPlanetId));
    final clue = ui.missionHintLevel == 0 ? (mission.hint ?? mission.description) : '${mission.hint ?? mission.description} ${mission.direction ?? 'Count outward from the Sun'}.';
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: AppTheme.glass(radius: BorderRadius.circular(22), padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('🚀', style: TextStyle(fontSize: 18)), const SizedBox(width: 7), Expanded(child: Text('MISSION ${mission.id}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.accentSky))), GestureDetector(onTap: controller.toggleMissionGuide, child: const Icon(Icons.keyboard_arrow_up, size: 18, color: Colors.white70))]),
      const SizedBox(height: 4),
      Text(mission.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 7),
      Text('📍 Start at ${mission.startPoint ?? 'the Sun'}   →   ${mission.direction ?? 'Explore outward'}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFDDEAFE))),
      const SizedBox(height: 9),
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppTheme.space800.withValues(alpha: .8), borderRadius: BorderRadius.circular(16)), child: Row(children: [
        ClipOval(child: SizedBox(width: 58, height: 58, child: Image.asset(planet.textureAsset, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(planet.isSun ? '☀️' : '🪐', style: const TextStyle(fontSize: 27))))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('LOOK FOR THIS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.accentAmber)), const SizedBox(height: 3), Text(clue, style: const TextStyle(fontSize: 10, height: 1.35, color: Color(0xFFE0E7FF)))])),
        GestureDetector(onTap: () => ref.read(planetNarrationServiceProvider).replay(planet), child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.all(9), child: const Icon(Icons.volume_up_rounded, size: 16, color: AppTheme.accentSky))),
      ])),
      const SizedBox(height: 5),
      Text(ui.missionHintLevel == 0 ? 'Use the picture as your clue.' : 'Hint ${ui.missionHintLevel.clamp(1, 3)} · Need more help? Keep exploring!', style: const TextStyle(fontSize: 9, color: Color(0xFF9CA9D8))),
    ]))));
  }
}

class WrongMissionFeedback extends StatelessWidget {
  const WrongMissionFeedback({super.key});
  @override
  Widget build(BuildContext context) => Center(child: TweenAnimationBuilder<double>(tween: Tween(begin: .0, end: 1), duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack, builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: .8 + v * .2, child: child)), child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10), child: const Text('💫 Not this one — let’s check the clue!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)))));
}