import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:planets/state.dart';
import 'package:planets/domain.dart';

import 'scene_models.dart';
import 'solar_system_scene_builder.dart';

/// Owns the orbit camera math shared by the 3D view and the 2D label
/// overlay (SRP: camera rig only).
class OrbitCameraRig {
  OrbitCameraRig({required this._state});

  final CameraRigState _state;
  double _focusedPlanetRadius = 1.0;
  bool _focusedPlanetIsSun = false;
  String? _activeFocusId;
  double _focusProgress = 1.0;
  double _focusElapsed = 0.0;
  vm.Vector3 _focusStartTarget = vm.Vector3.zero();
  vm.Vector3 _focusTarget = vm.Vector3.zero();
  double _focusStartRadius = kOverviewRadius;
  double _focusTargetRadius = kOverviewRadius;
  double _displayDetailZoom = 1.0;

  CameraRigState get state => _state;

  static const double kOverviewRadius = 46.0;
  static const double kMaxRadius = 90.0;
  static const double kMinRadius = 8.0;

  void resetOverview() {
    _state
      ..theta = 0.0
      ..phi = 0.32
      ..radius = kOverviewRadius
      ..targetX = 0.0
      ..targetY = 0.0
      ..targetZ = 0.0;
  }

  void orbitBy(double dx, double dy) {
    _state.theta -= dx * 0.008;
    _state.phi = (_state.phi + dy * 0.005).clamp(-0.15, 1.25);
  }

  void pinch(double scaleFactor) {
    _state.radius = (_state.radius / scaleFactor).clamp(kMinRadius, kMaxRadius);
  }

  /// Automatic readability rule for object labels.
  ///
  /// This does not modify the user's label preference. It only decides
  /// whether labels should be displayed at the current camera distance.
  bool labelsVisibleAtZoom(ExplorerState ui) {
    if (ui.hasSelection) {
      // In detail mode, a larger detailZoom means the camera is farther away.
      return _displayDetailZoom <= 1.7;
    }
    // In overview mode, hide labels once the whole system is zoomed out
    // enough that the chips begin to obscure the planets.
    return _state.radius <= 62.0;
  }

  /// Eases the focus target toward a planet's current world position.
  void focusOn(
    String planetId,
    SolarSystemSceneBuilder builder, {
    double deltaSeconds = 1 / 60,
  }) {
    final render = builder.states[planetId];
    if (render == null) return;

    final p = render.node.globalTransform.getTranslation();
    final destination = p.clone();
    final destinationRadius = _detailRadius(
      1.0,
      radius: render.radius,
      isSun: render.isSun,
    );

    if (_activeFocusId != planetId) {
      _activeFocusId = planetId;
      _focusElapsed = 0.0;
      _focusProgress = 0.0;
      _focusStartTarget = vm.Vector3(
        _state.targetX,
        _state.targetY,
        _state.targetZ,
      );
      _focusStartRadius = _state.radius;
      _displayDetailZoom = 1.0;
    }

    _focusTarget = destination;
    _focusTargetRadius = destinationRadius;
    _focusedPlanetRadius = render.radius;
    _focusedPlanetIsSun = render.isSun;

    // A short eased camera flight is much more stable than chasing a moving
    // Moon every frame. The target is updated from the current world transform
    // but interpolated, so the camera settles instead of snapping.
    const duration = 0.82;
    _focusElapsed = math.min(
      _focusElapsed + deltaSeconds.clamp(0.0, 0.05).toDouble(),
      duration,
    );
    final t = (_focusElapsed / duration).clamp(0.0, 1.0);
    final eased = 1.0 - math.pow(1.0 - t, 3).toDouble();
    _focusProgress = eased;

    final target = _focusStartTarget * (1.0 - eased) + _focusTarget * eased;
    _state
      ..targetX = target.x
      ..targetY = target.y
      ..targetZ = target.z
      ..radius =
          _focusStartRadius + (_focusTargetRadius - _focusStartRadius) * eased;
  }

  void releaseFocus() {
    _activeFocusId = null;
    _focusProgress = 1.0;
    _focusElapsed = 0.0;
    const k = 0.08;
    _state.targetX *= (1 - k);
    _state.targetY *= (1 - k);
    _state.targetZ *= (1 - k);
    _focusedPlanetRadius = 1.0;
    _focusedPlanetIsSun = false;
    // Do not change the camera radius here. Releasing a pinch must preserve
    // the exact zoom level the user reached. Overview recentering is handled
    // independently from the gesture lifecycle.
  }

