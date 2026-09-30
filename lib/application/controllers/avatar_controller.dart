import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/avatar_physics.dart';
import '../state/avatar_reaction_policy.dart';
import '../state/avatar_state.dart';

/// Owns the companion's pose, screen position, and continuous non-stop flying behaviors.
class AvatarController extends StateNotifier<AvatarState> {
  AvatarController({this.flightHold = const Duration(seconds: 10)})
    : super(
        const AvatarState(
          idleAction: AvatarIdleAction.flying,
          flightStyle: FlightStyle.circle,
        ),
      ) {
    _startFlightStyleSwitcher();
  }

  /// How long the companion hovers where the child dropped it before it eases
  /// back into its flight circuit. Long enough that a child who has just parked
  /// the toy sees it stay put, short enough that the companion is not dead.
  final Duration flightHold;

  Timer? _styleTimer;
  Timer? _reactionTimer;
  Timer? _holdTimer;
  bool _disposed = false;
  final math.Random _random = math.Random();

  /// Distance between the canonical flight path and where the companion
  /// actually is, because the child dragged it off the path.
  ///
  /// Flight resumes from the parked spot instead of snapping back onto the
  /// path: this offset decays to zero, so the companion drifts into its next
  /// circuit from wherever it was let go.
  Offset _flightRebase = Offset.zero;

  /// Path parameter, accumulated a frame at a time rather than derived from
  /// [AvatarState.flightTime]. A reaction that changes the flight speed then
  /// changes how fast this advances, instead of jumping along the path.
  double _pathTime = 0;

  /// Last bounds the widget computed, needed to place a resumed flight.
  Offset _maxPosition = const Offset(350, 700);

  /// Seconds for the rebase offset to fall by a factor of e.
  static const double _rebaseTimeConstant = 1.6;

  /// The flying speed before reactions: brisk and lively.
  static const double _baseFlightRate = 1.8;

