import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/layout.dart';
import 'package:core/l10n.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';
import 'package:kidz_planets/application/state/providers.dart';

import 'tv_providers.dart';

/// The TV home screen: large landscape cards a child can drive with the
/// remote alone.
///
/// Shown on the explore tab until the child picks a destination or a body is
/// selected. BACK on this screen is a no-op (handled by the remote handler),
/// so a child cannot accidentally leave the app from here.
///
/// Every dimension is authored at the 1080p reference and derived from the
/// viewport scale: one set of numbers serves 720p, 1080p and 4K.
class TvHomePanel extends ConsumerWidget {
  const TvHomePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tv = ref.read(tvExplorerControllerProvider.notifier);
    final ds = DesignScale.tvOf(context);
    void dismiss() => tv.dismissHome();
    return Center(
      child: TvFocusContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.topBarTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ds.font(44),
                fontWeight: FontWeight.w900,
                letterSpacing: ds.px(3),
                color: Colors.white,
              ),
            ),
            SizedBox(height: ds.px(8)),
            Text(
              t.tvHomeSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ds.font(24),
                fontWeight: FontWeight.w600,
                color: const Color(0xFFC7D2FE),
              ),
            ),
            SizedBox(height: ds.px(36)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HomeCard(
                  autofocus: true,
                  emoji: '🪐',
                  label: t.sectionPlanets,
                  onSelect: () {
                    dismiss();
                    // Park the cursor on the first body so the very next OK
                    // selects something real instead of no-opping.
                    ref
                        .read(tvExplorerControllerProvider.notifier)
                        .ensureCursor();
                  },
                ),
                SizedBox(width: ds.px(24)),
                _HomeCard(
                  emoji: '🌙',
                  label: t.sectionMoons,
                  onSelect: () {
                    dismiss();
                    ref
                        .read(appShellProvider.notifier)
                        .setTab(AppTab.playground);
                  },
                ),
                SizedBox(width: ds.px(24)),
                _HomeCard(
                  emoji: '🚀',
                  label: t.spaceMissions,
                  onSelect: () {
                    dismiss();
                    ref.read(appShellProvider.notifier).setTab(AppTab.missions);
                  },
                ),
              ],
            ),
            SizedBox(height: ds.px(28)),
            TvFocusable(
              onSelect: dismiss,
              child: Container(
                padding: ds.insets(horizontal: 34, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.circular(ds.radius(999)),
                  ),
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentIndigo, Color(0xFF7C3AED)],
                  ),
                ),
                child: Text(
                  t.tvContinueExploring,
                  style: TextStyle(
                    fontSize: ds.font(20),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.emoji,
    required this.label,
    required this.onSelect,
    this.autofocus = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ds = DesignScale.tvOf(context);
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      scaleOnFocus: false,
      builder: (_, focused, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: ds.px(250),
        padding: ds.insets(vertical: 30),
        decoration: BoxDecoration(
          color: AppTheme.space700.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(ds.radius(28)),
          border: Border.all(
            color: tvCardBorder(focused: focused),
            width: ds.px(focused ? 5 : 2),
          ),
          boxShadow: [
            if (focused)
              BoxShadow(
                color: AppTheme.accentAmber.withValues(alpha: 0.45),
                blurRadius: ds.px(26),
                spreadRadius: ds.px(3),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: ds.font(56))),
            SizedBox(height: ds.px(12)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ds.font(24),
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
