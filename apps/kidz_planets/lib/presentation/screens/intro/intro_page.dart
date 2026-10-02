import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/startup/startup_providers.dart';
import 'intro_body.dart';
import 'widgets/intro_background.dart';

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
  const IntroPage({super.key, required this.onEnterExplorer});

  /// What happens when the child taps the completion CTA: the composition
  /// root swaps this page for the existing Explorer screen.
  final VoidCallback onEnterExplorer;

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

  @override
  void dispose() {
    _launchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(startupCoordinatorProvider);

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

    return Scaffold(
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
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: IntroBody(
                      progress: progress,
                      seenMilestones: _seenMilestones,
                      launching: _launching,
                      onRetry: () =>
                          ref.read(startupCoordinatorProvider.notifier).retry(),
                      onEnter: _beginLaunch,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Plays the launch beat, then hands over to the Explorer.
  ///
  /// The prototype fires the Explorer view the moment the button is tapped;
  /// the short climb lets the child see the rocket leave before the swap,
  /// which is the payoff the whole screen has been promising.
  void _beginLaunch() {
    if (_launching) return;
    setState(() => _launching = true);
    _launchTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) widget.onEnterExplorer();
    });
  }
}
