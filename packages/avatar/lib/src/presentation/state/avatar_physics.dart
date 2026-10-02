import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'avatar_physics_config.dart';

/// A bounce the toy just made, and how hard it hit.
///
/// The simulation reports these rather than reacting to them itself, because
/// reacting means a sound and a squash, and both of those belong to the widget
/// layer. Keeping the simulation free of them is what lets it be tested with
/// nothing but a number and an [Offset].
class AvatarBounce {
  const AvatarBounce(this.axis, this.impactSpeed);

  /// Which wall was hit.
  final BounceAxis axis;

  /// How fast the toy was moving into the wall, in pixels per second, before
  /// the bounce. This is the number both the sound volume and the squash
  /// strength are derived from.
  final double impactSpeed;
}

enum BounceAxis { horizontal, vertical }

/// The rectangle the companion's top-left corner may range over.
///
/// Both edges are needed, not just the maximum. The companion lives in a
/// full-viewport stack, so the top and left edges of its usable area are pushed
/// inwards by the status bar, the top bar and any safe-area inset. A maximum
/// alone would assume the origin, which would let a bounced toy come to rest
/// underneath the top bar, hidden behind the child's own navigation.
class AvatarBounds {
  const AvatarBounds({this.min = Offset.zero, this.max = Offset.zero});

  /// A region anchored at the origin, the shape the flight path was written
  /// against. Used wherever no layout has been measured yet.
  static const AvatarBounds fromOrigin = AvatarBounds();

  /// The top-left-most position the companion's box may occupy.
  final Offset min;

  /// The bottom-right-most position the companion's box may occupy.
  final Offset max;

  /// Whether there is anywhere to move at all.
  ///
  /// A collapsed region means the window is smaller than the toy plus its
  /// insets, in which case a throw could only ever snap to a single point.
  bool get isUsable =>
      max.dx - min.dx > AvatarPhysicsConfig.minRunnableExtent &&
      max.dy - min.dy > AvatarPhysicsConfig.minRunnableExtent;

  /// Pulls a position into this region.
  Offset clamp(Offset position) => Offset(
    position.dx.clamp(math.min(min.dx, max.dx), math.max(min.dx, max.dx)),
    position.dy.clamp(math.min(min.dy, max.dy), math.max(min.dy, max.dy)),
  );

  /// The largest this region can be, given [size] and [padding] insets and the
  /// chrome to keep clear.
  factory AvatarBounds.available({
    required double width,
    required double height,
    required double boxWidth,
    required double boxHeight,
    required double leftInset,
    required double topInset,
    required double rightInset,
    required double bottomInset,
    double edgePadding = 0,
  }) {
    // The clamps are what make this safe on a window too small for the toy: the
    // naive expressions would invert, and an inverted clamp throws.
    final minX = (leftInset + edgePadding).clamp(
      0.0,
      (width - boxWidth).clamp(0.0, double.infinity),
    );
    final minY = (topInset + edgePadding).clamp(
      0.0,
      (height - boxHeight).clamp(0.0, double.infinity),
    );
    final maxX = (width - boxWidth - rightInset - edgePadding).clamp(
      minX,
      double.infinity,
    );
    final maxY = (height - boxHeight - bottomInset - edgePadding).clamp(
      minY,
      double.infinity,
    );
    return AvatarBounds(min: Offset(minX, minY), max: Offset(maxX, maxY));
  }
}

/// The throw simulation for the mission companion: where a released fling goes,
/// how it loses energy, how it bounces off the edges of the usable area and how
/// it rolls while it does.
///
/// This is deliberately a plain object with no Flutter, widget or GPU
/// dependency, and it owns no clock of its own: the caller supplies the frame
/// delta. That is what makes a throw testable by stepping a fixed timestep
/// rather than by pumping a real frame callback, and it is why the same code
/// behaves identically at 30 fps and at 120 fps.
///
/// The companion's position, its velocity and its spin all live here rather
/// than in the widget, so a throw survives a rebuild of the Explorer screen
/// mid-flight instead of restarting from wherever the last frame happened to
/// leave it.
class AvatarPhysics {
  AvatarPhysics({this.reducedMotion = false});

