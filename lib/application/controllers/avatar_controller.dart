import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/avatar_reaction_policy.dart';
import '../state/avatar_state.dart';

/// Owns the companion's pose, screen position, and continuous non-stop flying behaviors.
class AvatarController extends StateNotifier<AvatarState> {
  AvatarController({this.flightHold = const Duration(seconds: 10)})
      : super(const AvatarState(
          idleAction: AvatarIdleAction.flying,
          flightStyle: FlightStyle.circle,
        )) {
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

  Offset _clampTo(Offset position, Offset maxPosition) => Offset(
        position.dx.clamp(0.0, math.max(0.0, maxPosition.dx)),
        position.dy.clamp(0.0, math.max(0.0, maxPosition.dy)),
      );

  /// Current throw momentum velocity in pixels per second.
  Offset _throwVelocity = Offset.zero;

  /// Bounce coefficient for screen edge collisions (0.5 - 0.75).
  static const double _bounceFactor = 0.65;

  /// Exponential friction coefficient for decelerating after a throw.
  static const double _throwFrictionCoeff = 3.0;

  /// Launches the companion with initial [velocity] (pixels/sec) after a flick.
  void launchWithVelocity({
    required Offset velocity,
    required Offset maxPosition,
  }) {
    _maxPosition = maxPosition;
    // Cap maximum throw speed so a super-fast flick stays playful and controllable
    const double maxSpeed = 3200.0;
    final speed = velocity.distance;

    if (speed < 50.0) {
      stopMomentum();
      _restartHold();
      return;
    }

    final clampedVelocity = speed > maxSpeed ? velocity * (maxSpeed / speed) : velocity;
    _throwVelocity = clampedVelocity;

    state = state.copyWith(
      velocity: _throwVelocity,
      isFlightPaused: true,
    );
    _restartHold();
  }

  /// Cancels any active throw momentum.
  void stopMomentum() {
    _throwVelocity = Offset.zero;
    if (state.velocity != Offset.zero) {
      state = state.copyWith(velocity: Offset.zero);
    }
  }

  void _updateMomentumPhysics(double dt, Offset maxPosition) {
    if (_throwVelocity.distanceSquared < 100.0) { // < 10 px/s
      stopMomentum();
      _restartHold();
      return;
    }

    // Apply smooth deceleration
    _throwVelocity *= math.exp(-_throwFrictionCoeff * dt);

    final currentPos = state.screenPosition ?? Offset.zero;
    var nextX = currentPos.dx + _throwVelocity.dx * dt;
    var nextY = currentPos.dy + _throwVelocity.dy * dt;

    var vx = _throwVelocity.dx;
    var vy = _throwVelocity.dy;

    // Bounce off left/right edges
    if (nextX <= 0.0) {
      nextX = 0.0;
      vx = -vx * _bounceFactor;
    } else if (nextX >= maxPosition.dx) {
      nextX = maxPosition.dx;
      vx = -vx * _bounceFactor;
    }

    // Bounce off top/bottom edges
    if (nextY <= 0.0) {
      nextY = 0.0;
      vy = -vy * _bounceFactor;
    } else if (nextY >= maxPosition.dy) {
      nextY = maxPosition.dy;
      vy = -vy * _bounceFactor;
    }

    _throwVelocity = Offset(vx, vy);
    final clampedPos = _clampTo(Offset(nextX, nextY), maxPosition);

    // Subtle 3D spin and tilt proportional to velocity
    final spinDx = vx * dt * 0.006;
    final spinDy = vy * dt * 0.004;
    final newYaw = state.yaw + spinDx;
    final newPitch = (state.pitch + spinDy)
        .clamp(-AvatarState.pitchLimit, AvatarState.pitchLimit);

    if (_throwVelocity.distance < 15.0) {
      _throwVelocity = Offset.zero;
      state = state.copyWith(
        screenPosition: clampedPos,
        velocity: Offset.zero,
        yaw: newYaw,
        pitch: newPitch,
        isFlightPaused: true,
      );
      _restartHold();
    } else {
      state = state.copyWith(
        screenPosition: clampedPos,
        velocity: _throwVelocity,
        yaw: newYaw,
        pitch: newPitch,
        isFlightPaused: true,
      );
    }
  }

  /// Updates continuous non-stop flight movement along the chosen path.
  void updateFlight(double dt, Size viewport, Offset maxPosition) {
    _maxPosition = maxPosition;

    // Active throw momentum physics takes precedence while decelerating
    if (_throwVelocity.distanceSquared > 100.0) {
      _updateMomentumPhysics(dt, maxPosition);
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
      idleAction: reaction == AvatarReaction.dizzy
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
      pitch: (state.pitch + dy * pitchPerPixel)
          .clamp(-AvatarState.pitchLimit, AvatarState.pitchLimit),
    );
  }

  /// Drags the companion to a new spot and parks it there for [flightHold].
  ///
  /// Moving never re-aims the model: the pose is the child's own 3D work and a
  /// drag is only about where the toy sits.
  void moveBy({
    required Offset delta,
    required Offset maxPosition,
  }) {
    stopMomentum();
    final current = state.screenPosition;
    if (current == null) return;
    _maxPosition = maxPosition;
    state = state.copyWith(
      screenPosition: _clampTo(current + delta, maxPosition),
      isFlightPaused: true,
    );
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

  void placeAt(Offset position, {Offset? maxPosition}) {
    if (maxPosition == null) {
      state = state.copyWith(screenPosition: position);
      return;
    }
    _maxPosition = maxPosition;
    final clamped = _clampTo(position, maxPosition);
    // The opening placement is off the flight path too, so it rebases: the
    // companion eases out of its home corner into its first circuit.
    _rebaseFlightFrom(clamped);
    state = state.copyWith(screenPosition: clamped);
  }

  void resetPositionTo(Offset position, {Offset? maxPosition}) =>
      placeAt(position, maxPosition: maxPosition);
}

final avatarControllerProvider =
    StateNotifierProvider<AvatarController, AvatarState>(
  (ref) => AvatarController(),
);
