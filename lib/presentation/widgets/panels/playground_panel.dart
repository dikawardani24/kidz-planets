import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/providers.dart';
import '../../../infrastructure/services/scene_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/resolve_message.dart';
import '../../theme/app_theme.dart';

class PlaygroundPanel extends ConsumerWidget {
  const PlaygroundPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    final scene = ref.read(solarSystemSceneControllerProvider);
    final t = AppLocalizations.of(context);

    void experiment(String id) {
      if (id == 'earth') scene.setPlanetOrbitRadius('earth', 8.0);
      notifier.runExperiment(id);
    }

    return AppTheme.glass(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.science, color: AppTheme.accentAmber, size: 18), SizedBox(width: 7), Flexible(child: Text(t.playgroundTitle, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)))]),
              SizedBox(height: 3),
              Text(t.playgroundSubtitle, style: TextStyle(fontSize: 10.5, color: Color(0xFF9CA9D8))),
            ])),
            GestureDetector(onTap: () { scene.setPlanetOrbitRadius('earth', 14.2); notifier.resetPlayground(); }, child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.refresh, size: 12, color: Colors.white70), SizedBox(width: 4), Text(t.reset, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white70))]))),
          ]),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppTheme.accentAmber.withValues(alpha: .10), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.accentAmber.withValues(alpha: .35))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ui.playgroundAlertIcon, style: const TextStyle(fontSize: 20)), const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ui.playgroundAlertTitle.resolve(t, Localizations.localeOf(context)), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFFFE7A3))),
              const SizedBox(height: 2), Text(ui.playgroundAlertDescription.resolve(t, Localizations.localeOf(context)), style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ])),
          ])),
          const SizedBox(height: 10),
          AppTheme.glass(radius: BorderRadius.circular(17), padding: const EdgeInsets.all(11), child: Column(children: [
            Row(children: [
              const Icon(Icons.speed, color: AppTheme.accentSky, size: 15), const SizedBox(width: 5),
              Text(t.orbitSpeed, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white70)),
              const Spacer(), Text(t.speedLabel(ui.speed.toStringAsFixed(1)), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.accentAmber)),
            ]),
            Slider(value: ui.speed.clamp(0, 4), min: 0, max: 4, divisions: 8, activeColor: AppTheme.accentAmber, inactiveColor: Colors.white24, onChanged: notifier.setSpeed),
            Row(children: [
              Expanded(child: _Toggle(label: t.toggleOrbits, active: ui.showOrbits, onTap: notifier.toggleOrbits)),
              const SizedBox(width: 7), Expanded(child: _Toggle(label: t.toggleLabels, active: ui.showLabels, onTap: notifier.toggleLabels)),
            ]),
          ])),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.auto_awesome, color: Color(0xFFA78BFA), size: 14), SizedBox(width: 6), Flexible(child: Text(t.experimentsTitle, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white70)))]),
          const SizedBox(height: 7),
          _Experiment(icon: '☀️', title: t.experimentSunTitle, subtitle: t.experimentSunSubtitle, onTap: () => experiment('sun')),
          _Experiment(icon: '🔥', title: t.experimentEarthTitle, subtitle: t.experimentEarthSubtitle, onTap: () => experiment('earth')),
          _Experiment(icon: '🪐', title: t.experimentSaturnTitle, subtitle: t.experimentSaturnSubtitle, onTap: () => experiment('saturn')),
          _Experiment(icon: '🌪️', title: t.experimentJupiterTitle, subtitle: t.experimentJupiterSubtitle, onTap: () => experiment('jupiter')),
        ]),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.active, required this.onTap});
  final String label; final bool active; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: active ? AppTheme.accentViolet.withValues(alpha: .5) : Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: .1))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(active ? Icons.check_circle : Icons.circle_outlined, size: 12, color: active ? AppTheme.accentAmber : Colors.white38),
        const SizedBox(width: 5), Flexible(child: Text('$label: ${active ? t.toggleOn : t.toggleOff}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
      ]),
    ));
  }
}

class _Experiment extends StatelessWidget {
  const _Experiment({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final String icon; final String title; final String subtitle; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: AppTheme.space800.withValues(alpha: .82), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withValues(alpha: .10))),
    child: Row(children: [
      Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.accentAmber.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)), child: Text(icon, style: const TextStyle(fontSize: 16))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 9.5, color: Colors.white60)),
      ])),
      const Icon(Icons.chevron_right, size: 16, color: Colors.white38),
    ]),
  ));
}
