import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/l10n.dart';
import 'package:core/layout.dart';
import 'package:core/theme.dart';
import 'package:kidz_planets/application/state/providers.dart';

class ExplorerBottomNav extends ConsumerWidget {
  const ExplorerBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(appShellProvider.select((s) => s.tab));
    final t = AppLocalizations.of(context);
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    final nav = AppTheme.glass(
      pill: true,
      radius: BorderRadius.circular(999),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: kNavVerticalPadding,
      ),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.public,
            label: t.navExplore,
            selected: tab == AppTab.explore,
            onTap: () =>
                ref.read(appShellProvider.notifier).setTab(AppTab.explore),
          ),
          _NavItem(
            icon: Icons.science_outlined,
            label: t.navPlayground,
            selected: tab == AppTab.playground,
            onTap: () =>
                ref.read(appShellProvider.notifier).setTab(AppTab.playground),
          ),
          _NavItem(
            icon: Icons.rocket_launch_outlined,
            label: t.navMissions,
            selected: tab == AppTab.missions,
            onTap: () =>
                ref.read(appShellProvider.notifier).setTab(AppTab.missions),
          ),
        ],
      ),
    );

    return Positioned(
      left: isLandscape ? null : 16,
      right: isLandscape ? null : 16,
      bottom: kBottomNavMargin,
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
          vertical: kNavItemVerticalPadding,
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
            Icon(icon, size: kNavItemIconSize, color: Colors.white),
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
