import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/l10n.dart';
import 'package:core/layout.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:kidz_planets/presentation/widgets/panels/mission_guide.dart';
import 'package:planets/state.dart';

/// The app's title strip and the transient banner above it.
///
/// Lives in the application package because the banner it shows is a mission's
/// and opens the mission dialog: it reads the planets state and the mission
/// state, and neither feature can read the other.
class ExplorerTopBar extends ConsumerWidget {
  const ExplorerTopBar({super.key, this.isExploreTab = true});

  /// Whether the explore space is the one on screen.
  ///
  /// Passed in rather than read from a provider, because the tab belongs to the
  /// shell and this widget belongs to neither feature.
  final bool isExploreTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    final t = AppLocalizations.of(context);
    // Visible TV-mode confirmation for support ("is the TV build active?").
    final isTv = ref.watch(isTelevisionProvider);
    // Every dimension derives from the viewport scale: phones render today's
    // pixels (factor 1.0), larger screens scale proportionally.
    final ds = DesignScale.sharedOf(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(ds.px(16), ds.px(10), ds.px(16), ds.px(2)),
        child: Row(
          children: [
            Flexible(
              child: AppTheme.glass(
                pill: true,
                radius: BorderRadius.circular(999),
                padding: ds.insets(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: ds.px(28),
                      height: ds.px(28),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFF59E0B),
                            Color(0xFFF97316),
                            Color(0xFF4F46E5),
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.wb_sunny,
                        size: ds.px(14),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: ds.px(8)),
                    Flexible(
                      child: Text(
                        t.topBarTitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ds.font(14),
                          fontWeight: FontWeight.w800,
                          letterSpacing: .2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isTv) ...[
                      SizedBox(width: ds.px(8)),
                      Container(
                        padding: ds.insets(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ds.radius(999)),
                          border: Border.all(
                            color: AppTheme.accentAmber,
                            width: ds.px(1.5),
                          ),
                        ),
                        child: Text(
                          'TV',
                          style: TextStyle(
                            fontSize: ds.font(10),
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentAmber,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(width: ds.px(8)),
            LanguageButton(),
            SizedBox(width: ds.px(6)),
            Tooltip(
              message: t.tooltipAvatar,
              child: _CircleButton(
                icon: Icons.person_rounded,
                color: Colors.white70,
                onTap: () =>
                    ref.read(appShellProvider.notifier).openAvatarPage(),
              ),
            ),
            SizedBox(width: ds.px(6)),
            Tooltip(
              message: ui.showLabels
                  ? t.tooltipHideLabels
                  : t.tooltipShowLabels,
              child: _CircleButton(
                icon: ui.showLabels
                    ? Icons.label_outline
                    : Icons.label_off_outlined,
                color: ui.showLabels ? AppTheme.accentAmber : Colors.white54,
                onTap: notifier.toggleLabels,
              ),
            ),
            SizedBox(width: ds.px(6)),
            _CircleButton(
              icon: ui.running ? Icons.pause : Icons.play_arrow,
              color: AppTheme.accentSky,
              onTap: notifier.toggleRunning,
            ),
            SizedBox(width: ds.px(6)),
            Tooltip(
              message: ui.showOrbits
                  ? t.tooltipHideOrbits
                  : t.tooltipShowOrbits,
              child: _CircleButton(
                icon: ui.showOrbits
                    ? Icons.track_changes
                    : Icons.track_changes_outlined,
                color: ui.showOrbits ? AppTheme.accentViolet : Colors.white54,
                onTap: notifier.toggleOrbits,
              ),
            ),
          ],
        ),
      ),
    );
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
    final current = ref
        .watch(localeControllerProvider.notifier)
        .resolve(Localizations.localeOf(context));
    return Tooltip(
      message: t.tooltipLanguage,
      child: PopupMenuButton<String>(
        tooltip: '',
        onSelected: (code) =>
            ref.read(localeControllerProvider.notifier).select(Locale(code)),
        color: AppTheme.space800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        itemBuilder: (context) => [
          for (final (code, label) in [
            ('en', t.languageEnglish),
            ('id', t.languageIndonesian),
          ])
            PopupMenuItem(
              value: code,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: chosen?.languageCode == code
                      ? FontWeight.w900
                      : FontWeight.w500,
                ),
              ),
            ),
        ],
        child: _CircleButton(
          icon: Icons.translate_rounded,
          color: current.languageCode == 'id'
              ? AppTheme.accentAmber
              : Colors.white70,
          // A dot on the button is the only signal a pre-literate child gets
          // that the app is not speaking their language.
          badge: current.languageCode == 'id',
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  /// Draws a small marker in the corner, used to show the active language.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    // One viewport-derived size: 38px on the reference phone, proportional
    // everywhere else. Circles stay circles at every scale.
    final ds = DesignScale.sharedOf(context);
    final extent = ds.px(38);
    // TvFocusable keeps touch taps identical while making every top-bar
    // control — labels, play/pause, orbits — reachable from the TV remote.
    return TvFocusable(
      onSelect: onTap,
      consumeDirectionalKeys: false,
      child: Container(
        width: extent,
        height: extent,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.38),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: ds.px(18), color: color),
            if (badge)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: ds.px(9),
                  height: ds.px(9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentAmber,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: .5),
                      width: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The transient banners that sit under the top bar: the spin hint, the play
/// mode notice and the active mission's cue.
class ExplorerInteractionOverlays extends ConsumerWidget {
  const ExplorerInteractionOverlays({super.key, required this.isExploreTab});

  /// Whether the explore space is the one on screen.
  ///
  /// Passed in because the tab belongs to the shell: the mission cue only makes
  /// sense while the solar system is behind it.
  final bool isExploreTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final t = AppLocalizations.of(context);
    // Scaled with the bar itself: fixed offsets would drift as the bar grows.
    final ds = DesignScale.sharedOf(context);
    final top = MediaQuery.paddingOf(context).top + ds.px(kTopBarExtent);
    if (ui.hasSelection && ui.spinHintVisible) {
      return _Banner(
        top: top + ds.px(14),
        borderColor: const Color(0x66F59E0B),
        background: const Color(0xD9040712),
        textColor: const Color(0xFFFFE7A3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.bannerSwipeToSpin),
            SizedBox(width: ds.px(8)),
            const Text('•', style: TextStyle(color: AppTheme.accentViolet)),
            SizedBox(width: ds.px(8)),
            Text(t.bannerZoom),
          ],
        ),
      );
    }
    if (ui.playModeBannerVisible) {
      return _Banner(
        top: top + ds.px(14),
        borderColor: const Color(0x80F59E0B),
        background: const Color(0xE6040712),
        textColor: const Color(0xFFFFE7A3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gamepad, size: ds.px(13), color: AppTheme.accentAmber),
            SizedBox(width: ds.px(6)),
            Text(t.bannerPlayMode),
          ],
        ),
      );
    }
    if (!ui.hasSelection && isExploreTab) {
      // The same getter the companion uses, so the banner and the target ring
      // can never disagree. Recomputing it here by id alone would keep naming a
      // mission the child has already finished.
      final activeMission = ref.watch(activeMissionProvider);
      if (activeMission != null) {
        return _Banner(
          top: top + ds.px(8),
          interactive: true,
          onTap: () => showMissionDialog(context, ref),
          borderColor: const Color(0x665B8CFF),
          background: const Color(0xD9040712),
          textColor: const Color(0xFFD9E4FF),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore, size: ds.px(13), color: AppTheme.accentSky),
              SizedBox(width: ds.px(7)),
              Text(t.bannerMission(activeMission.id, activeMission.title)),
            ],
          ),
        );
      }
      return _Banner(
        top: top + ds.px(12),
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
  Widget build(BuildContext context) {
    final ds = DesignScale.sharedOf(context);
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        // Focusable so the TV remote can open the mission; touch taps behave
        // exactly as before.
        child: TvFocusable(
          onSelect: interactive ? onTap : null,
          consumeDirectionalKeys: false,
          child: Container(
            padding: ds.insets(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(ds.radius(999)),
              border: Border.all(color: borderColor),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 14),
              ],
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: textColor,
                fontSize: ds.font(10),
                fontWeight: FontWeight.w700,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class ExplorerControlPills extends ConsumerWidget {
  const ExplorerControlPills({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);
    final t = AppLocalizations.of(context);
    final ds = DesignScale.sharedOf(context);
    return AppTheme.glass(
      pill: true,
      radius: BorderRadius.circular(ds.radius(999)),
      padding: ds.insets(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed, size: ds.px(14), color: AppTheme.accentSky),
          SizedBox(
            width: ds.px(105),
            child: Slider(
              value: ui.speed.clamp(0, 4),
              min: 0,
              max: 4,
              divisions: 8,
              activeColor: AppTheme.accentAmber,
              inactiveColor: Colors.white24,
              onChanged: notifier.setSpeed,
            ),
          ),
          Text(
            t.speedLabel(ui.speed.toStringAsFixed(1)),
            style: TextStyle(
              fontSize: ds.font(10),
              fontWeight: FontWeight.w800,
              color: AppTheme.accentAmber,
            ),
          ),
          SizedBox(width: ds.px(6)),
        ],
      ),
    );
  }
}
