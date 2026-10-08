import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/layout.dart';
import 'package:core/l10n.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:planets/state.dart';

import 'tv_providers.dart';

/// TV replacement for the bottom pill nav: three large remote-first entries.
///
/// Large cards, large type, one [TvFocusContainer] so traversal starts in a
/// sensible place and can never leave the bar unexpectedly.
class TvNavBar extends ConsumerWidget {
  const TvNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(appShellProvider.select((s) => s.tab));
    final t = AppLocalizations.of(context);

    /// Returning to explore with empty hands lands on home, not on an empty
    /// scene with no obvious next step.
    void goExplore() {
      ref.read(appShellProvider.notifier).setTab(AppTab.explore);
      if (!ref.read(explorerControllerProvider).hasSelection) {
        ref.read(tvExplorerControllerProvider.notifier).showHome();
      }
    }

    // Margin from constraints, not a fixed guess: 3% of the width with a
    // scaled floor, so overscan never eats the bar on small TVs.
    final ds = DesignScale.tvOf(context);
    final edge = math.max(MediaQuery.sizeOf(context).width * 0.03, ds.px(20));

    return Positioned(
      left: 0,
      right: 0,
      bottom: edge,
      child: Center(
        child: TvFocusContainer(
          autofocusFirst: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TvNavButton(
                icon: Icons.public,
                label: t.navExplore,
                selected: tab == AppTab.explore,
                onSelect: goExplore,
              ),
              SizedBox(width: ds.px(20)),
              _TvNavButton(
                icon: Icons.science_outlined,
                label: t.navPlayground,
                selected: tab == AppTab.playground,
                onSelect: () => ref
                    .read(appShellProvider.notifier)
                    .setTab(AppTab.playground),
              ),
              SizedBox(width: ds.px(20)),
              _TvNavButton(
                icon: Icons.rocket_launch_outlined,
                label: t.navMissions,
                selected: tab == AppTab.missions,
                onSelect: () =>
                    ref.read(appShellProvider.notifier).setTab(AppTab.missions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvNavButton extends StatelessWidget {
  const _TvNavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    // Authored at the 1080p reference; the scale derives 720p/4K from the
    // same numbers, so proportions hold on every TV size.
    final ds = DesignScale.tvOf(context);
    return TvFocusable(
      onSelect: onSelect,
      scaleOnFocus: false,
      builder: (_, focused, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: ds.insets(horizontal: 36, vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentIndigo
              : AppTheme.space700.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(ds.radius(24)),
          border: Border.all(
            color: tvCardBorder(focused: focused),
            width: ds.px(focused ? 4 : 2),
          ),
          boxShadow: [
            if (focused)
              BoxShadow(
                color: AppTheme.accentAmber.withValues(alpha: 0.45),
                blurRadius: ds.px(22),
                spreadRadius: ds.px(2),
              ),
            if (selected && !focused)
              const BoxShadow(color: Color(0x664F46E5), blurRadius: 14),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: ds.px(30), color: Colors.white),
            SizedBox(width: ds.px(12)),
            Text(
              label,
              style: TextStyle(
                fontSize: ds.font(22),
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
