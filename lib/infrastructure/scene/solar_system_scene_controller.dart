import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';

import '../../../application/state/explorer_state.dart';
import '../../../application/state/simulation_clock.dart';
import '../../../domain/entities/planet.dart';
import 'orbit_camera_rig.dart';
import 'scene_factories.dart';
import 'scene_models.dart';
import 'solar_system_animator.dart';
import 'solar_system_scene_builder.dart';
import 'texture_provider.dart';

/// Facade over the whole 3D stack (ISP: one narrow interface for widgets).
abstract class SolarSystemSceneController {
  Scene get scene;
  CameraRigState get rigState;
  bool get isReady;

  Future<void> ensureBuilt({
    required List<Planet> planets,
    required void Function(String label) onProgress,
  });

  PerspectiveCamera buildCamera(ExplorerState ui);
  void tick(double deltaSeconds, ExplorerState ui);
  List<PlanetLabelFrame> projectLabels(
      PerspectiveCamera camera, Size viewSize);
  void setOrbitsVisible(bool visible);
  void setPlanetOrbitRadius(String planetId, double radius);
  void addSpinBoost(double amount);
  void orbitBy(double dx, double dy);
  void pinch(double scale);
  void dispose();
}

/// Default implementation wiring builder + animator + camera (DIP: depends
/// on [SimulationClock] abstraction, not on widgets).
class SolarSystemSceneControllerImpl implements SolarSystemSceneController {
  SolarSystemSceneControllerImpl({required SimulationClock clock})
      : _clock = clock,
        _scene = Scene(),
        _textures = AssetTextureProvider(),
        _geometries = GeometryFactory(),
        _rigState = CameraRigState() {
    _materials = PlanetMaterialFactory();
    _builder = SolarSystemSceneBuilder(
      textures: _textures,
      geometries: _geometries,
      materials: _materials,
    );
    _rig = OrbitCameraRig(state: _rigState);
  }

  final SimulationClock _clock;
  final Scene _scene;
  final TextureProvider _textures;
  final GeometryFactory _geometries;
  late final PlanetMaterialFactory _materials;
  late final SolarSystemSceneBuilder _builder;
  late final OrbitCameraRig _rig;
  final CameraRigState _rigState;

  SolarSystemAnimator? _animator;
  LabelProjector? _projector;
  bool _built = false;
  Future<void>? _buildFuture;

  @override
  Scene get scene => _scene;

  @override
  CameraRigState get rigState => _rigState;

  @override
  bool get isReady => _built;

  @override
  Future<void> ensureBuilt({
    required List<Planet> planets,
    required void Function(String label) onProgress,
  }) {
    _buildFuture ??= () async {
      await _builder.build(
          scene: _scene, planets: planets, onProgress: onProgress);
      _animator = SolarSystemAnimator(
          clock: _clock, builder: _builder, planets: planets);
      _animator!.attach();
      _projector =
          LabelProjector(builder: _builder, planets: planets);
      _rigState
        ..theta = 0.0
        ..phi = 0.32
        ..radius = OrbitCameraRig.kOverviewRadius
        ..fovRadians = 0.85;
      _built = true;
    }();
    return _buildFuture!;
  }

  @override
  PerspectiveCamera buildCamera(ExplorerState ui) =>
      _rig.buildCamera(ui: ui);

  @override
  void tick(double deltaSeconds, ExplorerState ui) {
    _clock.tick(deltaSeconds);
    _animator?.tick(deltaSeconds);
    final focused = ui.focusedPlanetId;
    if (focused != null) {
      _rig.focusOn(focused, _builder);
    } else {
      _rig.releaseFocus();
    }
  }

  @override
  List<PlanetLabelFrame> projectLabels(
      PerspectiveCamera camera, Size viewSize) {
    final projector = _projector;
    if (projector == null || !_built) return const [];
    return projector.project(camera: camera, viewSize: viewSize);
  }

  @override
  void setOrbitsVisible(bool visible) =>
      _builder.setOrbitsVisible(visible);

  @override
  void setPlanetOrbitRadius(String planetId, double radius) {
    _builder.setPlanetOrbitRadius(planetId, radius);
    _animator?.setOrbitRadius(planetId, radius);
  }

  @override
  void addSpinBoost(double amount) => _animator?.addSpinBoost(amount);

  @override
  void orbitBy(double dx, double dy) => _rig.orbitBy(dx, dy);

  @override
  void pinch(double scale) => _rig.pinch(scale);

  @override
  void dispose() {
    _animator?.detach();
    _textures.dispose();
    _geometries.dispose();
  }
}