  /// Whether to damp everything down for a reader who has asked for less
  /// motion. Treated as a shorter, calmer throw with the same gesture, rather
  /// than no throw at all, so the toy still goes where it was thrown.
  ///
  /// Settable rather than final because the preference can be turned on while
  /// the app is running. A `final` field would silently keep throwing at full
  /// strength for a reader who had asked otherwise, since nothing would ever
  /// reach the value again.
  bool reducedMotion;

  Offset _position = Offset.zero;
  Offset _velocity = Offset.zero;
  double _yaw = 0;
  double _pitch = 0;

  /// Current speed in logical pixels per second.
  Offset get velocity => _velocity;

  /// Top-left corner of the companion's box, in logical pixels.
  Offset get position => _position;

  double get yaw => _yaw;

  double get pitch => _pitch;

  /// Whether a throw is still in progress.
  bool get isThrowing => _velocity.distance > AvatarPhysicsConfig.stopVelocity;

  /// Where the toy is put directly, with no momentum.
  ///
  /// Used for the opening placement and for a drag: a drag moves the toy, it
  /// does not launch it, so any momentum from a previous throw is dropped here
  /// rather than being allowed to fight the finger.
  void placeAt(Offset position) {
    _position = position;
    _velocity = Offset.zero;
  }

  /// Adopts a pose the toy is already holding, so a throw continues the roll
  /// the child set up with two fingers instead of snapping it back to level.
  void setRotation({required double yaw, required double pitch}) {
    _yaw = yaw;
    _pitch = pitch;
  }

  /// Starts a throw with [velocity] in logical pixels per second.
  ///
  /// The speed is capped so a pointer spike cannot launch the toy off screen,
  /// and a throw below [AvatarPhysicsConfig.minThrowVelocity] is discarded
  /// entirely: at that speed the toy would creep a few pixels and stop, which
  /// is the snap the throw exists to replace.
  void launch(Offset velocity) {
    final speed = velocity.distance;
    if (speed < AvatarPhysicsConfig.minThrowVelocity) {
      _velocity = Offset.zero;
      return;
    }
    final capped = math.min(speed, AvatarPhysicsConfig.maxThrowVelocity);
    _velocity = velocity * (capped / speed);
  }

  /// Advances the simulation by [deltaSeconds] within [bounds].
  ///
  /// Returns every bounce that happened this step, in the order they occurred,
  /// so a corner hit reports both axes. An empty list means the frame passed
  /// without the toy touching anything.
  List<AvatarBounce> step(double deltaSeconds, AvatarBounds bounds) {
    if (!isThrowing) return const [];

    // A frame longer than the clamp means the app was not rendering (a
    // backgrounded tab, a stalled frame). Integrating the real delta would
    // teleport the toy across the screen, so the excess is dropped instead.
    final dt = deltaSeconds.clamp(0.0, AvatarPhysicsConfig.maxDeltaTime);
    if (dt <= 0.0) return const [];

    // Friction is a per-frame constant, so it is raised to the power of the
    // frames this step is worth. That is what keeps a throw's total travel
    // independent of the frame rate: without it, a 120 Hz display would bleed
    // off twice the energy per second and every throw would die at half the
    // distance.
    _velocity *= math.pow(AvatarPhysicsConfig.friction, dt * 60.0).toDouble();

    final bounces = _advance(_velocity * dt, bounds);

    _roll(dt);
    if (reducedMotion) {
      // A little extra bleed, so a calm throw also settles sooner. The pose is
      // left alone: decaying the accumulated roll would drag the toy back to
      // level and fight the two-finger rotation the child just set up.
      _velocity *= math
          .pow(AvatarPhysicsConfig.reducedMotionDamping, dt * 60.0)
          .toDouble();
    }

    // Settle exactly rather than creeping. Below the stop threshold the
    // remaining speed cannot move the toy a visible distance in a frame, and
    // leaving it live would keep a rebuild and a ticker running for movement
    // nobody can see.
    if (_velocity.distance <= AvatarPhysicsConfig.stopVelocity) {
      _velocity = Offset.zero;
    }

    return bounces;
  }

