import 'package:flutter/material.dart';

import 'package:core/l10n.dart';

import '../../../application/startup/intro_copy.dart' show IntroMilestone;
import '../../../application/startup/startup_providers.dart'
    show StartupProgress, StartupStatus;
import 'intro_copy_resolver.dart';
import 'widgets/intro_completion_cta.dart';
import 'widgets/intro_message.dart';
import 'widgets/intro_planets.dart';
import 'widgets/intro_progress.dart';
import 'widgets/intro_rocket.dart';
import 'widgets/intro_space_fact.dart';

export 'intro_copy_resolver.dart';
export 'widgets/intro_planets.dart' show milestonesForProgress;

/// The scrollable intro column; split from the page so that file stays about
/// launch bookkeeping rather than layout.
class IntroBody extends StatelessWidget {
  const IntroBody({
    super.key,
    required this.progress,
    required this.seenMilestones,
    required this.launching,
    required this.onRetry,
    required this.onEnter,
  });

  final StartupProgress progress;
  final Set<IntroMilestone> seenMilestones;
  final bool launching;
  final VoidCallback onRetry;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final complete = progress.isReady;
    return Column(
      children: [
        _BrandPill(label: t.introBrandTag),
        const SizedBox(height: 8),
        Text(
          t.introTitle,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          // The prototype's `loading-subtitle` shows its "preparing" default
          // before the first tick, then follows `phase.sub`, and switches to
          // its welcome line at completion.
          progress.status == StartupStatus.idle
              ? t.introSubtitle
              : introSubtitleFor(progress.message, t),
          style: const TextStyle(fontSize: 13, color: Color(0xFFD8B4FE)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IntroPlanets(
                progress: progress.progress,
                seenMilestones: seenMilestones,
              ),
              IntroRocket(launching: launching),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (progress.hasFailed)
          IntroError(onRetry: onRetry)
        else ...[
          IntroProgress(
            progress: progress.progress,
            phase: complete
                ? t.introPhaseReady
                : introPhaseFor(progress.message, t),
            complete: complete,
          ),
          const SizedBox(height: 12),
          IntroMessage(
            message: complete
                ? t.introCompleteTitle
                : introMessageFor(progress.message, t),
          ),
        ],
        const SizedBox(height: 16),
        const IntroSpaceFact(),
        if (complete) ...[
          const SizedBox(height: 12),
          IntroCompletionCta(onEnter: onEnter),
        ],
      ],
    );
  }
}

/// The small sparkles pill above the title.
class _BrandPill extends StatelessWidget {
  const _BrandPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('✨', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFD8B4FE),
          ),
        ),
      ],
    ),
  );
}
