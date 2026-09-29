import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/avatar_state.dart';

/// Owns the companion's pose, screen position, and continuous non-stop flying behaviors.
class AvatarController extends StateNotifier<AvatarState> {
  AvatarController()
      : super(const AvatarState(
          idleAction: AvatarIdleAction.flying,
          flightStyle: FlightStyle.circle,
        )) {
    _startFlightStyleSwitcher();
  }

  Timer? _styleTimer;
  final math.Random _random = math.Random();
  Offset? _lastMaxPosition;
  Size? _lastViewport;

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

  /// Updates continuous non-stop flight movement along chosen path (edge, zigzag, circle)
  void updateFlight(double dt, Size viewport, Offset maxPosition) {
    _lastViewport = viewport;
    _lastMaxPosition = maxPosition;

    final newTime = state.flightTime + dt;
    final t = newTime * 1.8; // brisk, lively flight speed

    Offset pos;
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
        pos = Offset(x.clamp(0.0, w), y.clamp(0.0, h));
        break;

      case FlightStyle.zigzag:
        final progress = (t * 0.5) % 2.0;
        final x = progress <= 1.0 ? progress * w : (2.0 - progress) * w;
        final y = h * 0.5 + (math.sin(t * 5.0) * h * 0.4);
        pos = Offset(x.clamp(0.0, w), y.clamp(0.0, h));
        break;

      case FlightStyle.edge:
        final perimeter = 2 * (w + h);
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
        pos = Offset(x.clamp(0.0, w), y.clamp(0.0, h));
        break;
    }

    state = state.copyWith(
      screenPosition: pos,
      flightTime: newTime,
      idleAction: AvatarIdleAction.flying, // Always flying non-stop!
    );
  }

  @override
  void dispose() {
    _styleTimer?.cancel();
    super.dispose();
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

  void moveBy({
    required Offset delta,
    required Offset maxPosition,
  }) {
    _lastMaxPosition = maxPosition;
    final current = state.screenPosition;
    if (current == null) return;
    state = state.copyWith(
      screenPosition: Offset(
        (current.dx + delta.dx).clamp(0.0, maxPosition.dx),
        (current.dy + delta.dy).clamp(0.0, maxPosition.dy),
      ),
    );
  }

  void placeAt(Offset position, {Offset? maxPosition}) {
    if (maxPosition != null) {
      _lastMaxPosition = maxPosition;
      state = state.copyWith(
        screenPosition: Offset(
          position.dx.clamp(0.0, maxPosition.dx),
          position.dy.clamp(0.0, maxPosition.dy),
        ),
      );
    } else {
      state = state.copyWith(screenPosition: position);
    }
  }

  void resetPositionTo(Offset position, {Offset? maxPosition}) =>
      placeAt(position, maxPosition: maxPosition);
}

final avatarControllerProvider =
    StateNotifierProvider<AvatarController, AvatarState>(
  (ref) => AvatarController(),
);