  /// Builds the camera for this frame.
  PerspectiveCamera buildCamera({required ExplorerState ui}) {
    double radius = _state.radius;
    double theta = _state.theta;
    double phi = _state.phi;
    double tx = _state.targetX;
    double ty = _state.targetY;
    double tz = _state.targetZ;

    if (ui.hasSelection) {
      // Pinch zoom remains user-controlled even while the automatic focus
      // flight is still running. Previously the focus animation overwrote the
      // zoom until _focusProgress reached 1.0, making zoom-out appear locked
      // until focus finished.
      _displayDetailZoom += (ui.detailZoom - _displayDetailZoom) * 0.18;
      final userRadius = _detailRadius(_displayDetailZoom);

      if (_focusProgress >= 1.0) {
        radius = userRadius;
      } else {
        // Keep the cinematic focus flight, but blend toward the user's current
        // zoom target. This means the child can pinch in/out at any point
        // without waiting for the focus animation to finish.
        radius = _state.radius + (userRadius - _state.radius) * _focusProgress;
      }

      // Detail mode keeps the camera centered on the selected body.
      // The body itself is rotated by the gesture; the camera must not orbit
      // around it or impose a vertical pole clamp.
      theta = _state.theta;
      phi = _state.phi;
    }

    final cosPhi = math.cos(phi);
    final eye = vm.Vector3(
      tx + radius * cosPhi * math.sin(theta),
      ty + radius * math.sin(phi),
      tz + radius * cosPhi * math.cos(theta),
    );
    return PerspectiveCamera(
      fovRadiansY: _state.fovRadians,
      position: eye,
      target: vm.Vector3(tx, ty, tz),
      up: vm.Vector3(0, 1, 0),
    );
  }

  double _detailRadius(double zoom, {double? radius, bool? isSun}) {
    final focusedRadius = radius ?? _focusedPlanetRadius;
    final focusedIsSun = isSun ?? _focusedPlanetIsSun;
    // Moons are tiny (0.10–0.42 units) and orbit close to bright parents.
    // A floor of 2.5 buries them behind the parent/zoom math that was tuned
    // for full-size planets — so clamp relative to the focused body size.
    final bodyMin = (focusedRadius * 3.0).clamp(0.45, 2.5);
    // bodyMax used to impose the visible "38%"/zoom-out ceiling. Detail
    // camera distance is now controlled continuously by the user's zoom.
    final baseDistance = focusedRadius * (focusedIsSun ? 3.4 : 3.6);
    // There is deliberately no detail-mode max/min zoom range. Keep only a
    // tiny numerical floor so a camera can never collapse onto the object.
    return math.max(baseDistance * zoom, math.max(0.001, bodyMin * 0.01));
  }
}

/// Projects planet world positions to screen space for floating labels.
class LabelProjector {
  LabelProjector({required this._builder, required this._planets});

  final SolarSystemSceneBuilder _builder;
  final List<Planet> _planets;

  List<PlanetLabelFrame> project({
    required PerspectiveCamera camera,
    required Size viewSize,
  }) {
    if (viewSize.isEmpty) return const [];
    final frames = <PlanetLabelFrame>[];
    for (final planet in _planets) {
      final render = _builder.states[planet.id];
      if (render == null) continue;
      final world = render.node.globalTransform.getTranslation();
      final screen = camera.worldToScreen(world, viewSize);
      if (screen == null) continue;
      final dx = world.x - camera.position.x;
      final dy = world.y - camera.position.y;
      final dz = world.z - camera.position.z;
      final depth = dx * dx + dy * dy + dz * dz;
      frames.add(
        PlanetLabelFrame(
          id: planet.id,
          // Labels float above the globe, offset by a fixed screen amount
          // plus a depth-aware lift.
          screenX: screen.dx,
          screenY: screen.dy - _labelLift(planet.radius, depth),
          worldDepth: depth,
          visible: _isOnScreen(screen, viewSize),
        ),
      );
    }
    // Far planets first so near labels paint on top.
    frames.sort((a, b) => b.worldDepth.compareTo(a.worldDepth));
    return frames;
  }

  double _labelLift(double radius, double depth) =>
      (34 + radius * 10).clamp(40.0, 72.0);

  bool _isOnScreen(Offset p, Size size) =>
      p.dx > -80 &&
      p.dx < size.width + 80 &&
      p.dy > -60 &&
      p.dy < size.height + 60;
}
