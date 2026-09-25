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
    return Positioned(left: 16, right: 16, bottom: 12, child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: Row(children: [
        _NavItem(icon: Icons.public, label: 'Explore', selected: ui.tab == ExplorerTab.explore, onTap: () => notifier.setTab(ExplorerTab.explore)),
        _NavItem(icon: Icons.science_outlined, label: 'Playground', selected: ui.tab == ExplorerTab.playground, onTap: () => notifier.setTab(ExplorerTab.playground)),
        _NavItem(icon: Icons.rocket_launch_outlined, label: 'Missions', selected: ui.tab == ExplorerTab.missions, onTap: () => notifier.setTab(ExplorerTab.missions)),
      ])));
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon; final String label; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: selected ? AppTheme.accentIndigo : Colors.transparent, borderRadius: BorderRadius.circular(999), boxShadow: selected ? const [BoxShadow(color: Color(0x664F46E5), blurRadius: 10)] : null),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 15, color: Colors.white), const SizedBox(width: 7),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white))),
    ]))));
}
