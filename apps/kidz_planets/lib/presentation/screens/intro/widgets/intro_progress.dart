import 'package:flutter/material.dart';

import 'package:core/layout.dart';
import 'package:core/l10n.dart';

/// The playful progress bar: phase label, percent, glowing gradient fill.
///
/// Mirrors the prototype's bar section — the `loading-phase-label` /
/// `loading-percent-label` row above a 16px rounded track, with the gradient
/// fill (`blue-500 → indigo-500 → yellow-400`), its glow, and the small
/// pulsing white light riding the fill's leading edge.
class IntroProgress extends StatelessWidget {
  const IntroProgress({
    super.key,
    required this.progress,
    required this.phase,
    required this.complete,
  });

  /// The prototype truncates the phase line at the first `...`
  /// (`phase.msg.split('...')[0]`), so the bar shows `Waking up the Sun`
  /// while the message card below keeps the full quoted sentence.
  static String truncatePhase(String phase) => phase.split('...').first;

  /// Overall startup progress, 0..1, from the coordinator's weighted sum.
  final double progress;

  /// The current phase line, e.g. `Waking up the Sun...`.
  final String phase;

  /// True once every required task finished: the label switches to the
  /// prototype's `100%` completion state.
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ds = DesignScale.sharedOf(context);
    final percent = (progress * 100).round().clamp(0, 100);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                truncatePhase(phase),
                style: TextStyle(
                  fontSize: ds.font(12),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD8B4FE),
                ),
              ),
            ),
            Text(
              t.introPercent(percent.toString()),
              style: TextStyle(
                fontSize: ds.font(14),
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFDE047),
              ),
            ),
          ],
        ),
        SizedBox(height: ds.px(8)),
        Container(
          height: ds.px(16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.black.withValues(alpha: 0.5),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF3B82F6),
                          Color(0xFF6366F1),
                          Color(0xFFFACC15),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFBB00).withValues(alpha: 0.6),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ),
                // The traveling star light on the fill's leading edge.
                if (!complete && progress > 0.02)
                  Positioned(
                    left: (constraints.maxWidth * progress - 12).clamp(
                      0.0,
                      constraints.maxWidth - 12,
                    ),
                    top: 0,
                    bottom: 0,
                    child: _TwinkleDot(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The small pulsing white light riding the bar's leading edge.
class _TwinkleDot extends StatefulWidget {
  @override
  State<_TwinkleDot> createState() => _TwinkleDotState();
}

class _TwinkleDotState extends State<_TwinkleDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.5, end: 1.0).animate(_pulse),
    child: Container(
      width: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
        boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 8)],
      ),
    ),
  );
}
