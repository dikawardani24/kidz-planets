import 'package:flutter/material.dart';

import 'package:core/layout.dart';
import 'package:core/l10n.dart';
import 'package:core/platform.dart';

/// The completion CTA: the prototype's bouncing gradient button.
///
/// Hidden until every required task finishes, then pops in (`popIn`) and
/// bounces gently until tapped — the prototype's `animate-bounce` on the
/// `LET'S EXPLORE!` button. The gradient (yellow → orange → pink), dark text
/// and glow match the mock; the bounce is a slow scale loop rather than a
/// translation so the button never overlaps its neighbours mid-bounce.
class IntroCompletionCta extends StatefulWidget {
  const IntroCompletionCta({
    super.key,
    required this.onEnter,
    this.autofocus = false,
  });

  final VoidCallback onEnter;

  /// Takes focus on arrival so the remote's OK enters without a touchscreen.
  ///
  /// Without this the TV stalls at 100%: the CTA is visible but no D-pad
  /// press can ever reach a bare `GestureDetector`.
  final bool autofocus;

  @override
  State<IntroCompletionCta> createState() => _IntroCompletionCtaState();
}

class _IntroCompletionCtaState extends State<IntroCompletionCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Viewport-derived sizing; touch and remote share the one button.
    final ds = DesignScale.sharedOf(context);
    // TvFocusable keeps the touch tap identical while letting the TV remote
    // activate the button through the focus system.
    return TvFocusable(
      autofocus: widget.autofocus,
      onSelect: widget.onEnter,
      child: ScaleTransition(
        scale: Tween(
          begin: 1.0,
          end: 1.04,
        ).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeInOut)),
        child: Container(
          width: double.infinity,
          padding: ds.insets(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFFACC15), Color(0xFFF97316), Color(0xFFEC4899)],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFA500).withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🚀', style: TextStyle(fontSize: ds.font(24))),
              SizedBox(width: ds.px(12)),
              Flexible(
                child: Text(
                  t.introEnterCta,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ds.font(18),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF020617),
                  ),
                ),
              ),
              SizedBox(width: ds.px(12)),
              Text('➡️', style: TextStyle(fontSize: ds.font(18))),
            ],
          ),
        ),
      ),
    );
  }
}
