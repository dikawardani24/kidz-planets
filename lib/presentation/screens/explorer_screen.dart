import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../infrastructure/services/scene_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/overlays/bottom_nav.dart';
import '../widgets/overlays/toast_overlay.dart';
import '../widgets/overlays/top_bar.dart';
import '../widgets/panels/missions_panel.dart';
import '../widgets/panels/planet_detail_sheet.dart';
import '../widgets/panels/playground_panel.dart';
import '../widgets/scene/solar_system_scene_view.dart';

class ExplorerScreen extends ConsumerWidget {
  const ExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);

    ref.listen<ExplorerState>(explorerControllerProvider, (prev, next) {
      if (prev?.showOrbits != next.showOrbits) {
        try {
          ref.read(solarSystemSceneControllerProvider).setOrbitsVisible(next.showOrbits);
        } catch (_) {}
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.space950,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth > 390 ? 390.0 : constraints.maxWidth;
        return Center(child: SizedBox(
          width: width,
          height: constraints.maxHeight,
          child: Stack(fit: StackFit.expand, children: [
            const SolarSystemSceneView(),
            const Positioned(top: 0, left: 0, right: 0, child: ExplorerTopBar()),
            const ExplorerInteractionOverlays(),
            const ToastOverlay(),
            if (ui.tab == ExplorerTab.playground)
              const Positioned(left: 12, right: 12, top: 64, bottom: 66, child: PlaygroundPanel()),
            if (ui.tab == ExplorerTab.missions)
              const Positioned(left: 12, right: 12, top: 64, bottom: 66, child: MissionsPanel()),
            if (ui.hasSelection && ui.tab == ExplorerTab.explore)
              Positioned(left: 16, right: 16, bottom: 70, child: _DetailWrapper(planetId: ui.selectedPlanetId!)),
            if (ui.tab == ExplorerTab.explore && !ui.hasSelection)
              const Positioned(left: 12, right: 12, bottom: 68, child: Center(child: ExplorerControlPills())),
            const ExplorerDetailHud(),
            const ExplorerBottomNav(),
            if (ui.celebrationVisible)
              Positioned.fill(child: _CelebrationModal(
                title: ui.celebrationTitle!,
                description: ui.celebrationDescription!,
              )),
          ]),
        ));
      }),
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
  const _CelebrationModal({required this.title, required this.description});
  final String title;
  final String description;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppTheme.space950.withValues(alpha: .85),
      child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentAmber.withValues(alpha: .20), border: Border.all(color: AppTheme.accentAmber, width: 2)),
          alignment: Alignment.center, child: const Text('🎉', style: TextStyle(fontSize: 38))),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFFC7D2FE))),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: () => ref.read(explorerControllerProvider.notifier).closeCelebration(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              gradient: LinearGradient(colors: [AppTheme.accentIndigo, Color(0xFF7C3AED)]),
              boxShadow: [BoxShadow(color: Color(0x664F46E5), blurRadius: 18, offset: Offset(0, 7))],
            ),
            child: const Text('Continue Exploring 🚀', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ])),
    );
  }
}
