import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../infrastructure/services/planet_narration_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/localized_mission.dart';
import '../../theme/app_theme.dart';

void showMissionDialog(BuildContext context, WidgetRef ref) {
  final t = AppLocalizations.of(context);
  final ui = ref.read(explorerControllerProvider);
  final matches = ui.missions.where((m) => m.id == ui.activeMissionId);
  if (matches.isEmpty) return;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: t.missionDetailsBarrierLabel,
    barrierColor: Colors.black.withValues(alpha: .78),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => _MissionDialog(mission: matches.first),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween<double>(begin: .92, end: 1).animate(curved), child: child));
    },
  );
}

class MissionGuide extends ConsumerWidget {
  const MissionGuide({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final t = AppLocalizations.of(context);
    final matches = ui.missions.where((m) => m.id == ui.activeMissionId);
    if (matches.isEmpty || matches.first.completed) return const SizedBox.shrink();
    final mission = localizedMission(matches.first, Localizations.localeOf(context));
    return Align(alignment: Alignment.topCenter, child: GestureDetector(
      onTap: () => showMissionDialog(context, ref),
      child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Text(t.missionPill(mission.id, mission.title), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    ));
  }
}

class _MissionDialog extends ConsumerWidget {
  const _MissionDialog({required this.mission});
  final MissionState mission;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final planet = ref.watch(planetByIdProvider(mission.targetPlanetId));
    final controller = ref.read(explorerControllerProvider.notifier);
    // Read live rather than snapshotted at open time, so revealing a clue
    // updates the text without having to reopen the dialog.
    final level = ref.watch(explorerControllerProvider.select((s) => s.missionHintLevel));
    // Resolved on every build, so switching language while the dialog is open
    // retranslates it in place instead of leaving the old language on screen.
    final copy = localizedMission(mission, Localizations.localeOf(context));
    final clue = copy.clueAt(level);
    final hasMoreClues = level < copy.hints.length - 1;
    return Material(color: Colors.transparent, child: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(20), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430, maxHeight: 620),
      child: AppTheme.glass(radius: BorderRadius.circular(28), padding: const EdgeInsets.all(18), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('🚀', style: TextStyle(fontSize: 22)), const SizedBox(width: 8), Expanded(child: Text(t.missionHeading(mission.id), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.accentSky))), IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white70))]),
        Text(copy.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 8),
        Text(copy.description, style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFFC7D2FE))),
        const SizedBox(height: 14),
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.space800.withValues(alpha: .75), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.missionStartHere, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.accentAmber)),
          const SizedBox(height: 5), Text(t.missionStartAt(copy.startPoint ?? t.missionStartAtDefault), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 7), Text('➡️  ${copy.direction ?? t.missionDirectionDefault}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDDEAFE))),
        ])),
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.accentSky.withValues(alpha: .25))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipOval(child: SizedBox(width: 76, height: 76, child: Image.asset(planet.textureAsset, fit: BoxFit.cover, errorBuilder: (_, _, _) => Center(child: Text(planet.isSun ? '☀️' : '🪐', style: const TextStyle(fontSize: 34)))))),
            const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.missionLookForThis, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.accentAmber)), const SizedBox(height: 5), Text(clue, style: const TextStyle(fontSize: 11, height: 1.4, color: Color(0xFFE0E7FF)))])),
            IconButton(onPressed: () => ref.read(planetNarrationServiceProvider).replay(planet), icon: const Icon(Icons.volume_up_rounded, color: AppTheme.accentSky)),
          ]),
          if (hasMoreClues) ...[
            const SizedBox(height: 10),
            // Asking is the only way to get a bigger clue, so the button is
            // offered plainly rather than hidden behind a streak of misses.
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: controller.revealNextHint,
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 17, color: AppTheme.accentAmber),
              label: Text(t.missionNeedBiggerClue, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.accentSky.withValues(alpha: .95))),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.accentSky.withValues(alpha: .3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            )),
          ],
        ])),
        const SizedBox(height: 14), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.explore_rounded), label: Text(t.missionGotIt))),
      ]))),
    )))));
  }
}
