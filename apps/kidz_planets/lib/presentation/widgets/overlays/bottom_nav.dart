import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/l10n.dart';
import 'package:core/layout.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';
import 'package:kidz_planets/presentation/tv/tv_nav_target.dart';
import 'package:kidz_planets/application/state/providers.dart';

class ExplorerBottomNav extends ConsumerWidget {
  const ExplorerBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(appShellProvider.select((s) => s.tab));
    final isTv = ref.watch(isTelevisionProvider);
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
            id: 'chrome:tab-explore',
            icon: Icons.public,
            label: t.navExplore,
            selected: tab == AppTab.explore,
            isTv: isTv,
            onTap: () =>
                ref.read(appShellProvider.notifier).setTab(AppTab.explore),
          ),
          _NavItem(
            id: 'chrome:tab-playground',
            icon: Icons.science_outlined,
            label: t.navPlayground,
            selected: tab == AppTab.playground,
            isTv: isTv,
            onTap: () =>
                ref.read(appShellProvider.notifier).setTab(AppTab.playground),
          ),
          _NavItem(
            id: 'chrome:tab-missions',
            icon: Icons.rocket_launch_outlined,
            label: t.navMissions,
            selected: tab == AppTab.missions,
            isTv: isTv,
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
    required this.id,
    required this.icon,
    required this.label,
    required this.selected,
    required this.isTv,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final String label;
  final bool selected;
  final bool isTv;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // One gesture owner per platform: touch wraps the row in its own
    // detector; on TV the TvNavTarget's focusable owns tap (a second nested
    // detector would still work — the arena fires the inner one — but two
    // owners for one button is how focus bugs hide).
    final body = AnimatedContainer(
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
    );
    return Expanded(
      child: isTv
          ? TvNavTarget(
              id: id,
              control: TvChromeControl.other,
              onSelect: onTap,
              child: body,
            )
          : GestureDetector(onTap: onTap, child: body),
    );
  }
}
