import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission/state.dart';
import 'package:core/l10n.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';

class MissionsPanel extends ConsumerWidget {
  const MissionsPanel({super.key, this.onOpenMission});

  /// Switches to the explore tab and focuses the body a mission is asking for.
  ///
  /// A callback because both actions belong to the application shell: the tab
  /// is shell state, and focusing a body is the planets feature's business.
  final void Function(String planetId)? onOpenMission;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(missionProgressProvider);
    final completed = ui.missions.where((m) => m.completed).length;
    final activeId = ui.activeMissionId;
    // First control takes focus on TV so the tab is usable the moment it
    // opens: the remote would otherwise have nowhere to go.
    final entryFocus = ref.watch(isTelevisionProvider);
    final progress = ui.missions.isEmpty ? 0.0 : completed / ui.missions.length;
    final t = AppLocalizations.of(context);
    return AppTheme.glass(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.rocket_launch,
                            color: AppTheme.accentSky,
                            size: 18,
                          ),
                          SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              t.spaceMissions,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text(
                        t.spaceMissionsSubtitle,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF9CA9D8),
                        ),
                      ),
                    ],
                  ),
                ),
                AppTheme.glass(
                  pill: true,
                  radius: BorderRadius.circular(999),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        size: 11,
                        color: AppTheme.accentAmber,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        t.missionCount(completed, ui.missions.length),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Container(
                height: 9,
                color: AppTheme.space800,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accentIndigo, AppTheme.accentAmber],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...ui.missions.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: m.completed
                        ? const Color(0x1A22C55E)
                        : m.id == activeId
                        ? const Color(0x223B82F6)
                        : AppTheme.space800.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: m.completed
                          ? const Color(0x6622C55E)
                          : m.id == activeId
                          ? AppTheme.accentSky.withValues(alpha: .65)
                          : Colors.white.withValues(alpha: .10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: m.completed
                              ? const Color(0x3322C55E)
                              : const Color(0x334F46E5),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: m.completed
                                ? const Color(0x6622C55E)
                                : const Color(0x664F46E5),
                          ),
                        ),
                        child: m.completed
                            ? const Icon(
                                Icons.check,
                                size: 15,
                                color: Color(0xFF86EFAC),
                              )
                            : Text(
                                m.id.toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFC7D2FE),
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.title,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.description,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TvFocusable(
                        autofocus: entryFocus && m.id == activeId,
                        onSelect: m.completed || m.id != activeId
                            ? null
                            : () {
                                onOpenMission?.call(m.targetPlanetId);
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: m.completed
                                ? const Color(0x3322C55E)
                                : AppTheme.accentIndigo,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            m.completed
                                ? t.missionStatusDone
                                : m.id == activeId
                                ? t.missionStatusActive
                                : t.missionStatusLocked,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: m.completed
                                  ? const Color(0xFF86EFAC)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
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
