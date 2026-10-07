import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/layout.dart';
import 'package:core/l10n.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';
import 'package:planets/domain.dart';
import 'package:planets/state.dart';

import 'tv_providers.dart';

/// Quick Planet & Moon Selector Drawer for Android TV testing and fast navigation.
///
/// Provides a horizontal carousel of all celestial bodies. Selecting a body
/// instantly marks and frames it in 3D without requiring manual camera orbiting.
class TvQuickSelectDrawer extends ConsumerWidget {
  const TvQuickSelectDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tvState = ref.watch(tvExplorerControllerProvider);
    if (!tvState.quickSelectVisible) return const SizedBox.shrink();

    final planets = ref.watch(planetsProvider);
    final tvController = ref.read(tvExplorerControllerProvider.notifier);
    final explorerController = ref.read(explorerControllerProvider.notifier);
    final t = AppLocalizations.of(context);
    final ds = DesignScale.tvOf(context);

    return Positioned(
      top: ds.px(30),
      left: ds.px(40),
      right: ds.px(40),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: ds.insets(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: AppTheme.space950.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(ds.radius(28)),
            border: Border.all(
              color: AppTheme.accentAmber.withValues(alpha: 0.6),
              width: ds.px(2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: ds.px(30),
                spreadRadius: ds.px(5),
              ),
            ],
          ),
          child: TvFocusContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('🪐', style: TextStyle(fontSize: ds.font(28))),
                    SizedBox(width: ds.px(10)),
                    Text(
                      t.sectionPlanets.toUpperCase(),
                      style: TextStyle(
                        fontSize: ds.font(22),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: ds.px(1.5),
                      ),
                    ),
                    const Spacer(),
                    TvFocusable(
                      onSelect: tvController.dismissQuickSelect,
                      child: Container(
                        padding: ds.insets(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.space700.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(ds.radius(999)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close,
                              size: ds.px(18),
                              color: Colors.white,
                            ),
                            SizedBox(width: ds.px(6)),
                            Text(
                              'Close',
                              style: TextStyle(
                                fontSize: ds.font(16),
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
                SizedBox(height: ds.px(16)),
                SizedBox(
                  height: ds.px(120),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: planets.length,
                    separatorBuilder: (_, _) => SizedBox(width: ds.px(14)),
                    itemBuilder: (context, index) {
                      final planet = planets[index];
                      return _QuickSelectCard(
                        planet: planet,
                        autofocus: index == 0,
                        onSelect: () {
                          tvController.dismissQuickSelect();
                          explorerController.selectPlanet(planet.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickSelectCard extends StatelessWidget {
  const _QuickSelectCard({
    required this.planet,
    required this.onSelect,
    this.autofocus = false,
  });

  final Planet planet;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ds = DesignScale.tvOf(context);
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      scaleOnFocus: true,
      builder: (_, focused, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: ds.px(140),
        padding: ds.insets(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.space700.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(ds.radius(20)),
          border: Border.all(
            color: focused
                ? AppTheme.accentAmber
                : Colors.white.withValues(alpha: 0.16),
            width: ds.px(focused ? 3 : 1),
          ),
          boxShadow: [
            if (focused)
              BoxShadow(
                color: AppTheme.accentAmber.withValues(alpha: 0.4),
                blurRadius: ds.px(16),
                spreadRadius: ds.px(1),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ds.px(24),
              height: ds.px(24),
              decoration: BoxDecoration(
                color: Color(planet.colorValue),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(planet.colorValue).withValues(alpha: 0.6),
                    blurRadius: ds.px(8),
                  ),
                ],
              ),
            ),
            SizedBox(height: ds.px(8)),
            Text(
              planet.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ds.font(16),
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      child: const SizedBox.shrink(),
    );
  }
}
