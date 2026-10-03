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
  static const double kMaxRadius = 10e9;
  static const double kMinRadius = 1e-4;

  /// Stable logical center of the solar system in world space.
  ///
  /// The Sun sits at the origin and every orbit is centered on it, so free
  /// exploration always rotates around this anchor. Pinch zoom moves the
  /// camera eye toward/away from the focal area but never rewrites this
  /// anchor, which is what keeps repeated gestures from drifting the whole
  /// system out of the viewport. (Read-only: never mutate the instance.)
  static final vm.Vector3 kExploreAnchor = vm.Vector3.zero();

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
    if (!scaleFactor.isFinite || scaleFactor <= 0) return;
    final next = _state.radius / scaleFactor;
    if (!next.isFinite) return;
    // Physical safety only: keep the camera transform valid without imposing
    // a user-facing zoom limit.
    _state.radius = next.clamp(1e-4, 1e9);
  }

  /// Free-exploration pinch that can move toward a focal world point.
  ///
  /// [scaleFactor] follows the same convention as [pinch] (>1 zooms in).
  /// When [focalWorldPoint] is given and the gesture zooms in, the camera
  /// eye moves toward that point so pinching over Jupiter approaches
  /// Jupiter instead of always dollying toward the solar-system origin
  /// (which is why the Sun used to be the only body with usable zoom).
  ///
  /// Crucially, the orbit target is NOT rewritten: it is re-pinned to
  /// [kExploreAnchor] every focal pinch. The focal point is a temporary zoom
  /// intent for the current gesture, not a new permanent anchor, so repeated
  /// pinches can never accumulate target drift and push the solar system
  /// off-screen. Rotation therefore always stays centered on the system.
  /// Zoom-out (and a missing focal point) is a pure dolly via [pinch].
  void pinchToward(double scaleFactor, {vm.Vector3? focalWorldPoint}) {
    if (!scaleFactor.isFinite || scaleFactor <= 0) return;
    if (focalWorldPoint == null || scaleFactor <= 1.0) {
      pinch(scaleFactor);
      return;
    }
    final pull = (1.0 - 1.0 / scaleFactor).clamp(0.0, 1.0);
    // Move strongly toward the focal area so repeated frames converge.
    const kPull = 0.9;
    final t = (pull * kPull).clamp(0.0, 1.0);
    final cosPhi = math.cos(_state.phi);
    final eyeX =
        _state.targetX + _state.radius * cosPhi * math.sin(_state.theta);
    final eyeY = _state.targetY + _state.radius * math.sin(_state.phi);
    final eyeZ =
        _state.targetZ + _state.radius * cosPhi * math.cos(_state.theta);
    _state.targetX = kExploreAnchor.x;
    _state.targetY = kExploreAnchor.y;
    _state.targetZ = kExploreAnchor.z;
    preserveEye(
      vm.Vector3(
        eyeX + (focalWorldPoint.x - eyeX) * t,
        eyeY + (focalWorldPoint.y - eyeY) * t,
        eyeZ + (focalWorldPoint.z - eyeZ) * t,
      ),
    );
  }

  /// World-space radius of a body (logical radius scaled by node transform).
  ///
  /// Meshes are built with `sphere(planet.radius)` and nodes carry no manual
  /// scale in the normal pipeline, so this usually equals [PlanetRenderState.radius].
  /// Deriving it from the global transform keeps the camera correct even if a
  /// body is rescaled later (the Sun's large scale is what accidentally made
  /// old origin-based zoom feel right for the Sun only).
  static double worldRadiusOf(PlanetRenderState render) {
    try {
      final scale = render.node.globalTransform.getMaxScaleOnAxis();
      if (scale.isFinite && scale > 0) return render.radius * scale;
    } catch (_) {
      // Fall through to logical radius.
    }
    return render.radius;
  }

  static vm.Vector3 worldPositionOf(PlanetRenderState render) =>
      render.node.globalTransform.getTranslation().clone();

  static double baseDistanceFor({
    required double worldRadius,
    required bool isSun,
  }) =>
      worldRadius * (isSun ? 3.4 : 3.6);

  /// Camera distance for [zoom] around a body. No UI clamp: only a tiny
  /// physical floor so the camera never collapses onto the object.
  double detailRadiusForZoom(
    double zoom, {
    double? worldRadius,
    bool? isSun,
  }) {
    final r = worldRadius ?? _focusedPlanetRadius;
    final sun = isSun ?? _focusedPlanetIsSun;
    return math.max(0.001, baseDistanceFor(worldRadius: r, isSun: sun) * zoom);
  }

  /// Instantly adopt [bodyPos] as the orbit target while keeping the current
  /// camera eye fixed. Returns the detail zoom that reproduces [distance].
  ///
  /// Used for automatic pinch selection so `selectedPlanetId = Earth` does not
  /// move the camera: distance stays exactly where the pinch left it instead of
  /// snapping to the default focus distance.
  /// Freeze [eye] into the orbit state exactly: the next frame renders the
  /// same camera position. The target is left alone, so this is also what
  /// keeps the eye fixed when detail mode hands back to free exploration.
  void preserveEye(vm.Vector3 eye) {
    final ox = eye.x - _state.targetX;
    final oy = eye.y - _state.targetY;
    final oz = eye.z - _state.targetZ;
    final distance = math.max(
      1e-4,
      math.sqrt(ox * ox + oy * oy + oz * oz),
    );
    _state
      ..theta = math.atan2(ox, oz)
      ..phi = math.asin((oy / distance).clamp(-1.0, 1.0))
      ..radius = distance.clamp(1e-4, 1e9);
  }

  /// Restore the stable exploration anchor without moving the camera.
  ///
  /// Used when a selection is released: [eye] stays exactly where the user
  /// left it, but rotation/zoom anchor back onto [kExploreAnchor] so the next
  /// free-exploration gesture orbits the solar system instead of the
  /// just-deselected body. No snap, no recenter animation, no zoom reset.
  void reanchorPreservingEye(vm.Vector3 eye) {
    _state.targetX = kExploreAnchor.x;
    _state.targetY = kExploreAnchor.y;
    _state.targetZ = kExploreAnchor.z;
    preserveEye(eye);
  }

  double snapToBodyPreservingEye({
    required String planetId,
    required vm.Vector3 bodyPos,
    required double worldRadius,
    required bool isSun,
    required vm.Vector3 eye,
  }) {
    _state
      ..targetX = bodyPos.x
      ..targetY = bodyPos.y
      ..targetZ = bodyPos.z;
    preserveEye(eye);
    final distance = _state.radius;
    _activeFocusId = planetId;
    _focusProgress = 1.0;
    _focusElapsed = 0.0;
    _focusStartTarget = bodyPos.clone();
    _focusTarget = bodyPos.clone();
    _focusStartRadius = distance;
    _focusTargetRadius = distance;
    _focusedPlanetRadius = worldRadius;
    _focusedPlanetIsSun = isSun;
    final base = baseDistanceFor(worldRadius: worldRadius, isSun: isSun);
    _displayDetailZoom = distance / base;
    return _displayDetailZoom;
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
  ///
  /// [detailZoom] is the user's current detail zoom: the flight lands on the
  /// exact distance the user already reached instead of snapping back to the
  /// default 100% framing. Tap selection passes 1.0, so its cinematic flight
  /// is unchanged; pinch auto-selection passes the preserved zoom.
  void focusOn(
    String planetId,
    SolarSystemSceneBuilder builder, {
    double deltaSeconds = 1 / 60,
    double detailZoom = 1.0,
  }) {
    final render = builder.states[planetId];
    if (render == null) return;

    final p = worldPositionOf(render);
    final destination = p.clone();
    final worldR = worldRadiusOf(render);
    final destinationRadius = _detailRadius(
      detailZoom,
      radius: worldR,
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
      _displayDetailZoom = detailZoom;
    }

    _focusTarget = destination;
    _focusTargetRadius = destinationRadius;
    _focusedPlanetRadius = worldR;
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
    // Pure tracking reset: the radius/target handover now happens
    // synchronously in the gesture handler ([preserveEye]) before the
    // selection state changes, so a scene tick running with a stale frame's
    // UI can never overwrite the preserved camera distance with a default.
    // The target stays on the body instead of recentering on the Sun/origin.
    _activeFocusId = null;
    _focusProgress = 1.0;
    _focusElapsed = 0.0;
    _focusedPlanetRadius = 1.0;
    _focusedPlanetIsSun = false;
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
    final worldR = radius ?? _focusedPlanetRadius;
    final sun = isSun ?? _focusedPlanetIsSun;
    return math.max(
      0.001,
      baseDistanceFor(worldRadius: worldR, isSun: sun) * zoom,
    );
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
