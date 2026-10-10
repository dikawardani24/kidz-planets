import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:avatar/audio.dart';
import 'package:avatar/controllers.dart';
import 'package:avatar/scene.dart';
import 'package:avatar/state.dart';
import 'package:avatar/widgets.dart';
import 'package:core/l10n.dart';
import 'package:core/platform.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:kidz_planets/presentation/tv/tv_nav_target.dart';
import 'package:kidz_planets/presentation/tv/tv_providers.dart';
import 'package:planets/data.dart';
import 'package:planets/state.dart';

export 'package:avatar/widgets.dart'
    show kCompanionBoxWidth, kCompanionBoxHeight, kCompanionEdge;

/// How much a two-finger twist turns the toy, per radian of twist.
const double kCompanionTwistYaw = 18;

/// How much a two-finger drag turns the toy: sideways turns it (yaw), up and
/// down tips it (pitch). One finger is spoken for by moving the toy, so the
/// second finger is what makes the companion behave like a 3D object rather
/// than a sticker.
const double kCompanionDragYaw = 0.8;
const double kCompanionDragPitch = 0.5;

/// The persistent 3D Chubby Cartoon Rocket Ship mission companion.
class MissionCompanion extends ConsumerStatefulWidget {
  const MissionCompanion({super.key, this.controllerFactory});

  final AvatarSceneController Function()? controllerFactory;

  @override
  ConsumerState<MissionCompanion> createState() => _MissionCompanionState();
}

