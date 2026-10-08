import 'dart:async';

import 'package:flutter/material.dart';

import 'package:core/layout.dart';
import 'package:core/l10n.dart';

import '../../../../application/startup/intro_copy.dart';

/// The rotating space-fact card under the message box.
///
/// The prototype's fact card: a glass panel with a `SPACE FACT` tab in the
/// corner and one quoted fact, swapping every 4.5s with a fade. The timer
/// lives here (not in the page) so the rotation is independent of progress
/// rebuilds — a rebuild mid-fade would otherwise restart the fade and the
/// card would flicker whenever the bar moves.
class IntroSpaceFact extends StatefulWidget {
  const IntroSpaceFact({super.key});

  /// How long each fact stays up, matching the prototype's 4.5s interval.
  @visibleForTesting
  static const Duration dwell = Duration(milliseconds: 4500);

  @override
  State<IntroSpaceFact> createState() => _IntroSpaceFactState();
}

class _IntroSpaceFactState extends State<IntroSpaceFact> {
  var _index = 0;
  var _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(IntroSpaceFact.dwell, (_) => _next());
  }

  void _next() {
    if (!mounted) return;
    setState(() => _visible = false);
    // Half the prototype's 300ms fade-out before swapping the text.
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % IntroCopy.spaceFacts.length;
        _visible = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ds = DesignScale.sharedOf(context);
    return Container(
      width: double.infinity,
      padding: ds.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ds.radius(24)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4C1D95).withValues(alpha: 0.30),
            const Color(0xFF312E81).withValues(alpha: 0.30),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFACC15).withValues(alpha: 0.2),
        ),
      ),
      child: Stack(
        children: [
          // Clears the corner tab: text never slides under it at any scale.
          Padding(
            padding: EdgeInsets.only(
              top: ds.px(28),
              right: ds.px(12),
            ),
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                t.introFact(IntroCopy.spaceFacts[_index]),
                style: TextStyle(
                  fontSize: ds.font(13),
                  height: 1.5,
                  color: const Color(0xFFE9D5FF),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(12),
                ),
                color: const Color(0xFFFACC15).withValues(alpha: 0.2),
                border: Border.all(
                  color: const Color(0xFFFACC15).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '💡 ${t.introFactLabel}',
                style: TextStyle(
                  fontSize: ds.font(10),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFDE047),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
