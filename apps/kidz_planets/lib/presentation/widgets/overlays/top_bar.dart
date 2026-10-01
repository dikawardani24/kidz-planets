import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/locale_controller.dart';
import '../../../application/state/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../panels/mission_guide.dart';

class ExplorerTopBar extends ConsumerWidget {
  const ExplorerTopBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    final t = AppLocalizations.of(context);
    return SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(children: [
        Flexible(
          child: AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 28, height: 28, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFF4F46E5)])),
                alignment: Alignment.center, child: const Icon(Icons.wb_sunny, size: 14, color: Colors.white)),
              const SizedBox(width: 8),
              Flexible(child: Text(t.topBarTitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: .2, color: Colors.white))),
            ])),
        ),
        const SizedBox(width: 8),
        LanguageButton(),
        const SizedBox(width: 6),
        Tooltip(
          message: ui.showLabels ? t.tooltipHideLabels : t.tooltipShowLabels,
          child: _CircleButton(
            icon: ui.showLabels ? Icons.label_outline : Icons.label_off_outlined,
            color: ui.showLabels ? AppTheme.accentAmber : Colors.white54,
            onTap: notifier.toggleLabels,
          ),
        ),
        const SizedBox(width: 6),
        _CircleButton(
          icon: ui.running ? Icons.pause : Icons.play_arrow,
          color: AppTheme.accentSky,
          onTap: notifier.toggleRunning,
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: ui.showOrbits ? t.tooltipHideOrbits : t.tooltipShowOrbits,
          child: _CircleButton(
            icon: ui.showOrbits ? Icons.track_changes : Icons.track_changes_outlined,
            color: ui.showOrbits ? AppTheme.accentViolet : Colors.white54,
            onTap: notifier.toggleOrbits,
          ),
        ),
      ]),
    ));
  }
}

/// Language picker. Deliberately a top-bar circle button rather than a
/// settings screen: the audience is pre-literate and has to reach language
/// in one tap, and the top bar is the only chrome visible in every tab.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final chosen = ref.watch(localeControllerProvider);
    final current = ref.watch(localeControllerProvider.notifier).resolve(Localizations.localeOf(context));
    return Tooltip(
      message: t.tooltipLanguage,
      child: PopupMenuButton<String>(
        tooltip: '',
        onSelected: (code) => ref.read(localeControllerProvider.notifier).select(Locale(code)),
        color: AppTheme.space800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        itemBuilder: (context) => [
          for (final (code, label) in [('en', t.languageEnglish), ('id', t.languageIndonesian)])
            PopupMenuItem(value: code, child: Text(label, style: TextStyle(color: Colors.white, fontWeight: chosen?.languageCode == code ? FontWeight.w900 : FontWeight.w500))),
        ],
        child: _CircleButton(
          icon: Icons.translate_rounded,
          color: current.languageCode == 'id' ? AppTheme.accentAmber : Colors.white70,
          // A dot on the button is the only signal a pre-literate child gets
          // that the app is not speaking their language.
          badge: current.languageCode == 'id',
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.color, this.onTap, this.badge = false});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  /// Draws a small marker in the corner, used to show the active language.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.38),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        alignment: Alignment.center,
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(icon, size: 18, color: color),
          if (badge)
            Positioned(right: -4, top: -4, child: Container(
              width: 9, height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentAmber, border: Border.all(color: Colors.black.withValues(alpha: .5), width: 1)),
            )),
        ]),
      ),
    );
  }
}

/// Vertical space the top bar occupies below the safe-area inset:
/// 10px top padding + 38px controls + 2px bottom padding.
const double topBarExtent = 50;

/// Y offset for banners that must sit below the top bar, so they stay clear
/// of it on devices with a status bar or notch.
double bannerTop(BuildContext context) =>
    MediaQuery.paddingOf(context).top + topBarExtent;

class ExplorerInteractionOverlays extends ConsumerWidget {
  const ExplorerInteractionOverlays({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final t = AppLocalizations.of(context);
    final top = bannerTop(context);
    if (ui.hasSelection && ui.spinHintVisible) {
      return _Banner(top: top + 14, borderColor: const Color(0x66F59E0B), background: const Color(0xD9040712), textColor: const Color(0xFFFFE7A3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text(t.bannerSwipeToSpin), const SizedBox(width: 8), const Text('•', style: TextStyle(color: AppTheme.accentViolet)), const SizedBox(width: 8), Text(t.bannerZoom)]));
    }
    if (ui.playModeBannerVisible) {
      return _Banner(top: top + 14, borderColor: const Color(0x80F59E0B), background: const Color(0xE6040712), textColor: const Color(0xFFFFE7A3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.gamepad, size: 13, color: AppTheme.accentAmber), const SizedBox(width: 6), Text(t.bannerPlayMode)]));
    }
    if (!ui.hasSelection && ui.tab == ExplorerTab.explore) {
      // The same getter the companion uses, so the banner and the target ring
      // can never disagree. Recomputing it here by id alone would keep naming a
      // mission the child has already finished.
      final activeMission = ui.activeMission;
      if (activeMission != null) {
        return _Banner(
          top: top + 8,
          interactive: true,
          onTap: () => showMissionDialog(context, ref),
          borderColor: const Color(0x665B8CFF),
          background: const Color(0xD9040712),
          textColor: const Color(0xFFD9E4FF),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore, size: 13, color: AppTheme.accentSky),
              const SizedBox(width: 7),
              Text(t.bannerMission(activeMission.id, activeMission.title)),
            ],
          ),
        );
      }
      return _Banner(
        top: top + 12,
        borderColor: const Color(0x664F46E5),
        background: const Color(0xBF010206),
        textColor: const Color(0xDDBFC6FF),
        child: Text(t.bannerAllExplored),
      );
    }
    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.top,
    required this.borderColor,
    required this.background,
    required this.textColor,
    required this.child,
    this.interactive = false,
    this.onTap,
  });

  final double top;
  final Color borderColor;
  final Color background;
  final Color textColor;
  final Widget child;
  final bool interactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Positioned(
    top: top,
    left: 0,
    right: 0,
    child: Center(
      child: GestureDetector(
        onTap: interactive ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)],
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w700),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class ExplorerControlPills extends ConsumerWidget {
  const ExplorerControlPills({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    final t = AppLocalizations.of(context);
    return AppTheme.glass(pill: true, radius: BorderRadius.circular(999), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.speed, size: 14, color: AppTheme.accentSky),
        SizedBox(width: 105, child: Slider(value: ui.speed.clamp(0, 4), min: 0, max: 4, divisions: 8, activeColor: AppTheme.accentAmber, inactiveColor: Colors.white24, onChanged: notifier.setSpeed)),
        Text(t.speedLabel(ui.speed.toStringAsFixed(1)), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.accentAmber)),
        const SizedBox(width: 6),
      ]));
  }
}
