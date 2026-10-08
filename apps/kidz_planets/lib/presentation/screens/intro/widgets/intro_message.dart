import 'package:flutter/material.dart';

import 'package:core/layout.dart';
import 'package:core/l10n.dart';
import 'package:core/platform.dart';

/// The glass message card under the bar: the quoted status line.
///
/// The prototype's `loading-message-box` — a glass card holding the current
/// line in quotes (e.g. `"Waking up the Sun... ☀️"`), swapped as phases
/// change. A `ValueKey` on the message replays a short fade/slide on every
/// phase change, the Flutter analogue of the prototype's `transition-all`.
class IntroMessage extends StatelessWidget {
  const IntroMessage({super.key, required this.message});

  /// The full quoted line to show.
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ds = DesignScale.sharedOf(context);
    return Container(
      key: ValueKey(message),
      width: double.infinity,
      padding: ds.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
      ),
      child: Text(
        t.introMessage(message),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: ds.font(13),
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF3E8FF),
        ),
      ),
    );
  }
}

/// The kid-friendly failure card: what went wrong, and the retry button.
///
/// The prototype has no error state (its loading bar cannot fail), so this
/// follows the task brief's `🚀 Oh no!` sketch in the same glass language:
/// a rocket, one plain sentence (never an exception), and a big `TRY AGAIN`
/// pill. Local copy comes from the ARB `introError*` keys.
class IntroError extends StatelessWidget {
  const IntroError({super.key, required this.onRetry, this.autofocus = false});

  final VoidCallback onRetry;

  /// Takes focus on arrival so the remote's OK retries without a touchscreen.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ds = DesignScale.sharedOf(context);
    return Container(
      width: double.infinity,
      padding: ds.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: const Color(0xFFF87171).withValues(alpha: 0.4),
        ),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🚀', style: TextStyle(fontSize: ds.font(40))),
          SizedBox(height: ds.px(8)),
          Text(
            t.introErrorTitle,
            style: TextStyle(
              fontSize: ds.font(18),
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: ds.px(4)),
          Text(
            t.introErrorBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ds.font(12),
              color: const Color(0xFFD8B4FE),
            ),
          ),
          SizedBox(height: ds.px(12)),
          TvFocusable(
            autofocus: autofocus,
            onSelect: onRetry,
            child: Container(
              padding: ds.insets(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x664F46E5),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Text(
                '🔄 ${t.introRetry}',
                style: TextStyle(
                  fontSize: ds.font(13),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
