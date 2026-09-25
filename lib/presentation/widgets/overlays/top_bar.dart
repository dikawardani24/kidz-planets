import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../theme/app_theme.dart';

class ExplorerTopBar extends ConsumerWidget {
  const ExplorerTopBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    return SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Row(children: [
        AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 28, height: 28, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFF4F46E5)])),
              alignment: Alignment.center, child: const Icon(Icons.wb_sunny, size: 14, color: Colors.white)),
            const SizedBox(width: 10),
            const Text('NASA Space Explorer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: .2, color: Colors.white)),
          ])),
        const Spacer(),
        _CircleButton(icon: ui.running ? Icons.pause : Icons.play_arrow, color: AppTheme.accentSky, onTap: notifier.toggleRunning),
        const SizedBox(width: 8),
        const _CircleButton(icon: Icons.emoji_people, color: AppTheme.accentAmber),
      ]),
    ));
  }
}

class ExplorerInteractionOverlays extends ConsumerWidget {
  const ExplorerInteractionOverlays({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    if (ui.hasSelection && ui.spinHintVisible) {
      return const _Banner(top: 64, borderColor: Color(0x66F59E0B), background: Color(0xD9040712), textColor: Color(0xFFFFE7A3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text('👆 Swipe to spin'), SizedBox(width: 8), Text('•', style: TextStyle(color: AppTheme.accentViolet)), SizedBox(width: 8), Text('🤏 Pinch or +/- to zoom')]));
    }
    if (ui.playModeBannerVisible) {
      return const _Banner(top: 64, borderColor: Color(0x80F59E0B), background: Color(0xE6040712), textColor: Color(0xFFFFE7A3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.gamepad, size: 13, color: AppTheme.accentAmber), SizedBox(width: 6), Text('Play Mode Active: Spin & explore freely!')]));
    }
    if (!ui.hasSelection && ui.tab == ExplorerTab.explore) {
      return const _Banner(top: 62, borderColor: Color(0x664F46E5), background: Color(0xBF010206), textColor: Color(0xDDBFC6FF),
        child: Text('✨ Tap the Sun or any planet to inspect NASA 3D details'));
    }
    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.top, required this.borderColor, required this.background, required this.textColor, required this.child});
  final double top; final Color borderColor; final Color background; final Color textColor; final Widget child;
  @override
  Widget build(BuildContext context) => Positioned(top: top, left: 0, right: 0, child: IgnorePointer(child: Center(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999), border: Border.all(color: borderColor), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)]),
    child: DefaultTextStyle(style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: textColor), child: child),
  ))));
}

class ExplorerDetailHud extends ConsumerWidget {
  const ExplorerDetailHud({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    if (!ui.hasSelection) return const SizedBox.shrink();
    final percent = (100 / ui.detailZoom).round();
    return Positioned(top: 76, right: 14, child: Column(children: [
      _HudButton(icon: Icons.zoom_in, onTap: () => notifier.adjustDetailZoom(-.25)),
      const SizedBox(height: 8),
      AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(percent.toString() + '%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.accentAmber))),
      const SizedBox(height: 8),
      _HudButton(icon: Icons.zoom_out, onTap: () => notifier.adjustDetailZoom(.25)),
      const SizedBox(height: 8),
      _HudButton(icon: ui.detailCardVisible ? Icons.info_outline : Icons.visibility_off, iconColor: ui.detailCardVisible ? AppTheme.accentSky : AppTheme.accentAmber, onTap: notifier.toggleDetailCard),
      const SizedBox(height: 8),
      _HudButton(icon: Icons.refresh, small: true, onTap: notifier.resetDetailView),
    ]));
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({required this.icon, required this.onTap, this.iconColor = Colors.white, this.small = false});
  final IconData icon; final VoidCallback onTap; final Color iconColor; final bool small;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999),
    padding: EdgeInsets.all(small ? 9 : 10), child: Icon(icon, size: small ? 14 : 18, color: iconColor)));
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.color = Colors.white, this.onTap});
  final IconData icon; final Color color; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.all(9),
    child: Icon(icon, size: 15, color: color)));
}

class ExplorerControlPills extends ConsumerWidget {
  const ExplorerControlPills({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    return AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.speed, size: 14, color: AppTheme.accentSky),
        SizedBox(width: 105, child: Slider(value: ui.speed.clamp(0, 4), min: 0, max: 4, divisions: 8, activeColor: AppTheme.accentAmber, inactiveColor: Colors.white24, onChanged: notifier.setSpeed)),
        Text(ui.speed.toStringAsFixed(1) + 'x', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.accentAmber)),
        const SizedBox(width: 6),
        _MiniToggle(label: 'Orbits', active: ui.showOrbits, onTap: notifier.toggleOrbits),
        const SizedBox(width: 5),
        _MiniToggle(label: 'Labels', active: ui.showLabels, onTap: notifier.toggleLabels),
      ]));
  }
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({required this.label, required this.active, required this.onTap});
  final String label; final bool active; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(color: active ? AppTheme.accentViolet.withValues(alpha: .55) : Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: .10))),
    child: Text(label + ': ' + (active ? 'On' : 'Off'), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white))));
}
