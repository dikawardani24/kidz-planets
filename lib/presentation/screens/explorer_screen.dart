import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../infrastructure/services/scene_providers.dart';
import '../../../infrastructure/services/planet_narration_provider.dart';
import '../../../infrastructure/services/planet_sound_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/overlays/bottom_nav.dart';
import '../widgets/overlays/toast_overlay.dart';
import '../widgets/overlays/top_bar.dart';
import '../widgets/panels/missions_panel.dart';
import '../widgets/panels/mission_guide.dart';
import '../widgets/panels/planet_detail_sheet.dart';
import '../widgets/panels/playground_panel.dart';
import '../widgets/scene/solar_system_scene_view.dart';

class ExplorerScreen extends ConsumerWidget {
  const ExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);

    ref.listen<ExplorerState>(explorerControllerProvider, (prev, next) {
      if (prev?.wrongSelectionKey != next.wrongSelectionKey && next.wrongSelectionKey != 0) {
        final matches = next.missions.where((m) => m.id == next.activeMissionId);
        final mission = matches.isEmpty ? null : matches.first;
        if (mission != null) {
          final planet = ref.read(planetByIdProvider(mission.targetPlanetId));
          ref.read(planetNarrationServiceProvider).replay(planet);
          Future<void>.delayed(const Duration(milliseconds: 550), () {
            if (context.mounted) showMissionDialog(context, ref);
          });
        }
      }

      if (prev?.activeMissionId != next.activeMissionId && next.activeMissionId != null) {
        final matches = next.missions.where((m) => m.id == next.activeMissionId);
        if (matches.isNotEmpty) {
          final planet = ref.read(planetByIdProvider(matches.first.targetPlanetId));
          ref.read(planetNarrationServiceProvider).replay(planet);
        }
      }

      if (prev?.selectedPlanetId != next.selectedPlanetId) {
        final narration = ref.read(planetNarrationServiceProvider);
        final sound = ref.read(planetSoundServiceProvider);
        if (next.selectedPlanetId == null) {
          narration.stop();
          sound.stop();
        } else {
          final planet = ref.read(planetByIdProvider(next.selectedPlanetId!));
          narration.speakPlanet(planet);
          sound.playBody(planet);
        }
      }

      if (prev?.showOrbits != next.showOrbits) {
        try {
          ref.read(solarSystemSceneControllerProvider).setOrbitsVisible(next.showOrbits);
        } catch (_) {}
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.space950,
      resizeToAvoidBottomInset: false,
      body: OrientationBuilder(
        builder: (context, orientation) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // OrientationBuilder explicitly reacts to device rotation.
              // LayoutBuilder then supplies the new viewport dimensions.
              final isLandscape = orientation == Orientation.landscape;
          final horizontalInset = isLandscape ? 24.0 : 0.0;

          // The scene is intentionally allowed to use the entire viewport.
          // The previous 390px width cap made landscape render as a narrow
          // portrait-sized canvas with unused space on both sides.
              return Stack(
                fit: StackFit.expand,
                children: [
              const SolarSystemSceneView(),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ExplorerTopBar(),
              ),
              const ExplorerInteractionOverlays(),
              const ToastOverlay(),if (ui.wrongFeedbackVisible)
                Positioned.fill(child: WrongMissionFeedback()),

              if (ui.tab == ExplorerTab.playground)
                Positioned(
                  left: horizontalInset + 12,
                  right: horizontalInset + 12,
                  top: isLandscape ? 68 : 64,
                  bottom: isLandscape ? 72 : 66,
                  child: const PlaygroundPanel(),
                ),

              if (ui.tab == ExplorerTab.missions)
                Positioned(
                  left: horizontalInset + 12,
                  right: horizontalInset + 12,
                  top: isLandscape ? 68 : 64,
                  bottom: isLandscape ? 72 : 66,
                  child: const MissionsPanel(),
                ),

              if (ui.hasSelection && ui.tab == ExplorerTab.explore)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 76,
                  child: Center(
                    child: DetailDescriptionToggle(
                      planet: ref.watch(
                        planetByIdProvider(ui.selectedPlanetId!),
                      ),
                    ),
                  ),
                ),

              if (ui.hasSelection && ui.tab == ExplorerTab.explore)
                const Positioned.fill(child: DetailSideRails()),

              const ExplorerBottomNav(),

              if (ui.celebrationVisible)
                Positioned.fill(
                  child: _CelebrationModal(
                    title: ui.celebrationTitle!,
                    description: ui.celebrationDescription!,
                  ),
                ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailWrapper extends ConsumerWidget {
  const _DetailWrapper({required this.planetId});
  final String planetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planet = ref.watch(planetByIdProvider(planetId));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 290),
      child: PlanetDetailSheet(planet: planet),
    );
  }
}

class _CelebrationModal extends ConsumerWidget {
  const _CelebrationModal({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppTheme.space950.withValues(alpha: .85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentAmber.withValues(alpha: .20),
                  border: Border.all(color: AppTheme.accentAmber, width: 2),
                ),
                alignment: Alignment.center,
                child: const Text('🎉', style: TextStyle(fontSize: 38)),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFFC7D2FE),
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () => ref
                    .read(explorerControllerProvider.notifier)
                    .closeCelebration(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    gradient: LinearGradient(
                      colors: [AppTheme.accentIndigo, Color(0xFF7C3AED)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x664F46E5),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Continue Exploring 🚀',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
