import 'package:flutter/material.dart';

import 'package:core/layout.dart';
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
///
/// One composition, two arrangements: portrait stacks visual above progress,
/// landscape sets them side by side — a genuine orientation breakpoint, not
/// a per-device redesign. Every size derives from the viewport scale, so the
/// same design fits phones, tablets and every TV resolution proportionally.
/// [isTv] only decides initial focus (the remote needs a focused CTA), never
/// sizing.
class IntroBody extends StatelessWidget {
  const IntroBody({
    super.key,
    required this.progress,
    required this.seenMilestones,
    required this.launching,
    required this.onRetry,
    required this.onEnter,
    this.isTv = false,
  });

  final StartupProgress progress;
  final Set<IntroMilestone> seenMilestones;
  final bool launching;
  final VoidCallback onRetry;
  final VoidCallback onEnter;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width > size.height) return _landscape(context);
    return _portrait(context);
  }

  Widget _visual(BuildContext context, AppLocalizations t) {
    final ds = DesignScale.sharedOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandPill(label: t.introBrandTag),
        SizedBox(height: ds.px(8)),
        Text(
          t.introTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ds.font(28),
            fontWeight: FontWeight.w800,
            letterSpacing: ds.px(1.5),
            color: Colors.white,
          ),
        ),
        SizedBox(height: ds.px(4)),
        Text(
          // The prototype's `loading-subtitle` shows its "preparing" default
          // before the first tick, then follows `phase.sub`, and switches to
          // its welcome line at completion.
          progress.status == StartupStatus.idle
              ? t.introSubtitle
              : introSubtitleFor(progress.message, t),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ds.font(13),
            color: const Color(0xFFD8B4FE),
          ),
        ),
        SizedBox(height: ds.px(16)),
        SizedBox(
          height: ds.px(240),
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
      ],
    );
  }

  Widget _progressColumn(BuildContext context, AppLocalizations t) {
    final ds = DesignScale.sharedOf(context);
    final complete = progress.isReady;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (progress.hasFailed)
          IntroError(onRetry: onRetry, autofocus: isTv)
        else ...[
          IntroProgress(
            progress: progress.progress,
            phase: complete
                ? t.introPhaseReady
                : introPhaseFor(progress.message, t),
            complete: complete,
          ),
          SizedBox(height: ds.px(12)),
          IntroMessage(
            message: complete
                ? t.introCompleteTitle
                : introMessageFor(progress.message, t),
          ),
        ],
        SizedBox(height: ds.px(16)),
        const IntroSpaceFact(),
        if (complete) ...[
          SizedBox(height: ds.px(12)),
          IntroCompletionCta(onEnter: onEnter, autofocus: isTv),
        ],
      ],
    );
  }

  Widget _portrait(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ds = DesignScale.sharedOf(context);
    return Column(
      children: [
        _visual(context, t),
        SizedBox(height: ds.px(12)),
        _progressColumn(context, t),
      ],
    );
  }

  Widget _landscape(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ds = DesignScale.sharedOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _visual(context, t)),
        SizedBox(width: ds.px(56)),
        Expanded(child: _progressColumn(context, t)),
      ],
    );
  }
}

/// The small sparkles pill above the title.
class _BrandPill extends StatelessWidget {
  const _BrandPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ds = DesignScale.sharedOf(context);
    return Container(
      padding: ds.insets(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ds.radius(999)),
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('✨', style: TextStyle(fontSize: ds.font(12))),
          SizedBox(width: ds.px(6)),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ds.font(11),
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD8B4FE),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
