import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../domain/entities/planet.dart';
import '../../../infrastructure/services/planet_tts_provider.dart';
import '../../theme/app_theme.dart';

class PlanetDetailSheet extends ConsumerWidget {
  const PlanetDetailSheet({super.key, required this.planet});

  final Planet planet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);

    return AppTheme.glass(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: ui.detailCardVisible
                ? _DetailContent(
                    planet: planet,
                    ui: ui,
                    onPlayMode: notifier.toggleDetailCard,
                    onClose: notifier.closeDetail,
                    onHotspot: (hotspot) {
                      ref.read(planetTtsServiceProvider).speak(
                            hotspot.title,
                            hotspot.description,
                          );
                      notifier.showHotspot(hotspot);
                    },
                  )
                : const SizedBox.shrink(),
          ),
          if (ui.detailCardVisible) const SizedBox(height: 8),
          _DetailZoomBar(
            zoom: ui.detailZoom,
            onZoomOut: () => notifier.adjustDetailZoom(.25),
            onZoomIn: () => notifier.adjustDetailZoom(-.25),
            onReset: notifier.resetDetailView,
          ),
          const SizedBox(height: 7),
          _CollapseButton(
            collapsed: !ui.detailCardVisible,
            onTap: notifier.toggleDetailCard,
          ),
        ],
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.planet,
    required this.ui,
    required this.onPlayMode,
    required this.onClose,
    required this.onHotspot,
  });

  final Planet planet;
  final ExplorerState ui;
  final VoidCallback onPlayMode;
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
                  onTap: onPlayMode,
                  child: AppTheme.glass(
                    pill: true,
                    radius: BorderRadius.circular(999),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.gamepad,
                          size: 12,
                          color: AppTheme.accentAmber,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Play Mode',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFE7A3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
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
  });

  final double zoom;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final percent = (100 / zoom).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ZoomButton(icon: Icons.remove, onTap: onZoomOut),
        const SizedBox(width: 7),
        AppTheme.glass(
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
        ),
        const SizedBox(width: 7),
        _ZoomButton(icon: Icons.add, onTap: onZoomIn),
        const SizedBox(width: 7),
        _ZoomButton(icon: Icons.refresh, onTap: onReset, small: true),
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

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({
    required this.collapsed,
    required this.onTap,
  });

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppTheme.glass(
        pill: true,
        radius: BorderRadius.circular(999),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              collapsed
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 15,
              color: AppTheme.accentSky,
            ),
            const SizedBox(width: 4),
            Text(
              collapsed ? 'Show facts' : 'Collapse',
              style: const TextStyle(
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