  /// Moves the toy by [travel], reflecting it off [bounds] as many times as it
  /// takes to get there.
  ///
  /// Reflection happens per wall rather than once per frame because a hard
  /// throw covers a large distance in a single frame: at the cap, one clamped
  /// frame can carry the toy further than a small window is wide, and a single
  /// reflection at the end of it would let the toy pass straight through a wall
  /// and come out the other side.
  List<AvatarBounce> _advance(Offset travel, AvatarBounds bounds) {
    final bounces = <AvatarBounce>[];

    // Each reflection loses energy, so this terminates on its own; the counter
    // is only there so a degenerate region cannot spin forever.
    for (var i = 0; i < AvatarPhysicsConfig.maxBouncesPerStep; i++) {
      final hit = _wallHit(travel, bounds);
      if (hit == null) {
        // Clear of every wall: the rest of the frame is spent travelling.
        _position += travel;
        break;
      }

      // Reach the wall, report the impact, then carry on with what was left of
      // the frame's travel, reflected and already reduced by the bounce.
      _position += hit.travelToWall;

      // The impact is the speed the toy was carrying into the wall, read off
      // the velocity rather than off how far this frame happened to travel. The
      // two are proportional, but only the speed is comparable between a long
      // frame and a short one, and it is the speed that decides how loud an
      // impact sounds and how hard the toy squashes.
      final bounce = AvatarBounce(
        hit.axis,
        hit.axis == BounceAxis.horizontal
            ? _velocity.dx.abs()
            : _velocity.dy.abs(),
      );
      bounces.add(bounce);
      _kick(bounce);

      if (_velocity.distance <= AvatarPhysicsConfig.stopVelocity) {
        // Too slow to bounce meaningfully. The toy comes to rest against the
        // wall, which is what dropping something slowly against a wall does,
        // and reporting a bounce here would only be a buzz.
        _velocity = Offset.zero;
        break;
      }

      // Only the axis that hit is reversed, and it is reversed in *both*
      // branches. Leaving the vertical sign alone would let a throw launched
      // upwards carry straight on through the top of the screen.
      _velocity = switch (hit.axis) {
        BounceAxis.horizontal => Offset(
          -_velocity.dx * AvatarPhysicsConfig.restitution,
          _velocity.dy,
        ),
        BounceAxis.vertical => Offset(
          _velocity.dx,
          -_velocity.dy * AvatarPhysicsConfig.restitution,
        ),
      };

      // The overshoot is scaled too, because it is travelled at the post-bounce
      // speed rather than the one the frame started with.
      travel = _reflected(
        hit.remaining * AvatarPhysicsConfig.restitution,
        hit.axis,
      );
    }

    _position = bounds.clamp(_position);
    return bounces;
  }

  /// The first wall [travel] runs into, and where along it.
  _WallHit? _wallHit(Offset travel, AvatarBounds bounds) {
    final wall = _nextWall(travel, bounds);
    if (wall == null) return null;

    final t = wall.distance / wall.along;
    final travelToWall = travel * t;
    return _WallHit(
      travelToWall: travelToWall,
      remaining: travel - travelToWall,
      axis: wall.axis,
    );
  }

  /// The wall nearest along [travel], or `null` if the toy reaches none.
  ///
  /// A per-axis distance, keeping whichever is nearer along the path, is what
  /// makes a corner hit report the wall the toy actually arrives at first
  /// rather than whichever axis happened to be checked first.
  ///
  /// The axis is decided here rather than from the direction of travel on
  /// purpose. Reading it off the travel instead would call a throw to the right
  /// a vertical hit, and the toy would sail through the right-hand wall.
  _Wall? _nextWall(Offset travel, AvatarBounds bounds) {
    _Wall? nearest;
    if (travel.dx < 0) {
      nearest = _nearer(
        nearest,
        BounceAxis.horizontal,
        _position.dx - bounds.min.dx,
        -travel.dx,
      );
    } else if (travel.dx > 0) {
      nearest = _nearer(
        nearest,
        BounceAxis.horizontal,
        bounds.max.dx - _position.dx,
        travel.dx,
      );
    }
    if (travel.dy < 0) {
      nearest = _nearer(
        nearest,
        BounceAxis.vertical,
        _position.dy - bounds.min.dy,
        -travel.dy,
      );
    } else if (travel.dy > 0) {
      nearest = _nearer(
        nearest,
        BounceAxis.vertical,
        bounds.max.dy - _position.dy,
        travel.dy,
      );
    }
    return nearest;
  }

