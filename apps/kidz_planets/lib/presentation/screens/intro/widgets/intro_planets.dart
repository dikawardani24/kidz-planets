import 'package:flutter/material.dart';

import 'package:core/l10n.dart';

import '../../../../application/startup/intro_copy.dart';

/// Milestone badges that pop onto the orbit ring as progress lands.
///
/// The prototype reveals three glass badges at fixed points of the bar —
/// Earth at 25%, Moon at 48%, Saturn at 68% — each with a springy `popIn`.
/// Visibility derives from the bar fraction (not from task identity) so the
/// pop-ins stay on the same beats even if a task's weight is retuned.
class IntroPlanets extends StatelessWidget {
  const IntroPlanets({
    super.key,
    required this.progress,
    required this.seenMilestones,
  });

  /// Overall startup progress, 0..1.
  final double progress;

  /// Milestones already revealed once; kept so a badge that popped in never
  /// pops out when the bar pauses (the prototype leaves revealed milestones
  /// on screen, and only adds the stragglers at completion).
  final Set<IntroMilestone> seenMilestones;

  /// Bar fraction that reveals Earth, from the prototype's 25% trigger.
  @visibleForTesting
  static const double earthAt = 0.25;

  /// Bar fraction that reveals the Moon, from the prototype's 48% trigger.
  @visibleForTesting
  static const double moonAt = 0.48;

  /// Bar fraction that reveals Saturn, from the prototype's 68% trigger.
  @visibleForTesting
  static const double saturnAt = 0.68;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Stack(
      children: [
        Center(child: _OrbitRing(diameter: 176, alpha: 0.10)),
        Center(child: _OrbitRing(diameter: 288, alpha: 0.05)),
        if (_visible(IntroMilestone.earth))
          _MilestoneBadge(
            alignment: const Alignment(0.85, -0.9),
            emoji: IntroCopy.milestoneEmoji[IntroMilestone.earth]!,
            label: t.introMilestoneEarth,
            border: Colors.blue.shade300,
          ),
        if (_visible(IntroMilestone.moon))
          _MilestoneBadge(
            alignment: const Alignment(-0.9, 0.75),
            emoji: IntroCopy.milestoneEmoji[IntroMilestone.moon]!,
            label: t.introMilestoneMoon,
            border: Colors.grey.shade300,
          ),
        if (_visible(IntroMilestone.saturn))
          _MilestoneBadge(
            alignment: const Alignment(-0.8, -0.95),
            emoji: IntroCopy.milestoneEmoji[IntroMilestone.saturn]!,
            label: t.introMilestoneSaturn,
            border: Colors.yellow.shade300,
          ),
      ],
    );
  }

  bool _visible(IntroMilestone milestone) {
    if (seenMilestones.contains(milestone)) return true;
    return switch (milestone) {
      IntroMilestone.earth => progress >= earthAt,
      IntroMilestone.moon => progress >= moonAt,
      IntroMilestone.saturn => progress >= saturnAt,
    };
  }
}

/// One dashed-look orbit circle, drawn as a thin bordered ring.
class _OrbitRing extends StatelessWidget {
  const _OrbitRing({required this.diameter, required this.alpha});

  final double diameter;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: alpha)),
    ),
  );
}

/// One glass badge: emoji + name, springing in with the prototype's `popIn`.
class _MilestoneBadge extends StatefulWidget {
  const _MilestoneBadge({
    required this.alignment,
    required this.emoji,
    required this.label,
    required this.border,
  });

  final Alignment alignment;
  final String emoji;
  final String label;
  final Color border;

  @override
  State<_MilestoneBadge> createState() => _MilestoneBadgeState();
}

class _MilestoneBadgeState extends State<_MilestoneBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    // `popIn`: 0.5s overshooting scale, played once when the badge appears.
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: widget.alignment,
    child: ScaleTransition(
      scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
      child: FadeTransition(
        opacity: _pop,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: widget.border.withValues(alpha: 0.4)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Which milestones the current bar fraction has earned.
///
/// Pure function over the same thresholds the widget uses, so tests can
/// assert the reveal schedule without pumping frames.
Set<IntroMilestone> milestonesForProgress(double progress) {
  final seen = <IntroMilestone>{};
  if (progress >= IntroPlanets.earthAt) seen.add(IntroMilestone.earth);
  if (progress >= IntroPlanets.moonAt) seen.add(IntroMilestone.moon);
  if (progress >= IntroPlanets.saturnAt) seen.add(IntroMilestone.saturn);
  return seen;
}
