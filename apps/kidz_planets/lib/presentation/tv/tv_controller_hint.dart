import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/layout.dart';
import 'package:core/l10n.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';
import 'package:planets/state.dart';

import 'tv_providers.dart';

/// The TV controller chrome: the visible mode indicator plus the hint bar.
///
/// The mode pill is always visible while exploring (the child must always
/// know what the D-pad currently controls); the hint text appears when
/// entering the Explorer, on every mode switch, and from the help button,
/// then fades away on its own so it never permanently covers the scene.
///
/// Positioned from viewport fractions and sized from the 1080p reference:
/// proportional on every TV size from one set of numbers.
class TvControllerChrome extends ConsumerWidget {
  const TvControllerChrome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tv = ref.watch(tvExplorerControllerProvider);
    final notifier = ref.read(tvExplorerControllerProvider.notifier);
    final running = ref.watch(
      explorerControllerProvider.select((s) => s.running),
    );
    final t = AppLocalizations.of(context);
    final isBrowse = tv.mode == TvControlMode.browse;
    final ds = DesignScale.tvOf(context);
    final viewport = MediaQuery.sizeOf(context);
    return Positioned(
      left: viewport.width * 0.03,
      bottom: viewport.height * 0.16,
      child: TvFocusContainer(
        autofocusFirst: false,
        // Shared identity with the BACK shuttle: this is the "chrome" side
        // BACK offers when the scene has empty hands.
        scopeNode: ref.watch(tvChromeScopeProvider),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              opacity: tv.hintVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !tv.hintVisible,
                child: Container(
                  padding: ds.insets(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.space950.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(ds.radius(18)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    isBrowse ? t.tvHintBrowse : t.tvHintRotate,
                    style: TextStyle(
                      fontSize: ds.font(20),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: ds.px(12)),
            Row(
              children: [
                TvFocusable(
                  onSelect: notifier.toggleMode,
                  child: Container(
                    padding: ds.insets(horizontal: 22, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppTheme.accentIndigo,
                      borderRadius: BorderRadius.circular(ds.radius(999)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBrowse ? Icons.explore : Icons.rotate_right,
                          size: ds.px(22),
                          color: Colors.white,
                        ),
                        SizedBox(width: ds.px(8)),
                        Text(
                          isBrowse ? t.tvModeBrowse : t.tvModeRotate,
                          style: TextStyle(
                            fontSize: ds.font(19),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: ds.px(10)),
                TvFocusable(
                  onSelect: () => ref
                      .read(explorerControllerProvider.notifier)
                      .toggleRunning(),
                  child: Container(
                    width: ds.px(52),
                    height: ds.px(52),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.space700.withValues(alpha: 0.92),
                      border: Border.all(
                        color: AppTheme.accentSky.withValues(alpha: 0.6),
                        width: ds.px(2),
                      ),
                    ),
                    child: Icon(
                      running ? Icons.pause : Icons.play_arrow,
                      size: ds.px(26),
                      color: AppTheme.accentSky,
                    ),
                  ),
                ),
                SizedBox(width: ds.px(10)),
                TvFocusable(
                  onSelect: notifier.showHint,
                  child: Container(
                    width: ds.px(52),
                    height: ds.px(52),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.space700.withValues(alpha: 0.92),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: ds.px(2),
                      ),
                    ),
                    child: Text(
                      '?',
                      style: TextStyle(
                        fontSize: ds.font(24),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
