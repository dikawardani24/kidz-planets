import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../infrastructure/services/scene_providers.dart';
import '../widgets/overlays/bottom_nav.dart';
import '../widgets/overlays/toast_overlay.dart';
import '../widgets/overlays/top_bar.dart';
import '../widgets/panels/missions_panel.dart';
import '../widgets/panels/planet_detail_sheet.dart';
import '../widgets/panels/planets_panel.dart';
import '../widgets/scene/solar_system_scene_view.dart';

class ExplorerScreen extends ConsumerWidget {
  const ExplorerScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    ref.listen<ExplorerState>(explorerControllerProvider, (prev, next) {
      if (prev?.showOrbits != next.showOrbits) {
        try { ref.read(solarSystemSceneControllerProvider).setOrbitsVisible(next.showOrbits); } catch (_) {}
      }
    });
    return Scaffold(
      backgroundColor: const Color(0xFF010206),
      resizeToAvoidBottomInset: false,
      // NOTE: the inner Stack contains only Positioned children, so it has
      // no intrinsic size. The Container MUST be forced to fill the screen
      // (width/height infinity) otherwise the Stack collapses to zero and
      // flutter_scene logs "draw region is zero-sized" + renders black.
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Stack(children: [
          const Positioned.fill(child: SolarSystemSceneView()),
          const Positioned(top: 0, left: 0, right: 0, child: ExplorerTopBar()),
          const ToastOverlay(),
          Positioned(left: 0, right: 0, bottom: 0, child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (ui.tab == ExplorerTab.explore) ...[
              if (ui.hasSelection)
                const SizedBox(height: 8)
              else
                const Padding(padding: EdgeInsets.only(bottom: 8), child: ExplorerControlPills()),
              const ExplorerBottomNav(),
            ],
          ])),
          if (ui.tab == ExplorerTab.planets)
            Positioned(left: 0, right: 0, bottom: 0, top: 120, child: const PlanetsGridPanel()),
          if (ui.tab == ExplorerTab.missions)
            Positioned(left: 0, right: 0, bottom: 0, top: 120, child: const MissionsPanel()),
          if (ui.hasSelection && ui.tab == ExplorerTab.explore)
            Positioned(left: 0, right: 0, bottom: 0, child: _DetailWrapper(planetId: ui.selectedPlanetId!)),
        ])))));
  }
}

class _DetailWrapper extends ConsumerWidget {
  const _DetailWrapper({required this.planetId});
  final String planetId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planet = ref.watch(planetByIdProvider(planetId));
    final sheetHeight = MediaQuery.of(context).size.height * 0.42;
    return SizedBox(height: sheetHeight + 86, child: Stack(children: [
      Positioned(left: 0, right: 0, bottom: 0, height: sheetHeight, child: PlanetDetailSheet(planet: planet)),
      const Positioned(left: 0, right: 0, bottom: 0, child: ExplorerBottomNav()),
    ]));
  }
}
