import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:planets/scene.dart';

import '../../application/startup/startup_providers.dart';
import 'explorer_screen.dart';
import 'intro/intro_page.dart';

export 'explorer_screen.dart';
export 'intro/intro_page.dart';

/// The composition root's gate: intro until the universe is ready, then a
/// zoom-through handover to the Explorer.
///
/// A plain boolean rather than a route: the Explorer is expensive to build
/// (its scene view constructs the controller the moment it mounts), so it
/// must not exist in the tree at all *before startup completes* — pushing it
/// as a route would still build it underneath the intro.
///
/// Once startup *has* completed the trade-off flips, because the expensive
/// part is no longer building the scene but the first frame that shows it:
/// shader compilation, texture upload and the scene controller's first tick
/// all land in one frame, which is what the old hard swap hitched on. So the
/// Explorer is mounted early, underneath the intro's opaque background, and
/// painted there for the whole launch beat. By the time the rocket has
/// climbed, the scene is compiled and warm, and the handover only has to
/// crossfade two already-running pages.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key, this.explorerBuilder});

  /// Builds the Explorer shown after startup; `null` builds the real one.
  ///
  /// A test seam in the same style as `MissionCompanion.controllerFactory`:
  /// the real Explorer pulls in the 3D scene view, which needs a GPU, while a
  /// gate test only cares *when* the swap happens, not what the Explorer
  /// renders.
  final Widget Function()? explorerBuilder;

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate>
    with SingleTickerProviderStateMixin {
  /// How long the flight from intro to Explorer lasts once the rocket beat
  /// and the first scene frame are both in.
  ///
  /// Long enough to read as flying forward into space rather than a cut,
  /// short enough that a child who taps twice is not waiting on an animation.
  static const Duration handover = Duration(milliseconds: 900);

  /// The journey, in one continuous camera move: the intro accelerates past
  /// the lens while staying solid, then dissolves mid-rush; the solar system
  /// fades in small and far away, then flies toward the viewer and settles
  /// to full size exactly as the intro is gone — the system coming to meet
  /// the rocket.
  static const double _introZoom = 1.7;
  static const double _explorerZoom = 0.72;

  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: handover,
  );
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _swap,
    curve: const Interval(0.15, 0.7, curve: Curves.easeOut),
  );
  late final Animation<double> _zoomOut = CurvedAnimation(
    parent: _swap,
    curve: Curves.easeInCubic,
  );
  late final Animation<double> _introFade = CurvedAnimation(
    parent: _swap,
    curve: const Interval(0.4, 1.0, curve: Curves.easeInCubic),
  );
  late final Animation<double> _zoomIn = CurvedAnimation(
    parent: _swap,
    curve: Curves.easeOutCubic,
  );

  /// True once the Explorer should be in the tree. Latched, never reset:
  /// going back to the intro mid-exploration would strand the already-built
  /// scene behind a loading screen that has nothing left to load.
  var _explorerLive = false;

  /// True once the CTA has been tapped and the handover is under way.
  var _handingOver = false;

  /// True once the rocket's launch beat has elapsed.
  var _beatDone = false;

  /// True once the crossfade itself has started.
  var _swapStarted = false;

  /// True once the crossfade has finished and the intro can leave the tree.
  var _done = false;

  @override
  void initState() {
    super.initState();
    _swap.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _swap.dispose();
    super.dispose();
  }

  /// Builds the Explorer while the intro is still fully on screen.
  ///
  /// Called the moment the CTA is tapped, before the rocket's climb starts, so
  /// the scene gets the whole launch beat to compile and settle rather than
  /// doing it in the frame the child is looking at.
  void _primeExplorer() {
    if (_explorerLive) return;
    setState(() => _explorerLive = true);
  }

  /// The rocket has landed: freeze the intro's loops and wait for the scene.
  ///
  /// The crossfade itself starts in [_maybeStartSwap] once the Explorer has
  /// also presented its first frame, so the reveal never exposes a compiling
  /// scene or a loading fallback — only two already-running pages.
  void _enterExplorer() {
    if (_handingOver) return;
    setState(() {
      _handingOver = true;
      _explorerLive = true;
      _beatDone = true;
    });
    _maybeStartSwap();
  }

  /// Starts the crossfade once both sides are ready: the launch beat has
  /// elapsed and the Explorer scene has presented a frame.
  void _maybeStartSwap() {
    if (_swapStarted || !_beatDone) return;
    if (!ref.read(explorerScenePresentedProvider)) return;
    _swapStarted = true;
    // Moons are lazy: start decoding once the Explorer can present, so Intro
    // readiness and the first interactive frame are not blocked on them.
    ref
        .read(startupCoordinatorProvider.notifier)
        .warmLater(SolarSystemStartupTaskId.moons);
    _swap.forward();
  }

  @override
  Widget build(BuildContext context) {
    // The scene view reports its first presented frame through this flag;
    // starting the swap from the listener (rather than during build) keeps
    // the animation controller out of the build phase.
    ref.listen<bool>(explorerScenePresentedProvider, (_, presented) {
      if (presented) _maybeStartSwap();
    });
    // Both slots exist from the very first build, and neither is ever inserted
    // or removed in the middle: Stack children are matched by index, so adding
    // the Explorer underneath would shift the intro along and make Flutter
    // throw its State away - cancelling the launch timer's callback with it and
    // stranding the child on a screen that can no longer finish its own
    // animation. An empty slot is what keeps the intro's element, and with it
    // the launch beat, alive across the whole handover.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_explorerLive) _explorerLayer() else const SizedBox.shrink(),
        if (_handingOver && _done) const SizedBox.shrink() else _introLayer(),
      ],
    );
  }

  /// The Explorer, painted *underneath* the intro's opaque background so it is
  /// invisible while it compiles, then revealed as the intro fades away.
  Widget _explorerLayer() {
    final explorer = widget.explorerBuilder?.call() ?? const ExplorerScreen();
    return FadeTransition(
      opacity: _fadeIn,
      child: ScaleTransition(
        scale: Tween(begin: _explorerZoom, end: 1.0).animate(_zoomIn),
        child: explorer,
      ),
    );
  }

  /// The intro.
  ///
  /// The fade and the zoom read as a hold - opacity 1, scale 1 - until the
  /// handover starts, because they run off the same controller that still sits
  /// at zero. Keeping this subtree the same shape before and after the tap is
  /// what stops the intro from being rebuilt (and the rocket from reappearing)
  /// at the exact moment it should be flying away.
  Widget _introLayer() {
    final intro = IntroPage(
      onPrepareExplorer: _primeExplorer,
      onEnterExplorer: _enterExplorer,
    );
    return FadeTransition(
      // Holds solid for the first stretch of the rush, then dissolves fast:
      // the page flies past the camera and is gone by the time it would have
      // reached the lens, rather than dissolving away at its original size.
      opacity: Tween(begin: 1.0, end: 0.0).animate(_introFade),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: _introZoom).animate(_zoomOut),
        child: TickerMode(
          // Its own loops stop once the swap itself starts: the twinkling
          // starfield repaints the whole screen every frame, and this is the
          // moment the first Explorer frame is being paid for. While the gate
          // waits out a slow first frame the intro stays alive behind its
          // opaque background rather than freezing mid-fade.
          enabled: !_swapStarted,
          // Dead to touches while it fades, so a second tap cannot re-enter.
          child: IgnorePointer(ignoring: _handingOver, child: intro),
        ),
      ),
    );
  }
}
