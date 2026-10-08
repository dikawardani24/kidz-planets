import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/l10n.dart';
import 'package:core/platform.dart';

import '../../../application/startup/startup_providers.dart';
import 'intro_body.dart';
import 'widgets/intro_background.dart';
import 'widgets/intro_rocket.dart';

export 'intro_body.dart';

/// The kid-friendly loading screen: `prototype/intro.html` in Flutter.
///
/// Branding pill, big title, the rocket centerpiece on its orbit ring with
/// milestone badges, the progress bar + message card, the rotating fact card
/// and — once every required task finishes — the completion CTA. The page
/// watches the startup coordinator (Riverpod) and only renders state; every
/// animation is a self-contained loop so progress updates rebuild nothing but
/// the bar text.
class IntroPage extends ConsumerStatefulWidget {
  const IntroPage({
    super.key,
    required this.onEnterExplorer,
    this.onPrepareExplorer,
  });

  /// What happens when the child taps the completion CTA: the composition
  /// root starts handing this page over to the Explorer.
  final VoidCallback onEnterExplorer;

  /// Called the instant the CTA is tapped, before the launch beat plays.
  ///
  /// The gate uses it to build the Explorer while this page still covers the
  /// screen, so the scene is compiled by the time the handover starts and the
  /// swap is a pure animation rather than a cut followed by a stall.
  final VoidCallback? onPrepareExplorer;

  @override
  ConsumerState<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends ConsumerState<IntroPage> {
  var _started = false;
  var _launching = false;
  Timer? _launchTimer;

  /// Milestones revealed so far; monotonic so a badge never un-pops when the
  /// bar pauses between phases.
  var _seenMilestones = <IntroMilestone>{};

  /// The failure dialog is shown once per failure, not on every rebuild.
  var _errorDialogShown = false;

  @override
  void initState() {
    super.initState();
    // Last-resort remote handling: fires even when nothing holds focus, a
    // state some TV firmwares land in and never leave. Double delivery with
    // the Focus fallback and the focused button is harmless: launching is
    // latched and the coordinator collapses concurrent retries.
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _launchTimer?.cancel();
    super.dispose();
  }

  /// Global OK-key handler: entry and retry without depending on focus.
  bool _handleHardwareKey(KeyEvent event) {
    if (event is KeyRepeatEvent || event is! KeyDownEvent) return false;
    if (!_isOkKey(event.logicalKey)) return false;
    final current = ref.read(startupCoordinatorProvider);
    if (current.hasFailed) {
      _retry();
      return true;
    }
    if (current.isReady && !_launching) {
      _beginLaunch();
      return true;
    }
    return false;
  }

  static bool _isOkKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.gameButtonA;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(startupCoordinatorProvider);
    // TV gets a wider column with 10-foot type; phones keep the 448px rail.
    final isTv = ref.watch(isTelevisionProvider);

    // Kick off the real initialization after the first frame, so the child
    // sees the rocket before any heavy work starts.
    if (!_started) {
      _started = true;
      Future.microtask(() {
        if (mounted) ref.read(startupCoordinatorProvider.notifier).start();
      });
    }

    final complete = progress.isReady;
    _seenMilestones = {
      ..._seenMilestones,
      ...milestonesForProgress(progress.progress),
      if (complete) ...IntroMilestone.values,
    };

    // A failure must shout, not whisper: pop a kid-friendly error dialog on
    // top of the intro instead of leaving a full-looking bar with a small
    // card that may sit below the fold on a TV.
    ref.listen<StartupProgress>(startupCoordinatorProvider, (prev, next) {
      if (next.hasFailed && !(prev?.hasFailed ?? false) && !_errorDialogShown) {
        _errorDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showErrorDialog();
        });
      }
    });

    return Focus(
      // Focus-level fallback for the remote's OK: fires even when no button
      // currently holds focus (missed autofocus, lost focus, exotic remote),
      // so the intro can never strand a child at 100% again. The focused
      // button still wins when it has focus — handled events never bubble
      // here — and the launch/retry guards make a double delivery a no-op.
      autofocus: true,
      onKeyEvent: (node, event) {
        // Held-button repeats must not double-launch or double-retry.
        if (event is KeyRepeatEvent || event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (!_isOkKey(event.logicalKey)) return KeyEventResult.ignored;
        final current = ref.read(startupCoordinatorProvider);
        if (current.hasFailed) {
          _retry();
          return KeyEventResult.handled;
        }
        if (current.isReady && !_launching) {
          _beginLaunch();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF060417),
        body: Stack(
          children: [
            const IntroBackground(),
            // Fredoka everywhere below: explicit styles inside merge over this
            // inherited default, so the intro reads with the prototype's
            // rounded, playful type without re-skinning the Explorer too.
            DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'Fredoka',
                color: Colors.white,
                fontSize: 14,
              ),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    // Column width from the viewport itself: phones keep the
                    // 448px rail, wider screens open up to the two-column
                    // maximum. No per-device widths anywhere.
                    constraints: BoxConstraints(
                      maxWidth: (MediaQuery.sizeOf(context).width * 0.6).clamp(
                        448.0,
                        1150.0,
                      ),
                    ),
                    child: SingleChildScrollView(
                      // Overscan-friendly: grows with the screen instead of
                      // touching edges on small TVs.
                      padding: EdgeInsets.all(
                        (MediaQuery.sizeOf(context).width * 0.025).clamp(
                          24.0,
                          48.0,
                        ),
                      ),
                      child: IntroBody(
                        progress: progress,
                        seenMilestones: _seenMilestones,
                        launching: _launching,
                        isTv: isTv,
                        onRetry: _retry,
                        onEnter: _beginLaunch,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Plays the launch beat, then hands over to the Explorer.
  ///
  /// The prototype fires the Explorer view the moment the button is tapped;
  /// the short climb lets the child see the rocket leave before the swap,
  /// which is the payoff the whole screen has been promising. The Explorer is
  /// asked for first, so its scene is built and compiled underneath this page
  /// during the beat and the handover has nothing left to stall on.
  void _beginLaunch() {
    if (_launching) return;
    widget.onPrepareExplorer?.call();
    setState(() => _launching = true);
    _launchTimer = Timer(IntroRocket.launchDuration, () {
      if (mounted) widget.onEnterExplorer();
    });
  }

  /// Re-runs the failed startup tasks, from the inline card or the dialog.
  ///
  /// Re-arms the dialog flag so a second failure still shouts: without this a
  /// retry that fails again would fall back to the silent inline card.
  void _retry() {
    _errorDialogShown = false;
    ref.read(startupCoordinatorProvider.notifier).retry();
  }

  /// The kid-friendly failure dialog: what went wrong (never an exception),
  /// and one big retry the remote can press.
  ///
  /// Dismissing it without retrying leaves the inline error card underneath,
  /// whose own retry is equally focusable — there is no dead end either way.
  void _showErrorDialog() {
    final t = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xFF0C132C),
              border: Border.all(
                color: const Color(0xFFF87171).withValues(alpha: .5),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🚀', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  t.introErrorTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.introErrorBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.4,
                    color: Color(0xFFD8B4FE),
                  ),
                ),
                const SizedBox(height: 24),
                TvFocusable(
                  autofocus: true,
                  onSelect: () {
                    Navigator.of(dialogContext).pop();
                    _retry();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      ),
                    ),
                    child: Text(
                      '🔄 ${t.introRetry}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