  void _startFlightStyleSwitcher() {
    // Switch flight patterns (circle -> zigzag -> edge) every 6 seconds for variety
    _styleTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      final styles = FlightStyle.values;
      final nextStyle = styles[_random.nextInt(styles.length)];
      state = state.copyWith(
        idleAction: AvatarIdleAction.flying,
        flightStyle: nextStyle,
      );
    });
  }

  /// The flight path's own position at path time [t], before any rebase.
  Offset _flightPathAt(double t, Offset maxPosition) {
    final w = maxPosition.dx;
    final h = maxPosition.dy;

    switch (state.flightStyle) {
      case FlightStyle.circle:
        final cx = w / 2;
        final cy = h / 2;
        final rx = w * 0.40;
        final ry = h * 0.35;
        final x = cx + rx * math.cos(t);
        final y = cy + ry * math.sin(t * 1.3);
        return _clampTo(Offset(x, y), maxPosition);

      case FlightStyle.zigzag:
        final progress = (t * 0.5) % 2.0;
        final x = progress <= 1.0 ? progress * w : (2.0 - progress) * w;
        final y = h * 0.5 + (math.sin(t * 5.0) * h * 0.4);
        return _clampTo(Offset(x, y), maxPosition);

      case FlightStyle.edge:
        final perimeter = 2 * (w + h);
        if (perimeter <= 0) return Offset.zero;
        final dist = (t * 140.0) % perimeter;
        double x = 0, y = 0;
        if (dist < w) {
          x = dist;
          y = 0;
        } else if (dist < w + h) {
          x = w;
          y = dist - w;
        } else if (dist < 2 * w + h) {
          x = w - (dist - (w + h));
          y = h;
        } else {
          x = 0;
          y = h - (dist - (2 * w + h));
        }
        return _clampTo(Offset(x, y), maxPosition);
    }
  }

  /// Holds a position inside the region the companion may occupy.
  ///
  /// The minimum is passed in rather than assumed to be the origin because the
  /// top and left of the screen are not the edge of the playable area: the
  /// status bar, the top bar and the toy-sized margin all sit inside the window,
  /// and a drag that only respected the far corner could slide the toy under
  /// all of them, where the child could neither see nor grab it.
  Offset _clampTo(
    Offset position,
    Offset maxPosition, [
    Offset minPosition = Offset.zero,
  ]) {
    // The bounds are ordered rather than merely sanitised, because a region too
    // small for the toy has to collapse to a point rather than throw: a split
    // screen on a small phone really can leave less room than the toy needs.
    final maxX = math.max(0.0, maxPosition.dx);
    final maxY = math.max(0.0, maxPosition.dy);
    return Offset(
      position.dx.clamp(math.min(minPosition.dx, maxX), maxX),
      position.dy.clamp(math.min(minPosition.dy, maxY), maxY),
    );
  }

  /// The throw simulation, which owns the position, velocity and roll of a
  /// thrown companion.
  ///
  /// A throw has to survive a rebuild of the Explorer screen mid-flight, so it
  /// cannot live in a widget; and it has to be testable without a frame
  /// callback, so it cannot depend on one. Holding it here gives it both, and
  /// keeps the physics itself as plain Dart in [AvatarPhysics].
  final AvatarPhysics _physics = AvatarPhysics();

  /// The bounces from the most recent [updateFlight], for the caller to react
  /// to with a sound and a squash.
  ///
  /// The simulation reports these rather than playing them, because playing a
  /// sound and animating a squash both belong to the widget layer.
  List<AvatarBounce> _lastBounces = const [];

  /// Bounces the most recent [updateFlight] reported, clearing them.
  List<AvatarBounce> takeBounces() {
    if (_lastBounces.isEmpty) return const [];
    final taken = _lastBounces;
    _lastBounces = const [];
    return taken;
  }

  /// Whether a throw is still in progress.
  ///
  /// The caller needs this because a thrown companion is parked as well as
  /// moving: the flight loop is paused for it, so the pause cannot be used to
  /// decide whether to keep stepping the physics.
  bool get isThrowing => _physics.isThrowing;

  /// Launches the companion with initial [velocity] (pixels/sec) after a flick.
  ///
  /// [minPosition] defaults to the origin, which is where the flight path
  /// starts, so a caller that does not know about the bars can still throw.
  void launchWithVelocity({
    required Offset velocity,
    required Offset maxPosition,
    Offset minPosition = Offset.zero,
  }) {
    _maxPosition = maxPosition;
    final start = state.screenPosition;
    if (start != null) _physics.placeAt(start);

    // The throw continues the roll the child may have set up with two fingers,
    // rather than snapping the toy level the moment it is let go.
    _physics.setRotation(yaw: state.yaw, pitch: state.pitch);
    _physics.launch(velocity);

    state = state.copyWith(velocity: _physics.velocity, isFlightPaused: true);

    // A throw is not a park. The hold timer is deliberately not restarted here:
    // it would end the throw early by sliding the companion back onto its
    // flight path mid-bounce. The throw ends when the simulation says it has.
    if (!_physics.isThrowing) _restartHold();
  }

  /// Cancels any active throw momentum.
  void stopMomentum() {
    _physics.stop();
    if (state.velocity != Offset.zero) {
      state = state.copyWith(velocity: Offset.zero);
    }
  }

  void _updateThrowPhysics(double dt, AvatarBounds bounds) {
    _lastBounces = _physics.step(dt, bounds);

    state = state.copyWith(
      screenPosition: _physics.position,
      velocity: _physics.velocity,
      yaw: _physics.yaw,
      pitch: _physics.pitch.clamp(
        -AvatarState.pitchLimit,
        AvatarState.pitchLimit,
      ),
      isFlightPaused: true,
    );

    // The throw is over once the simulation says so, at which point the
    // companion parks exactly where it settled rather than snapping anywhere.
    if (!_physics.isThrowing) {
      _lastBounces = const [];
      _restartHold();
    }
  }

  /// Updates continuous non-stop flight movement along the chosen path.
  ///
  /// [minPosition] is the other edge of the region the companion may occupy.
  /// The flight path is only ever asked for a maximum, because the path it
  /// follows starts at the origin; a throw needs both edges, since the top and
  /// left of the screen are taken by the status bar and the top bar.
  void updateFlight(
    double dt,
    Size viewport,
    Offset maxPosition, {
    Offset minPosition = Offset.zero,
  }) {
    _maxPosition = maxPosition;

    // An active throw takes precedence over the flight path, and is checked
    // before the pause below: a thrown companion is parked as well as moving,
    // so `isFlightPaused` alone would stop the throw on its very first frame.
    if (_physics.isThrowing) {
      _updateThrowPhysics(dt, AvatarBounds(min: minPosition, max: maxPosition));
      return;
    }

    // While the companion is parked there is no flight to update: standing
    // still is the whole point of the pause.
    if (state.isFlightPaused) return;

    _pathTime += dt * _baseFlightRate * reactionSpeedFactor(state.reaction);
    _flightRebase *= math.exp(-dt / _rebaseTimeConstant);
    if (_flightRebase.distanceSquared < 0.01) _flightRebase = Offset.zero;

    final position = _clampTo(
      _flightPathAt(_pathTime, maxPosition) + _flightRebase,
      maxPosition,
    );

    state = state.copyWith(
      screenPosition: position,
      flightTime: state.flightTime + dt,
      idleAction: AvatarIdleAction.flying,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _styleTimer?.cancel();
    _reactionTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  /// Pins the flight path so each [FlightStyle] branch of [updateFlight] can
  /// be exercised deterministically; in production the 6s switcher owns it.
  @visibleForTesting
  void debugSetFlightStyle(FlightStyle style) {
    state = state.copyWith(flightStyle: style);
  }

  /// Turns reduced motion on or off for a throw already in flight.
  ///
  /// The platform can change this preference while the app is running, and the
  /// platform is also what a reader uses to ask for calmer motion at all, so
  /// the simulation has to be told rather than deciding for itself. It is
  /// applied to the flight in progress as well as the next one: a throw that
  /// was already under way when the preference was switched on should calm
  /// down, not finish at the speed it started.
  void setReducedMotion(bool reducedMotion) {
    _physics.reducedMotion = reducedMotion;
  }

  void react(
    AvatarReaction reaction, {
    Duration duration = const Duration(milliseconds: 900),
  }) {
    _reactionTimer?.cancel();
    // `none` is the resting state rather than a reaction, so reacting with it
    // simply clears whatever is playing instead of starting a timer for it.
    if (reaction == AvatarReaction.none) {
      clearReaction();
      return;
    }
    state = state.copyWith(
      reaction: reaction,
      reactionUntil:
          DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds,
      // Cheerful reactions carry the heart pose with them (`sendingHeart`),
      // so the idle layer agrees with the face: the bubble text, the porthole
      // tint and the SFX all read the same celebration rather than three
      // different ones. Non-cheerful reactions leave the idle alone — except
      // dizzy, which borrows the thinking tilt for its wobble.
      idleAction: reactionShowsHearts(reaction)
          ? AvatarIdleAction.sendingHeart
          : reaction == AvatarReaction.dizzy
              ? AvatarIdleAction.thinking
              : state.idleAction,
      isHeartVisible: reactionShowsHearts(reaction),
    );
    // A plain timestamp cannot clear itself, so the controller owns a single
    // cancellable timer per reaction. The disposed guard keeps a late timer
    // from touching state after the provider is gone, and cancelling first
    // keeps a newer reaction from being cleared early by an older timer.
    _reactionTimer = Timer(duration, () {
      if (_disposed || !mounted) return;
      clearReaction();
    });
  }

  void clearReaction() {
    _reactionTimer?.cancel();
    _reactionTimer = null;
    if (state.reaction == AvatarReaction.none && !state.isHeartVisible) return;
    state = state.copyWith(
      reaction: AvatarReaction.none,
      reactionUntil: 0,
      isHeartVisible: false,
    );
  }

  void rotateBy({required double dx, required double dy}) {
    const yawPerPixel = 0.012;
    const pitchPerPixel = 0.008;
    state = state.copyWith(
      yaw: state.yaw + dx * yawPerPixel,
      pitch: (state.pitch + dy * pitchPerPixel).clamp(
        -AvatarState.pitchLimit,
        AvatarState.pitchLimit,
      ),
    );
  }

  /// Drags the companion to a new spot and parks it there for [flightHold].
  ///
  /// Moving never re-aims the model: the pose is the child's own 3D work and a
  /// drag is only about where the toy sits.
  void moveBy({
    required Offset delta,
    required Offset maxPosition,
    Offset minPosition = Offset.zero,
  }) {
    stopMomentum();
    final current = state.screenPosition;
    if (current == null) return;
    _maxPosition = maxPosition;
    final moved = _clampTo(current + delta, maxPosition, minPosition);
    // The simulation owns the position, so it has to be moved with the finger.
    // Otherwise the next throw would launch from wherever the last one ended
    // rather than from where the child actually let the toy go.
    _physics.placeAt(moved);
    state = state.copyWith(screenPosition: moved, isFlightPaused: true);
    _restartHold();
  }

  /// Ends a drag-induced pause and eases flight back in from the parked spot.
  void resumeFlight() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!state.isFlightPaused) return;
    final position = state.screenPosition;
    // Rebasing here, rather than when the drag ended, uses the position the
    // companion actually holds at the moment flight restarts.
    if (position != null) _rebaseFlightFrom(position);
    state = state.copyWith(isFlightPaused: false);
  }

  void _restartHold() {
    _holdTimer?.cancel();
    _holdTimer = Timer(flightHold, () {
      if (_disposed || !mounted) return;
      resumeFlight();
    });
  }

  void _rebaseFlightFrom(Offset position) {
    _flightRebase = position - _flightPathAt(_pathTime, _maxPosition);
  }

  void placeAt(
    Offset position, {
    Offset? maxPosition,
    Offset minPosition = Offset.zero,
  }) {
    // The simulation is moved first, and unconditionally. A placement that set
    // the state without moving the simulation would look right until the next
    // frame, when the frame loop wrote the simulation's position straight back
    // over it and the toy appeared to snap to wherever it had been before.
    final clamped = maxPosition == null
        ? position
        : _clampTo(position, maxPosition, minPosition);
    _physics.placeAt(clamped);

    if (maxPosition != null) {
      _maxPosition = maxPosition;
      // The opening placement is off the flight path too, so it rebases: the
      // companion eases out of its home corner into its first circuit.
      _rebaseFlightFrom(clamped);
    }
    state = state.copyWith(screenPosition: clamped);
  }

  void resetPositionTo(Offset position, {Offset? maxPosition}) =>
      placeAt(position, maxPosition: maxPosition);
}

final avatarControllerProvider =
    StateNotifierProvider<AvatarController, AvatarState>(
      (ref) => AvatarController(),
    );