  /// [current] if it is the wall the toy reaches first, and the nearer of the
  /// two, or `current] if the candidate is not a wall this frame reaches.
  ///
  /// A distance of exactly zero is a real hit, not a rounding artefact. The toy
  /// is placed exactly on a wall when it bounces, so in a corner the toy is on
  /// the second wall at the moment it rebounds off the first; rejecting that as
  /// "already touching" would swallow the second bounce entirely and leave the
  /// toy sliding along the edge with a wall it never reported.
  ///
  /// It cannot turn into a per-frame buzz either, because a hit reverses the
  /// component that caused it and the toy then moves away from that wall. Only
  /// a region too small to move in would repeat, and that is bounded by
  /// [AvatarPhysicsConfig.maxBouncesPerStep].
  _Wall? _nearer(
    _Wall? current,
    BounceAxis axis,
    double distance,
    double along,
  ) {
    if (distance < 0 || along <= 0) return current;
    if (distance / along > 1.0) return current;
    if (current != null &&
        current.distance / current.along <= distance / along) {
      return current;
    }
    return _Wall(axis, distance, along);
  }

  /// The part of a frame's travel that still lies beyond a wall, mirrored onto
  /// the near side of it.
  ///
  /// The overshoot is *negated*, not merely made positive. The toy is placed
  /// exactly on the wall when it bounces, so an overshoot still pointing the
  /// way the toy came would drive it straight back through the wall it just
  /// hit, and the next wall test would read a distance of zero and bounce it a
  /// second time in the same frame.
  Offset _reflected(Offset overshoot, BounceAxis axis) =>
      axis == BounceAxis.horizontal
      ? Offset(-overshoot.dx, overshoot.dy)
      : Offset(overshoot.dx, -overshoot.dy);

  /// Spins the toy in proportion to how it is moving.
  ///
  /// A thrown ball spins because it is moving, and the spin is what sells it as
  /// a solid object rather than a picture sliding around. A horizontal throw
  /// spins it about the vertical axis (yaw) and a vertical one tips it (pitch),
  /// at a weaker rate so an upright rocket does not read as tumbling over on
  /// every throw.
  ///
  /// The rate is capped, because a fast throw would otherwise spin so quickly
  /// that the toy becomes a blur: the cap is what keeps a hard fling readable
  /// as the same object turning over a few times, rather than as noise.
  void _roll(double dt) {
    final cap = AvatarPhysicsConfig.maxSpin;
    _yaw +=
        (_velocity.dx * AvatarPhysicsConfig.spinPerPixel).clamp(-cap, cap) * dt;
    _pitch +=
        (_velocity.dy * AvatarPhysicsConfig.tipPerPixel).clamp(-cap, cap) * dt;
  }

  /// Spins the toy a little on impact, on top of reversing it.
  ///
  /// This is what makes a bounce read as the toy being knocked rather than as
  /// its motion glitching: the reversal alone is a discontinuity, and a small
  /// turn in the same moment is what the eye reads as contact. Reduced motion
  /// keeps the reversal and drops the kick, since the kick is the most
  /// eye-catching part of the bounce.
  void _kick(AvatarBounce bounce) {
    if (reducedMotion) return;
    final strength = (bounce.impactSpeed / AvatarPhysicsConfig.maxThrowVelocity)
        .clamp(0.0, 1.0);
    final turn = AvatarPhysicsConfig.impactKick * strength;
    if (bounce.axis == BounceAxis.horizontal) {
      _yaw += turn;
    } else {
      _pitch += turn;
    }
  }

  /// Stops the toy where it is, dropping any momentum.
  void stop() => _velocity = Offset.zero;
}

/// A wall the toy is heading towards, and how far along it is.
class _Wall {
  const _Wall(this.axis, this.distance, this.along);

  final BounceAxis axis;

  /// The distance from the toy to the wall.
  final double distance;

  /// The distance the toy would travel this frame along that axis.
  final double along;
}

/// Where in a step the toy met a wall.
class _WallHit {
  const _WallHit({
    required this.travelToWall,
    required this.remaining,
    required this.axis,
  });

  /// The part of the frame's travel that reaches the wall.
  final Offset travelToWall;

  /// The part that would have gone past it.
  final Offset remaining;

  /// Which wall it was.
  final BounceAxis axis;
}
