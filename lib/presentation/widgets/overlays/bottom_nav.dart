import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../theme/app_theme.dart';

class ExplorerBottomNav extends ConsumerWidget {
  const ExplorerBottomNav({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    final completed = ui.missions.where((m) => m.completed).length;
    return SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 14), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppTheme.space800.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
      child: Row(children: [
        _NavItem(icon: Icons.explore, label: 'Explore', selected: ui.tab == ExplorerTab.explore, onTap: () => notifier.setTab(ExplorerTab.explore)),
        _NavItem(icon: Icons.science_rounded, label: 'Playground', selected: ui.tab == ExplorerTab.playground, onTap: () => notifier.setTab(ExplorerTab.planets)),
        _NavItem(icon: Icons.emoji_events, label: 'Missions', badge: completed > 0 ? '$completed' : null,
          selected: ui.tab == ExplorerTab.missions, onTap: () => notifier.setTab(ExplorerTab.missions)),
      ]))));
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.badge});
  final IconData icon; final String label; final bool selected; final VoidCallback onTap; final String? badge;
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(color: selected ? AppTheme.accentViolet.withValues(alpha: 0.95) : Colors.transparent, borderRadius: BorderRadius.circular(18)),
      child: Stack(alignment: Alignment.center, children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 21, color: Colors.white),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
        if (badge != null) Positioned(right: 22, top: 0, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.rectangle, borderRadius: BorderRadius.all(Radius.circular(10))),
          child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))))
      ]))));
  }
}
