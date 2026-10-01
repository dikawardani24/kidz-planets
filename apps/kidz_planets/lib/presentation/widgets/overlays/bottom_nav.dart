import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';

/// The gap between the bottom of the nav and the bottom of the screen.
const double bottomNavMargin = 18;

/// The nav's own height, excluding [bottomNavMargin].
///
/// The companion has to stay clear of the nav, and it lives in the same stack,
/// so it needs to know how much room the nav takes. Deriving it from the nav's
/// own numbers rather than writing a number next to them is what keeps the two
/// from drifting apart: change a padding here and the reserve the companion
/// keeps changes with it. `companion_safe_area_test` then measures the nav as it
/// is really laid out and fails if the sum below is wrong, which catches the
/// parts that cannot be derived from a constant at all.
///
/// Assumes the default text scale. A larger one makes the labels taller than
/// the icons, and the nav grows; that would need the height measured at runtime
/// rather than reserved.
const double bottomNavExtent =
    _navVerticalPadding * 2 +
    _navItemVerticalPadding * 2 +
    _navItemIconSize +
    _glassBorderWidth * 2;

const double _navVerticalPadding = 7;
const double _navItemVerticalPadding = 10;
const double _navItemIconSize = 18;
const double _glassBorderWidth = 1;

class ExplorerBottomNav extends ConsumerWidget {
  const ExplorerBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    final t = AppLocalizations.of(context);
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    final nav = AppTheme.glass(
      pill: true,
      radius: BorderRadius.circular(999),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: _navVerticalPadding,
      ),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.public,
            label: t.navExplore,
            selected: ui.tab == ExplorerTab.explore,
            onTap: () => notifier.setTab(ExplorerTab.explore),
          ),
          _NavItem(
            icon: Icons.science_outlined,
            label: t.navPlayground,
            selected: ui.tab == ExplorerTab.playground,
            onTap: () => notifier.setTab(ExplorerTab.playground),
          ),
          _NavItem(
            icon: Icons.rocket_launch_outlined,
            label: t.navMissions,
            selected: ui.tab == ExplorerTab.missions,
            onTap: () => notifier.setTab(ExplorerTab.missions),
          ),
        ],
      ),
    );

    return Positioned(
      left: isLandscape ? null : 16,
      right: isLandscape ? null : 16,
      bottom: bottomNavMargin,
      child: isLandscape ? SizedBox(width: 460, child: nav) : nav,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: _navItemVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentIndigo : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x664F46E5), blurRadius: 10)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: _navItemIconSize, color: Colors.white),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
