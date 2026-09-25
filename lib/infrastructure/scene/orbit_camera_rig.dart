import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../../application/state/explorer_state.dart';
import '../../../domain/entities/planet.dart';
import 'scene_models.dart';
import 'solar_system_scene_builder.dart';

/// Owns the orbit camera math shared by the 3D view and the 2D label
/// overlay (SRP: camera rig only).
class OrbitCameraRig {
  OrbitCameraRig({required CameraRigState state}) : _state = state;

  final CameraRigState _state;
  double _focusedPlanetRadius = 1.0;
  bool _focusedPlanetIsSun = false;
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
    _state.radius = (_state.radius / scaleFactor)
        .clamp(kMinRadius, kMaxRadius);
  }

  /// Eases the focus target toward a planet's current world position.
  void focusOn(String planetId, SolarSystemSceneBuilder builder) {
    final render = builder.states[planetId];
    if (render == null) return;
    final p = render.node.position;
    _focusedPlanetRadius = render.radius;
    _focusedPlanetIsSun = render.isSun;
    const k = 0.12;
    _state.targetX += (p.x - _state.targetX) * k;
    _state.targetY += (p.y - _state.targetY) * k;
    _state.targetZ += (p.z - _state.targetZ) * k;
  }

  void releaseFocus() {
    const k = 0.08;
    _state.targetX *= (1 - k);
    _state.targetY *= (1 - k);
    _state.targetZ *= (1 - k);
    _focusedPlanetRadius = 1.0;
    _focusedPlanetIsSun = false;
    if (_state.radius < kOverviewRadius) {
      _state.radius += (kOverviewRadius - _state.radius) * 0.05;
    }
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
      // Detail mode: closer orbit driven by the detail sheet gestures.
      radius = _detailRadius(ui.detailZoom);
      theta = _state.theta + ui.detailTheta;
      phi = (ui.detailPhi).clamp(-0.2, 1.3);
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

  double _detailRadius(double zoom) {
    final baseDistance = _focusedPlanetRadius * (_focusedPlanetIsSun ? 3.4 : 3.6);
    return (baseDistance * zoom).clamp(2.5, 30.0);
  }
}

/// Projects planet world positions to screen space for floating labels.
class LabelProjector {
  LabelProjector({
    required SolarSystemSceneBuilder builder,
    required List<Planet> planets,
  })  : _builder = builder,
        _planets = planets;

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
      final world = render.node.position;
      final screen = camera.worldToScreen(world, viewSize);
      if (screen == null) continue;
      final dx = world.x - camera.position.x;
      final dy = world.y - camera.position.y;
      final dz = world.z - camera.position.z;
      final depth = dx * dx + dy * dy + dz * dz;
      frames.add(PlanetLabelFrame(
        id: planet.id,
        // Labels float above the globe, offset by a fixed screen amount
        // plus a depth-aware lift.
        screenX: screen.dx,
        screenY: screen.dy - _labelLift(planet.radius, depth),
        worldDepth: depth,
        visible: _isOnScreen(screen, viewSize),
      ));
    }
    // Far planets first so near labels paint on top.
    frames.sort((a, b) => b.worldDepth.compareTo(a.worldDepth));
    return frames;
  }

  double _labelLift(double radius, double depth) =>
      (34 + radius * 10).clamp(40.0, 72.0);

  bool _isOnScreen(Offset p, Size size) =>
      p.dx > -80 && p.dx < size.width + 80 && p.dy > -60 && p.dy < size.height + 60;
}
