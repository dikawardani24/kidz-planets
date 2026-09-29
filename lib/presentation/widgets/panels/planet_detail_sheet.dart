import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../domain/entities/planet.dart';
import '../../../infrastructure/services/planet_narration_provider.dart';
import '../../../infrastructure/services/planet_sound_provider.dart';
import '../../theme/app_theme.dart';
import '../overlays/top_bar.dart';

class PlanetDetailSheet extends ConsumerWidget {
  const PlanetDetailSheet({super.key, required this.planet});

  final Planet planet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);

    return AppTheme.glass(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
      child: _DetailContent(
        planet: planet,
        ui: ui,
        onClose: () => Navigator.of(context).pop(),
        onHotspot: (hotspot) {
          ref
              .read(planetNarrationServiceProvider)
              .speakHotspot(hotspot);
          ref.read(explorerControllerProvider.notifier).showHotspot(hotspot);
        },
      ),
    );
  }
}

/// Opens the full facts view as a modal dialog. The dialog owns its available
/// space, so orientation changes do not constrain the facts card to the scene.
class DetailDescriptionToggle extends ConsumerWidget {
  const DetailDescriptionToggle({super.key, required this.planet});

  final Planet planet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Planet facts',
          barrierColor: Colors.black.withValues(alpha: .68),
          transitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, _, _) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 620,
                maxHeight: 620,
              ),
              child: PlanetDetailSheet(planet: planet),
            ),
          ),
          transitionBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: .94, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
      },
      child: AppTheme.glass(
        pill: true,
        radius: BorderRadius.circular(999),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_up,
              size: 15,
              color: AppTheme.accentSky,
            ),
            SizedBox(width: 4),
            Text(
              'Show facts',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailSideRails extends ConsumerWidget {
  const DetailSideRails({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    if (!ui.hasSelection || ui.tab != ExplorerTab.explore) {
      return const SizedBox.shrink();
    }
    final planet = ref.watch(planetByIdProvider(ui.selectedPlanetId!));
    final notifier = ref.read(explorerControllerProvider.notifier);
    final top = bannerTop(context) + 8;

    return Stack(children: [
      // Voice + Play Mode rail, below the app title on the left.
      Positioned(
        left: 12,
        top: top,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () =>
                  ref.read(planetNarrationServiceProvider).replay(planet),
              child: AppTheme.glass(
                pill: true,
                radius: BorderRadius.circular(999),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volume_up_rounded,
                      size: 14,
                      color: AppTheme.accentSky,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Listen',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDDEAFE),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () =>
                  ref.read(planetSoundServiceProvider).playBody(planet),
              child: AppTheme.glass(
                pill: true,
                radius: BorderRadius.circular(999),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 14,
                      color: AppTheme.accentAmber,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Sound',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFE7A3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: notifier.toggleDetailCard,
              child: AppTheme.glass(
                pill: true,
                radius: BorderRadius.circular(999),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gamepad,
                      size: 14,
                      color: AppTheme.accentAmber,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Play Mode',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFE7A3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Zoom rail, below the app title on the right edge.
      Positioned(
        right: 12,
        top: top,
        child: _DetailZoomBar(
          zoom: ui.detailZoom,
          vertical: true,
          onZoomOut: () => notifier.adjustDetailZoom(.25),
          onZoomIn: () => notifier.adjustDetailZoom(-.25),
          onReset: notifier.resetDetailView,
        ),
      ),
    ]);
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.planet,
    required this.ui,
    required this.onClose,
    required this.onHotspot,
  });

  final Planet planet;
  final ExplorerState ui;
  final VoidCallback onClose;
  final ValueChanged<Hotspot> onHotspot;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planet.isSun
                      ? '☀️'
                      : planet.isMoon
                          ? '🌕'
                          : planet.id == 'saturn'
                              ? '🪐'
                              : '🌍',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ui.detailTitleOverride ?? planet.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        planet.tag,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA5B4FC),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: AppTheme.glass(
                    pill: true,
                    radius: BorderRadius.circular(999),
                    padding: const EdgeInsets.all(7),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Color(0xFFC7D2FE),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              ui.detailDescriptionOverride ?? planet.fact,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.45,
                color: Color(0xFFE0E7FF),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: Icons.straighten,
                    title: 'Diameter',
                    value: planet.diameter,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _Stat(
                    icon: Icons.thermostat,
                    title: 'Avg Temp',
                    value: planet.temperature,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final hotspot in planet.hotspots)
                  GestureDetector(
                    onTap: () => onHotspot(hotspot),
                    child: AppTheme.glass(
                      pill: true,
                      radius: BorderRadius.circular(999),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hotspot.icon,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hotspot.title,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailZoomBar extends StatelessWidget {
  const _DetailZoomBar({
    required this.zoom,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onReset,
    this.vertical = false,
  });

  final double zoom;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onReset;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final percent = (100 / zoom).round();

    final zoomOut = _ZoomButton(icon: Icons.remove, onTap: onZoomOut);
    final badge = AppTheme.glass(
      pill: true,
      radius: BorderRadius.circular(999),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Text(
        '$percent%',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppTheme.accentAmber,
        ),
      ),
    );
    final zoomIn = _ZoomButton(icon: Icons.add, onTap: onZoomIn);
    final reset = _ZoomButton(icon: Icons.refresh, onTap: onReset, small: true);

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          zoomIn,
          const SizedBox(height: 7),
          badge,
          const SizedBox(height: 7),
          zoomOut,
          const SizedBox(height: 7),
          reset,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        zoomOut,
        const SizedBox(width: 7),
        badge,
        const SizedBox(width: 7),
        zoomIn,
        const SizedBox(width: 7),
        reset,
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.onTap,
    this.small = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppTheme.glass(
        pill: true,
        radius: BorderRadius.circular(999),
        padding: EdgeInsets.all(small ? 7 : 8),
        child: Icon(
          icon,
          size: small ? 13 : 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppTheme.space800.withValues(alpha: .80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.accentAmber),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFA5B4FC),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
