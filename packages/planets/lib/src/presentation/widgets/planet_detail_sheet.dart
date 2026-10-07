import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/layout.dart';
import 'package:core/l10n.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';
import 'package:planets/planets.dart';

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
          ref.read(planetNarrationServiceProvider).speakHotspot(hotspot);
          ref
              .read(explorerControllerProvider.notifier)
              .showHotspot(hotspot, planetId: planet.id);
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
    // On TV the facts pill takes initial focus after a selection, so a second
    // OK opens the existing facts dialog: no separate detail step needed.
    // Sizing is purely viewport-derived, like every other pill here.
    final isTv = ref.watch(isTelevisionProvider);
    final ds = DesignScale.sharedOf(context);
    return TvFocusable(
      autofocus: isTv,
      onSelect: () {
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
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 620),
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
        radius: BorderRadius.circular(ds.radius(999)),
        padding: ds.insets(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_up,
              size: ds.px(15),
              color: AppTheme.accentSky,
            ),
            SizedBox(width: ds.px(4)),
            Text(
              'Show facts',
              style: TextStyle(
                fontSize: ds.font(9),
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
    // Every dimension derives from the viewport scale; the top offset tracks
    // the scaled bar height so the rails never slide under it.
    final ds = DesignScale.sharedOf(context);
    final ui = ref.watch(explorerControllerProvider);
    if (!ui.hasSelection) {
      return const SizedBox.shrink();
    }
    final planet = ref.watch(planetByIdProvider(ui.selectedPlanetId!));
    final notifier = ref.read(explorerControllerProvider.notifier);
    final top =
        MediaQuery.paddingOf(context).top + ds.px(kTopBarExtent) + ds.px(8);

    return Stack(
      children: [
        // Voice + Play Mode rail, below the app title on the left.
        Positioned(
          left: 12,
          top: top,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TvFocusable(
                onSelect: () =>
                    ref.read(planetNarrationServiceProvider).replay(planet),
                child: AppTheme.glass(
                  pill: true,
                  radius: BorderRadius.circular(ds.radius(999)),
                  padding: ds.insets(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.volume_up_rounded,
                        size: ds.px(14),
                        color: AppTheme.accentSky,
                      ),
                      SizedBox(width: ds.px(5)),
                      Text(
                        'Listen',
                        style: TextStyle(
                          fontSize: ds.font(10),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFDDEAFE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: ds.px(6)),
              TvFocusable(
                onSelect: () =>
                    ref.read(planetSoundServiceProvider).playBody(planet),
                child: AppTheme.glass(
                  pill: true,
                  radius: BorderRadius.circular(999),
                  padding: ds.insets(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: ds.px(14),
                        color: AppTheme.accentAmber,
                      ),
                      SizedBox(width: ds.px(5)),
                      Text(
                        'Sound',
                        style: TextStyle(
                          fontSize: ds.font(10),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFE7A3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: ds.px(6)),
              TvFocusable(
                onSelect: notifier.toggleDetailCard,
                child: AppTheme.glass(
                  pill: true,
                  radius: BorderRadius.circular(ds.radius(999)),
                  padding: ds.insets(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.gamepad,
                        size: ds.px(14),
                        color: AppTheme.accentAmber,
                      ),
                      SizedBox(width: ds.px(5)),
                      Text(
                        'Play Mode',
                        style: TextStyle(
                          fontSize: ds.font(10),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFE7A3),
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
            onClose: notifier.closeDetail,
          ),
        ),
      ],
    );
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
    // Resolved once here rather than per field, so the heading, the body
    // copy, and the hotspot pills cannot disagree about which language they
    // are in, and a language change repaints all of them together.
    final body = localizedPlanet(planet, Localizations.localeOf(context));
    final selected = ui.detailHotspot;
    final shownHotspot = selected == null
        ? null
        : body.hotspots
              .where((h) => h.hotspot.slug == selected.slug)
              .firstOrNull;
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
                        shownHotspot?.title ?? body.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body.tag,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA5B4FC),
                        ),
                      ),
                    ],
                  ),
                ),
                TvFocusable(
                  onSelect: onClose,
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
              shownHotspot?.description ?? body.fact,
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
                    title: AppLocalizations.of(context).statDiameter,
                    value: planet.diameter,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _Stat(
                    icon: Icons.thermostat,
                    title: AppLocalizations.of(context).statAvgTemp,
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
                for (final entry in body.hotspots)
                  TvFocusable(
                    onSelect: () => onHotspot(entry.hotspot),
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
                            entry.hotspot.icon,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.title,
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
    required this.onClose,
    this.vertical = false,
  });

  final double zoom;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onReset;

  /// Leaves the focused body entirely.
  ///
  /// Separate from [onReset] on purpose: resetting the framing keeps the body
  /// focused and its narration playing, so a child who taps the cross while the
  /// camera is somewhere they cannot get back from still gets the body released
  /// rather than stuck zoomed in.
  final VoidCallback onClose;

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
    final close = _ZoomButton(
      icon: Icons.close,
      onTap: onClose,
      small: true,
      color: const Color(0xFFC7D2FE),
    );

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          zoomIn,
          const SizedBox(height: 7),
          badge,
          const SizedBox(height: 7),
          zoomOut,
          // A wider gap than the ones inside the zoom cluster, so the two ways
          // out of the focused view read as their own group rather than as a
          // fourth step of the same control.
          const SizedBox(height: 13),
          reset,
          const SizedBox(height: 7),
          close,
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
        const SizedBox(width: 7),
        close,
      ],
    );
  }
}

class _ZoomButton extends ConsumerWidget {
  const _ZoomButton({
    required this.icon,
    required this.onTap,
    this.small = false,
    this.color = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool small;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One viewport-derived size for the compact buttons everywhere.
    final ds = DesignScale.sharedOf(context);
    return TvFocusable(
      onSelect: onTap,
      child: AppTheme.glass(
        pill: true,
        radius: BorderRadius.circular(ds.radius(999)),
        padding: ds.all(small ? 7 : 8),
        child: Icon(icon, size: ds.px(small ? 13 : 16), color: color),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.title, required this.value});

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