class _MissionCompanionState extends ConsumerState<MissionCompanion>
    with TickerProviderStateMixin {
  late final AvatarSceneController _controller;

  /// The frame clock.
  ///
  /// A ticker rather than a repeating animation controller, because the physics
  /// needs a monotonically increasing elapsed time to difference against the
  /// previous frame. An animation controller's elapsed time resets on every
  /// repeat, so differencing it would produce one enormous negative delta once
  /// a second, which the clamp would turn into a dropped frame at a fixed and
  /// very visible cadence.
  late final _FrameClock _frameClock;

  /// The bounce squash, eased back to nothing over
  /// [AvatarPhysicsConfig.impactDuration].
  late final AnimationController _impactTicker;

  /// The companion's own controller, held for the life of the state.
  ///
  /// The frame loop reads this on every frame, and a `ref.read` from inside a
  /// ticker callback is not safe: a ticker that outlives its element, which a
  /// torn-down tree can produce, finds the element's provider already
  /// deinitialised and throws from inside the scheduler. The notifier itself
  /// lives in the container rather than in the element, so holding it costs
  /// nothing and stays usable for as long as the clock does.
  late final AvatarController _avatar;

  /// Whether a planet is selected, sampled once per frame from the explorer.
  ///
  /// Cached for the same reason as [_avatar]; [didChangeDependencies] keeps it
  /// current, since the frame loop has to read it without building.
  bool _hasSelection = false;

  /// The TV focus node for the parked toy: owned here (never rebuilt) so the
  /// shell can hand the remote to the companion on a miss.
  final FocusNode _tvFocus = FocusNode(debugLabel: 'tvCompanion');

  bool _ready = false;
  bool _placed = false;

  /// A viewport to use before the first layout, so the ticker always has
  /// something valid to work with. Only the pre-layout frames see it, and no
  /// motion is possible before then anyway.
  static const Size _fallbackViewport = Size(400, 800);

  /// The throwable area from the most recent layout.
  ///
  /// Kept as a rectangle rather than a maximum offset because the top and left
  /// edges are not at the origin once the safe area and the bars are accounted
  /// for, and a throw that ignored the minimum would park the toy under the top
  /// bar.
  CompanionSafeArea _safeArea = CompanionSafeArea.forViewport(
    _fallbackViewport,
    EdgeInsets.zero,
  );

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controllerFactory?.call() ?? AvatarSceneControllerImpl();
    _avatar = ref.read(avatarControllerProvider.notifier);
    _hasSelection = ref.read(explorerControllerProvider).hasSelection;
    // The opening body loads before the first frame is declared ready, so the
    // companion never shows one avatar while meaning another.
    unawaited(_controller.setAvatarType(ref.read(avatarSelectionProvider)));

    _frameClock = _FrameClock(vsync: this, onFrame: _onFlightFrame);

    _impactTicker = AnimationController(
      vsync: this,
      duration: AvatarPhysicsConfig.impactDuration,
    )..addListener(_onImpactFrame);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.ensureBuilt();
      setState(() => _ready = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The frame loop cannot watch anything, and this rebuild is the only moment
    // a changed selection is visible to a state that holds it as a plain field.
    _hasSelection = ref.read(explorerControllerProvider).hasSelection;
  }

  /// Eases the impact squash back to an undeformed toy.
  ///
  /// A symmetric in-and-out would read as a heartbeat; easing out over a
  /// slightly longer tail reads as the toy absorbing the hit and settling, which
  /// is what actually happens. The squashed scale is written directly rather
  /// than through a `setState`, because a throw is already rebuilding this
  /// widget every frame and a second notification per frame would double the
  /// build cost for one effect.
  void _onImpactFrame() {
    // Ease-out cubic: the toy pops back quickly and then eases away the last of
    // the deformation, which reads as absorbing the hit. An ease-in-out would
    // read as a heartbeat instead.
    final eased = 1 - math.pow(1 - _impactTicker.value, 3).toDouble();
    _impactSquash = _impactFrom + (1 - _impactFrom) * eased;
    // The 3D body is deformed here rather than from a build, so the deformation
    // costs a transform write and not a second rebuild of this widget on top of
    // the one a throw is already causing every frame.
    _controller.setImpactSquash(_impactSquash);
  }

  /// Advances the companion one frame.
  ///
  /// Two separate jobs share this one ticker, and the order of the checks below
  /// is the reason a throw used to die on its very first frame: a launched
  /// companion is parked as well as moving, so `isFlightPaused` was already
  /// true at the moment it was thrown, and the pause check returned before
  /// anything integrated the velocity. The toy therefore had its throw
  /// velocity set and then stopped dead, which is exactly the "it stops where I
  /// let go" behaviour a flick is supposed to avoid.
  ///
  /// `isThrowing` is the real test for "a throw is in flight", so it is checked
  /// first and short-circuits the pause.
  void _onFlightFrame(double dt) {
    if (!mounted) return;

    if (_avatar.isThrowing) {
      _updateThrow(dt, _avatar);
      return;
    }

    // A planet being focused takes priority over a throw: the child asked for
    // something else, and a toy still bouncing across the screen would be in
    // the way of the answer they are waiting for.
    if (_hasSelection) return;

    // Parked by a drag, or mid-reaction: the companion holds its place instead
    // of flying. The pause lives in the state, so the widget never has to guess
    // what the controller is up to.
    _avatar.updateFlight(dt, _safeArea.viewport, _safeArea.max);
  }

  /// Steps the throw, then reacts to whatever the physics hit.
  ///
  /// The order matters: the reaction reads the bounces the step just reported,
  /// so an impact is always heard on the same frame the toy reaches the wall
  /// rather than a frame late.
  void _updateThrow(double dt, AvatarController notifier) {
    notifier.updateFlight(
      dt,
      _safeArea.viewport,
      _safeArea.max,
      minPosition: _safeArea.min,
    );
    _reactToBounces(notifier.takeBounces());
  }

  /// The scale to recover to once the current squash has finished.
  double _impactFrom = 1;

  /// How much the toy is squashed right now, `1` meaning unsquashed.
  ///
  /// Driven by [_onImpact] from the physics and read by the build, so an impact
  /// never triggers a widget rebuild of its own: the companion's position is
  /// already being rebuilt every frame during a throw, and a second
  /// notification for the same frame would double the work for one effect.
  double _impactSquash = 1;

  /// When the squash may next be triggered, to keep fast bounces from stacking.
  DateTime _lastImpactAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the platform has asked for less motion.
  bool _reducedMotion = false;

  /// Reacts to the bounces the physics reported this frame.
  ///
  /// A bounce is only worth showing if the toy hit hard enough to notice.
  /// Below [AvatarPhysicsConfig.impactVelocity] the toy is settling rather than
  /// bouncing, and squashing or clicking for each of those would turn the last
  /// second of a throw into a rattle.
  void _reactToBounces(List<AvatarBounce> bounces) {
    if (bounces.isEmpty) return;

    // A corner hit reports both axes at once. The hardest of the two is the
    // one the child would describe as "it hit the wall", so it is the one that
    // decides the volume and the squash.
    var hardest = 0.0;
    for (final bounce in bounces) {
      if (bounce.impactSpeed > hardest) hardest = bounce.impactSpeed;
    }
    if (hardest < AvatarPhysicsConfig.impactVelocity) return;

    // The cooldown also stops a toy pinned in a corner, bouncing on the spot,
    // from retriggering the effect every frame.
    final now = DateTime.now();
    if (now.difference(_lastImpactAt).inMilliseconds <
        AvatarPhysicsConfig.impactCooldownMs) {
      return;
    }
    _lastImpactAt = now;

    // Normalised against the speed a hard fling really reaches a wall at, then
    // square-rooted for the same reason the sound's volume is: against the
    // throw cap, an ordinary bounce lands at a few percent, which is not a
    // reaction the child can see.
    final strength = math.sqrt(
      (hardest / AvatarPhysicsConfig.impactReferenceSpeed).clamp(0.0, 1.0),
    );
    _impactFrom =
        1 -
        AvatarPhysicsConfig.impactSquashDepth *
            strength *
            (_reducedMotion
                ? AvatarPhysicsConfig.reducedMotionImpactScale
                : 1.0);
    _impactSquash = _impactFrom;
    _controller.setImpactSquash(_impactFrom);
    _impactTicker.forward(from: 0);

    // Read lazily rather than held: the sound outlives any single companion
    // through the provider, and a test that pumps the widget without audio still
    // gets a valid object whose player simply fails to load the asset.
    unawaited(
      ref
          .read(avatarImpactSoundProvider)
          .playBounce(impactSpeed: hardest, reducedMotion: _reducedMotion),
    );

    // A hard wall hit is also a character moment: let the rocket look briefly
    // dizzy instead of only deforming physically. Keep gentle bounces purely
    // physical so normal play does not become noisy or over-animated.
    if (!_reducedMotion && hardest >= 700.0) {
      ref
          .read(avatarControllerProvider.notifier)
          .react(
            AvatarReaction.dizzy,
            duration: const Duration(milliseconds: 700),
          );
    }
  }

  final Map<int, Offset> _activePointers = {};
  VelocityTracker? _velocityTracker;
  Offset? _firstDownPos;
  DateTime? _firstDownTime;
  int _tapCount = 0;
  Timer? _singleTapTimer;
  Timer? _longPressTimer;
  bool _isLongPress = false;
  bool _hasMovedFar = false;

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length == 1) {
      _firstDownPos = event.position;
      _firstDownTime = DateTime.now();
      _hasMovedFar = false;
      _isLongPress = false;
      _dragSamples.clear();

      _velocityTracker = VelocityTracker.withKind(event.kind);
      _velocityTracker?.addPosition(event.timeStamp, event.position);
      ref.read(avatarControllerProvider.notifier).stopMomentum();

      _longPressTimer?.cancel();
      _longPressTimer = Timer(const Duration(milliseconds: 500), () {
        if (_activePointers.length == 1 && !_hasMovedFar && mounted) {
          _isLongPress = true;
          ref
              .read(avatarControllerProvider.notifier)
              .react(
                AvatarReaction.sleepy,
                duration: const Duration(milliseconds: 1800),
              );
        }
      });
    } else if (_activePointers.length >= 2) {
      _velocityTracker = null;
      _dragSamples.clear();
      _longPressTimer?.cancel();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    _activePointers[event.pointer] = event.position;

    if (_activePointers.length == 1) {
      final start = _firstDownPos;
      if (start != null && (event.position - start).distanceSquared > 36) {
        _hasMovedFar = true;
        _longPressTimer?.cancel();
      }
      _velocityTracker?.addPosition(event.timeStamp, event.position);
      // Every move is also fed to a short history, because the velocity of the
      // last event alone is a poor estimate of a throw: a release often arrives
      // with a tiny or zero final delta while the real speed is still high, and
      // relying on it is what makes a flick feel like a drop.
      _recordDragSample(event.position, event.timeStamp);
      ref
          .read(avatarControllerProvider.notifier)
          .moveBy(
            delta: event.delta,
            maxPosition: _safeArea.max,
            // The minimum matters as much as the maximum here: a drag that only
            // respected the far corner would slide the toy under the status bar
            // and the top bar, where it could no longer be seen or grabbed.
            minPosition: _safeArea.min,
          );
    } else if (_activePointers.length >= 2) {
      _velocityTracker = null;
      _longPressTimer?.cancel();
      _hasMovedFar = true;
      ref
          .read(avatarControllerProvider.notifier)
          .rotateBy(
            dx: event.delta.dx * kCompanionDragYaw,
            dy: event.delta.dy * kCompanionDragPitch,
          );
    }
  }

  /// Recent drag samples, newest last.
  ///
  /// A fixed-capacity ring rather than a growing list: a long drag must not
  /// accumulate memory, and only the tail of the gesture describes how fast
  /// the toy was actually moving when it was let go.
  final List<_DragSample> _dragSamples = <_DragSample>[];

  /// How many recent samples a throw velocity is estimated from.
  static const int _kDragSampleCount = 5;

  /// Records a drag position, dropping the oldest sample once full.
  void _recordDragSample(Offset position, Duration timeStamp) {
    _dragSamples.add(_DragSample(position, timeStamp));
    if (_dragSamples.length > _kDragSampleCount) _dragSamples.removeAt(0);
  }

  /// The speed to throw at, in logical pixels per second.
  ///
  /// The recent samples are combined with the framework's own velocity tracker:
  /// the tracker fits a curve through the whole gesture and is the better
  /// estimate of a smooth flick, while the sample history survives the two cases
  /// it handles badly, namely a release whose last event reports almost no
  /// movement and a slow drag that the tracker rounds to zero.
  ///
  /// The two are blended rather than one overriding the other, so neither a
  /// spurious final sample nor a tracker's zero can decide the throw on its
  /// own. The sample history is weighted towards its newest entries, because
  /// how fast the toy was going just before release is the question being
  /// asked.
  Offset _throwVelocity(Offset? tracked) {
    if (_dragSamples.length < 2) {
      return tracked ?? Offset.zero;
    }

    // Per-sample velocity, each weighted by recency, integrated over the
    // window's own duration so a slow sample cannot outvote a fast one just by
    // being older.
    var weightedDx = 0.0;
    var weightedDy = 0.0;
    var totalWeight = 0.0;
    for (var i = 1; i < _dragSamples.length; i++) {
      final previous = _dragSamples[i - 1];
      final current = _dragSamples[i];
      final micros = (current.time - previous.time).inMicroseconds;
      if (micros <= 0) continue;
      final seconds = micros / 1e6;
      final weight = i.toDouble();
      weightedDx +=
          (current.position.dx - previous.position.dx) / seconds * weight;
      weightedDy +=
          (current.position.dy - previous.position.dy) / seconds * weight;
      totalWeight += weight;
    }
    if (totalWeight <= 0) return tracked ?? Offset.zero;

    final sampled = Offset(weightedDx / totalWeight, weightedDy / totalWeight);
    if (tracked == null) return sampled;

    // The two estimates agreeing is the common case, so the blend is only
    // visible when they disagree, which is exactly when one of them is wrong.
    return Offset((sampled.dx + tracked.dx) / 2, (sampled.dy + tracked.dy) / 2);
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    _longPressTimer?.cancel();

    if (_activePointers.isEmpty) {
      if (_hasMovedFar && _velocityTracker != null) {
        _velocityTracker?.addPosition(event.timeStamp, event.position);
        final estimate = _velocityTracker?.getVelocity();
        _recordDragSample(event.position, event.timeStamp);
        final tracked = estimate == null
            ? null
            : Offset(estimate.pixelsPerSecond.dx, estimate.pixelsPerSecond.dy);
        final velocity = _throwVelocity(tracked);
        if (velocity.distance > 0) {
          ref
              .read(avatarControllerProvider.notifier)
              .launchWithVelocity(
                velocity: _reducedMotion
                    // Reduced motion keeps the toy controllable rather than
                    // removing the throw, so the speed is capped low enough
                    // that it settles almost immediately.
                    ? velocity * AvatarPhysicsConfig.reducedMotionThrowScale
                    : velocity,
                maxPosition: _safeArea.max,
              );
          // The whoosh marks the launch, not the flight: one cue per flick,
          // fired here rather than from the frame loop so it cannot retrigger
          // every frame the toy is moving.
          if (velocity.distance >= AvatarPhysicsConfig.minThrowVelocity) {
            unawaited(
              ref.read(avatarExpressionSoundProvider).playThrowWhoosh(),
            );
            // A fast launch makes the companion feel excited about being
            // thrown, while the scene builder simultaneously increases the
            // engine plume from the actual flight speed.
            ref
                .read(avatarControllerProvider.notifier)
                .react(
                  AvatarReaction.excited,
                  duration: const Duration(milliseconds: 650),
                );
          }
        }
        _velocityTracker = null;
        _dragSamples.clear();
      }

      final downTime = _firstDownTime;
      final now = DateTime.now();
      if (!_hasMovedFar &&
          !_isLongPress &&
          downTime != null &&
          now.difference(downTime).inMilliseconds < 350) {
        _tapCount++;
        if (_tapCount == 1) {
          _singleTapTimer?.cancel();
          _singleTapTimer = Timer(const Duration(milliseconds: 250), () {
            if (_tapCount == 1 && mounted) _interactByTap();
            _tapCount = 0;
          });
        } else if (_tapCount >= 2) {
          _singleTapTimer?.cancel();
          _tapCount = 0;
          ref
              .read(avatarControllerProvider.notifier)
              .react(
                AvatarReaction.dizzy,
                duration: const Duration(milliseconds: 1300),
              );
        }
      } else {
        _tapCount = 0;
      }
    }
  }

  /// The TV-remote equivalent of tapping the toy: encouragement after a miss,
  /// a happy reaction otherwise. Shared with the single-tap path above so
  /// touch and remote always do the same thing.
  void _interactByTap() {
    if (ref.read(appShellProvider).avatarMood == AvatarMood.wrong) {
      ref.read(appShellProvider.notifier).retryMission();
    } else {
      ref.read(avatarControllerProvider.notifier).react(AvatarReaction.happy);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    _longPressTimer?.cancel();
    _singleTapTimer?.cancel();
    _tapCount = 0;
  }

  @override
  void dispose() {
    _tvFocus.dispose();
    _singleTapTimer?.cancel();
    _longPressTimer?.cancel();
    _frameClock.dispose();
    _impactTicker.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Resolves the mix level for an expression cue.
  ///
  /// Mission cues are deliberately quieter because the mission result sound
  /// is the primary audio event. Regular expression and idle cues use the
  /// normal expression level.
  double _volumeForCue(AvatarExpressionCue cue) {
    switch (cue.asset) {
      case 'assets/audio/sfx/avatar/avatar_success.mp3':
      case 'assets/audio/sfx/avatar/avatar_failure.mp3':
      case 'assets/audio/sfx/avatar/avatar_find_object.mp3':
        return AvatarExpressionSound.missionVolume;
      default:
        return AvatarExpressionSound.baseVolume;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pose = ref.watch(avatarControllerProvider);
    final ui = ref.watch(explorerControllerProvider);
    final mission = ref.watch(activeMissionProvider);
    final mood = ref.watch(appShellProvider.select((s) => s.avatarMood));
    final avatarType = ref.watch(avatarSelectionProvider);

    // One centralized SFX trigger for the whole expressive state. Both
    // listeners resolve through the same `avatarCueFor`, which picks exactly
    // one cue for the combined (mood, reaction, idle, heart) state — so a
    // mission beat can never double-play (mission cue + reaction cue), and
    // rebuilds re-resolve the same cue which the sound's dedupe key drops.
    // Animation and SFX start together because both read the same state
    // change in the same frame the controller publishes it.
    //
    // Two listeners (not one) because Riverpod has no multi-provider select:
    // each one re-resolves the full state when its half changes. Whichever
    // fires second for a single beat re-resolves the same cue and is dropped
    // by the dedupe key — that is the guard doing its job, not a bug.
    void playResolvedCue() {
      final mood = ref.read(appShellProvider).avatarMood;
      final pose = ref.read(avatarControllerProvider);
      final cue = avatarCueFor(
        mood: mood,
        reaction: pose.reaction,
        idle: pose.idleAction,
        heartVisible: pose.isHeartVisible,
      );
      if (cue == null) return;
      final sound = ref.read(avatarExpressionSoundProvider);
      unawaited(sound.playCue(cue, volume: _volumeForCue(cue)));
    }

    ref.listen<AvatarMood>(appShellProvider.select((s) => s.avatarMood), (
      previous,
      next,
    ) {
      if (previous == next) return;
      final beat = companionBeatFor(next);
      final avatar = ref.read(avatarControllerProvider.notifier);
      if (beat.reaction == AvatarReaction.none) {
        avatar.clearReaction();
      } else {
        avatar.react(beat.reaction, duration: beat.duration);
      }
      playResolvedCue();
    });

    ref.listen<AvatarState>(avatarControllerProvider, (previous, next) {
      if (previous == next) return;
      playResolvedCue();
    });

    // Choosing an avatar on the Avatar page swaps the Explorer's body live:
    // the builder stages the new model before the old one leaves, so the toy
    // changes clothes without ever popping out of existence.
    ref.listen<AvatarType>(avatarSelectionProvider, (previous, next) {
      if (previous == next) return;
      unawaited(_controller.setAvatarType(next));
    });

    // A miss hands the remote to the rocket: encouragement is one OK away
    // instead of unreachable. Post-frame so the freshly mounted facts pill
    // (which autofocuses on every selection) loses deterministically rather
    // than racing it. Directly in build — listeners cannot live in the
    // LayoutBuilder below. Menu Mode only: in Planet Mode the companion sits
    // out D-pad focus, so focus must not be pulled onto an excluded target
    // (touch encouragement still works there).
    ref.listen<AvatarMood>(appShellProvider.select((s) => s.avatarMood), (
      previous,
      next,
    ) {
      if (next == AvatarMood.wrong && previous != AvatarMood.wrong) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              ref.read(isTelevisionProvider) &&
              ref.read(tvExplorerControllerProvider).chromeFocused) {
            _tvFocus.requestFocus();
          }
        });
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (viewport.isEmpty) return const SizedBox.shrink();

        // Read rather than watch: the platform can turn reduced motion on
        // while the app is running, and a throw has to notice that on the next
        // release rather than on the next rebuild of something else.
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        if (reduceMotion != _reducedMotion) {
          _reducedMotion = reduceMotion;
          // The simulation has to know as well. Scaling the release gesture
          // alone leaves a throw launched by anything else, a reaction, or a
          // restored state, travelling at full strength for a reader who asked
          // for less of it.
          _avatar.setReducedMotion(reduceMotion);
        }

        // The region the toy may be thrown around in, derived from the space
        // this widget was actually given rather than from the window, so it is
        // correct in the explorer's stack and in the smaller test layouts alike.
        _safeArea = CompanionSafeArea.forViewport(
          viewport,
          MediaQuery.paddingOf(context),
        );
        final bounds = _safeArea.bounds;

        final hasFocus = ui.hasSelection;

        // The toy centres itself above the nav when a planet is focused, and
        // the anchor is taken from the same bounds a throw would use so the two
        // cannot disagree about where the bottom of the screen is.
        final bottomAnchor = Offset(
          (viewport.width / 2 - kCompanionBoxWidth / 2).clamp(
            bounds.min.dx,
            bounds.max.dx,
          ),
          bounds.max.dy,
        );

        final home = Offset(
          bounds.max.dx,
          bounds.min.dy + (bounds.max.dy - bounds.min.dy) * 0.42,
        );

        if (!_placed && pose.screenPosition == null) {
          _placed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref
                .read(avatarControllerProvider.notifier)
                .placeAt(
                  home,
                  maxPosition: bounds.max,
                  minPosition: bounds.min,
                );
          });
        }

        final rawPosition = hasFocus
            ? bottomAnchor
            : (pose.screenPosition ?? home);
        final position = bounds.clamp(rawPosition);

        _controller.applyPose(pose);
        _controller.applyReaction(pose.reaction);

        final targetColor = mission == null
            ? Theme.of(context).colorScheme.primary
            : Color(
                ref.read(planetByIdProvider(mission.targetPlanetId)).colorValue,
              );
        _controller.showTarget(visible: false, color: targetColor);

        final placement = bubblePlacement(
          avatarTop: position.dy,
          avatarLeft: position.dx,
          avatarWidth: kCompanionBoxWidth,
          avatarHeight: kCompanionBoxHeight,
          viewport: viewport,
        );

        final isIceWorld =
            ui.selectedPlanetId == 'neptune' ||
            ui.selectedPlanetId == 'uranus' ||
            ui.selectedPlanetId == 'pluto';
        final isHotWorld =
            ui.selectedPlanetId == 'sun' ||
            ui.selectedPlanetId == 'mercury' ||
            ui.selectedPlanetId == 'venus';

        final t = AppLocalizations.of(context);
        // On TV the throwable toy is parked: the same tap interaction is
        // offered as a registered spatial stop instead, and focus ownership
        // tells the remote handler to yield arrow input to the avatar layer
        // (outside UI focus mode — inside it the companion is simply the next
        // spatial target). TvNavTarget is the single wrapper: it renders the
        // focus ring, reports layout into the registry, and owns OK.
        final isTv = ref.watch(isTelevisionProvider);
        Widget focusForTv(Widget child) {
          if (!isTv) return child;
          return TvNavTarget(
            id: 'chrome:companion',
            control: TvChromeControl.other,
            focusNode: _tvFocus,
            onSelect: _interactByTap,
            scaleOnFocus: false,
            onFocusChange: (focused) =>
                ref.read(tvAvatarFocusedProvider.notifier).state = focused,
            child: child,
          );
        }

        String companionText = t.companionFlying;
        if (hasFocus) {
          if (isIceWorld) {
            companionText = t.companionCold;
          } else if (isHotWorld) {
            companionText = t.companionHot;
          } else {
            companionText = t.companionInspecting;
          }
        } else if (pose.idleAction == AvatarIdleAction.sendingHeart) {
          companionText = t.companionSpaceLove;
        } else if (pose.idleAction == AvatarIdleAction.dancing) {
          companionText = t.companionBoogie;
        } else if (pose.idleAction == AvatarIdleAction.thinking) {
          companionText = t.companionThinking;
        }

        // A mission beat owns the line, even over the lines above: the
        // companion is what tells the child what to look for, that a pick was
        // wrong, and that it was found - and it says it by the planet's own
        // name, in the language the rest of the screen is in.
        if (mission != null && mood != AvatarMood.searching) {
          companionText = avatarLine(
            mood,
            localizedPlanetName(
              mission.targetPlanetId,
              Localizations.localeOf(context),
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: bubbleLeft(
                side: placement.side,
                avatarLeft: position.dx,
                avatarWidth: kCompanionBoxWidth,
                viewport: viewport,
              ),
              top: placement.top,
              width: kBubbleWidth,
              child: _Bubble(
                text: companionText,
                below: placement.below,
                accent: isIceWorld
                    ? const Color(0xFF38BDF8)
                    : isHotWorld
                    ? const Color(0xFFFBBF24)
                    : pose.isHeartVisible
                    ? const Color(0xFFEC4899)
                    : avatarAccent(mood),
              ),
            ),
            Positioned(
              left: position.dx,
              top: position.dy,
              width: kCompanionBoxWidth,
              height: kCompanionBoxHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (pose.isHeartVisible)
                    Positioned(
                      top: -30,
                      left: kCompanionBoxWidth / 2 - 18,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.6, end: 1.3),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: const Text(
                              '❤️',
                              style: TextStyle(fontSize: 32),
                            ),
                          );
                        },
                      ),
                    ),
                  focusForTv(
                    Semantics(
                      // The label the move handle used to carry: the toy itself
                      // is the handle now, so a screen reader hears it there.
                      label: t.companionMoveLabel,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerUp: _onPointerUp,
                        onPointerCancel: _onPointerCancel,
                        child: Stack(
                          children: [
                            _CompanionScene(
                              ready: _ready,
                              controller: _controller,
                              mood: mood,
                              idleAction: hasFocus
                                  ? AvatarIdleAction.sitting
                                  : pose.idleAction,
                              selectedPlanetId: ui.selectedPlanetId,
                            ),
                            // The face is Flutter paint over the 3D render, so it
                            // must not swallow drags meant for the toy. It is
                            // also rocket-only: the painted face belongs to
                            // the rocket's window, and the astronaut wears
                            // none, so only the rocket's body carries one.
                            if (_ready && avatarType == AvatarType.rocket)
                              AnimatedBuilder(
                                // The face is driven by the same clock as the
                                // physics, so the expression and the toy never
                                // disagree about how much time has passed.
                                animation: Listenable.merge([
                                  _frameClock,
                                  _impactTicker,
                                ]),
                                builder: (context, _) => IgnorePointer(
                                  child: AvatarFace(
                                    box: const Size(
                                      kCompanionBoxWidth,
                                      kCompanionBoxHeight,
                                    ),
                                    pose: pose,
                                    motion: _controller.bodyMotion,
                                    phase: _frameClock.seconds,
                                    squash: _impactSquash,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One recorded point of a drag, with the time it was seen at.
///
/// The timestamp has to be the event's own rather than `DateTime.now()` at the
/// time it was handled: a pointer event carries the time the platform produced
/// it, which is what a velocity is a function of, and handling a batch of
/// queued events late would otherwise understate how fast the toy was really
/// moving.
/// The companion's frame clock: a monotonic elapsed time, a clamped per-frame
/// delta, and a notification on every frame.
///
/// A [Ticker] is not a [Listenable] in this Flutter version, and the face
/// painted over the 3D window has to be repainted on the same frames the body
/// moves on. Wrapping the ticker is what lets one clock drive both the throw
/// physics and that repaint, instead of running two loops that would drift apart
/// and leave the face a frame behind the toy it belongs to.
class _FrameClock extends ChangeNotifier {
  _FrameClock({required TickerProvider vsync, required this.onFrame}) {
    _ticker = vsync.createTicker(_onTick)..start();
  }

  final void Function(double dt) onFrame;

  late final Ticker _ticker;
  Duration? _lastElapsed;

  /// Elapsed seconds, accumulated from clamped frame deltas.
  ///
  /// The idle animation runs off this rather than off the wall clock, so it
  /// keeps its own pace regardless of the display's refresh rate, and it
  /// advances by exactly the delta the physics integrates, so the face and the
  /// toy never disagree about how much time has passed.
  double seconds = 0;

  /// The current frame's delta, in seconds.
  ///
  /// Zero on the first frame, which has no previous timestamp to measure
  /// against and no motion behind it.
  double delta = 0;

  void _onTick(Duration elapsed) {
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    delta = previous == null
        ? 0.0
        : ((elapsed - previous).inMicroseconds / 1e6).clamp(
            0.0,
            AvatarPhysicsConfig.maxDeltaTime,
          );
    seconds += delta;
    onFrame(delta);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// One recorded point of a drag, with the time it was seen at.
class _DragSample {
  const _DragSample(this.position, this.time);

  final Offset position;
  final Duration time;
}

class _CompanionScene extends StatelessWidget {
  const _CompanionScene({
    required this.ready,
    required this.controller,
    required this.mood,
    required this.idleAction,
    required this.selectedPlanetId,
  });

  final bool ready;
  final AvatarSceneController controller;
  final AvatarMood mood;
  final AvatarIdleAction idleAction;
  final String? selectedPlanetId;

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SizedBox.shrink();
    if (!controller.isRealScene) return const SizedBox.expand();
    return SceneView(
      controller.scene,
      camera: AvatarSceneControllerImpl.camera,
      onTick: (elapsed, _) =>
          controller.tick(elapsed, mood, idleAction, selectedPlanetId),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.below,
    required this.accent,
  });

  final String text;
  final bool below;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!below) _bubbleButtonOrText(),
        Icon(Icons.arrow_drop_down_rounded, size: 22, color: accent),
        if (below) _bubbleButtonOrText(),
      ],
    );
  }

  Widget _bubbleButtonOrText() {
    return Container(
      height: kBubbleHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0C132C).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent, width: 2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
