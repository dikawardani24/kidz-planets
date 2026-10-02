import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:planets/state.dart';
import 'package:core/time.dart';
import 'package:planets/domain.dart';

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

  /// Builds the Sun, the planets and the orbits. Safe to call repeatedly.
  ///
  /// Startup calls this before the Explorer exists, so the first frame the
  /// child sees is a finished solar system instead of a spinner over a scene
  /// that is still decoding.
  Future<void> ensureBuilt({
    required List<Planet> planets,
    required void Function(double fraction, String label) onProgress,
  });

  /// Adds the moons, which is deliberately not part of [ensureBuilt].
  ///
  /// Safe to call repeatedly and from a lazy warm: the second call is a no-op
  /// rather than a second copy of every moon.
  Future<void> ensureMoonsBuilt({
    required List<Planet> moons,
    required void Function(double fraction, String label) onProgress,
  });

  /// Whether the moons are in the scene yet.
  ///
  /// Exposed so the startup code can tell a lazy warm apart from a second full
  /// build, and so a test can assert the moons really did arrive later.
  bool get areMoonsBuilt;

  /// How many textures are already decoded and resident.
  ///
  /// Reported on the loading screen's diagnostics and asserted in tests: it is
  /// the one number that proves a warm start did not decode the sky twice.
  int get cachedTextureCount;

  PerspectiveCamera buildCamera(ExplorerState ui);
  void tick(double deltaSeconds, ExplorerState ui);
  List<PlanetLabelFrame> projectLabels(PerspectiveCamera camera, Size viewSize);
  void setOrbitsVisible(bool visible);
  bool labelsVisibleAtZoom(ExplorerState ui);
  void setPlanetOrbitRadius(String planetId, double radius);
  void addSpinBoost(double amount);
  String? pickPlanet(
    Offset screenPosition,
    Size viewSize,
    PerspectiveCamera camera,
  );
  void spinPlanet(String planetId, double delta);
  void rotatePlanet(String planetId, double dx, double dy);
  void rotateSolarSystem(double dx, double dy);
  void setRotationVelocity({
    String? planetId,
    required double angularX,
    required double angularY,
  });
  void orbitBy(double dx, double dy);
  void pinch(double scale);
  void dispose();
}

/// Default implementation wiring builder + animator + camera (DIP: depends
/// on [SimulationClock] abstraction, not on widgets).
class SolarSystemSceneControllerImpl implements SolarSystemSceneController {
  SolarSystemSceneControllerImpl({required this._clock})
    : _scene = Scene(),
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
  Future<void>? _moonsFuture;
  double _rotationVelocityX = 0.0;
  double _rotationVelocityY = 0.0;
  String? _rotationVelocityPlanetId;
  String? _lastFocusedPlanetId;

  @override
  Scene get scene => _scene;

  @override
  CameraRigState get rigState => _rigState;

  @override
  bool get isReady => _built;

  @override
  Future<void> ensureBuilt({
    required List<Planet> planets,
    required void Function(double fraction, String label) onProgress,
  }) {
    _buildFuture ??= () async {
      // The full catalogue, moons included, goes to the animator and the label
      // projector even though only the planets are built here: both read the
      // builder's state map per frame and pick the moons up the moment the lazy
      // build adds them.
      await _builder.build(
        scene: _scene,
        planets: planets,
        onProgress: onProgress,
      );
      _animator = SolarSystemAnimator(
        clock: _clock,
        builder: _builder,
        planets: planets,
      );
      _animator!.attach();
      _projector = LabelProjector(builder: _builder, planets: planets);
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
  Future<void> ensureMoonsBuilt({
    required List<Planet> moons,
    required void Function(double fraction, String label) onProgress,
  }) => _moonsFuture ??= () async {
    await _builder.buildMoons(moons: moons, onProgress: onProgress);
  }();

  @override
  bool get areMoonsBuilt => _moonsFuture != null;

  @override
  int get cachedTextureCount => _textures.cachedCount;

  @override
  PerspectiveCamera buildCamera(ExplorerState ui) => _rig.buildCamera(ui: ui);

  @override
  bool labelsVisibleAtZoom(ExplorerState ui) => _rig.labelsVisibleAtZoom(ui);

  @override
  void tick(double deltaSeconds, ExplorerState ui) {
    _clock.tick(deltaSeconds);
    final focused = ui.focusedPlanetId;
    if (focused != _lastFocusedPlanetId) {
      _rotationVelocityX = 0.0;
      _rotationVelocityY = 0.0;
      _rotationVelocityPlanetId = focused;
      _lastFocusedPlanetId = focused;
    }
    _animator?.setFocusedPlanet(focused);

    if (_rotationVelocityX.abs() > 0.0001 ||
        _rotationVelocityY.abs() > 0.0001) {
      if (_rotationVelocityPlanetId != null) {
        _builder.rotatePlanetAngularVelocity(
          _rotationVelocityPlanetId!,
          _rotationVelocityX,
          _rotationVelocityY,
          deltaSeconds,
        );
      } else {
        _builder.rotateSolarSystemAngularVelocity(
          _rotationVelocityX,
          _rotationVelocityY,
          deltaSeconds,
        );
      }
      final damping = math.pow(0.055, deltaSeconds).toDouble();
      _rotationVelocityX *= damping;
      _rotationVelocityY *= damping;
    }

    _animator?.tick(deltaSeconds);
    if (focused != null) {
      _rig.focusOn(focused, _builder, deltaSeconds: deltaSeconds);
    } else {
      _rig.releaseFocus();
    }
  }

  @override
  List<PlanetLabelFrame> projectLabels(
    PerspectiveCamera camera,
    Size viewSize,
  ) {
    final projector = _projector;
    if (projector == null || !_built) return const [];
    return projector.project(camera: camera, viewSize: viewSize);
  }

  @override
  void setOrbitsVisible(bool visible) => _builder.setOrbitsVisible(visible);

  @override
  void setPlanetOrbitRadius(String planetId, double radius) {
    _builder.setPlanetOrbitRadius(planetId, radius);
    _animator?.setOrbitRadius(planetId, radius);
  }

  @override
  void addSpinBoost(double amount) => _animator?.addSpinBoost(amount);

  @override
  String? pickPlanet(
    Offset screenPosition,
    Size viewSize,
    PerspectiveCamera camera,
  ) {
    if (!_built || viewSize.isEmpty) return null;
    final ray = camera.screenPointToRay(screenPosition, viewSize);
    final hit = _scene.raycast(
      ray,
      where: (node) => node.name.endsWith(':mesh'),
    );
    if (hit == null) return null;
    Node? node = hit.node;
    while (node != null && node.parent != _builder.solarSystemRoot) {
      node = node.parent;
    }
    if (node == null) return null;
    for (final entry in _builder.states.entries) {
      if (identical(entry.value.node, node)) return entry.key;
    }
    return null;
  }

  @override
  void spinPlanet(String planetId, double delta) {
    final render = _builder.states[planetId];
    if (render == null) return;
    render.spinNode.rotation =
        render.spinNode.rotation *
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), delta);
  }

  @override
  void rotatePlanet(String planetId, double dx, double dy) =>
      _builder.rotatePlanet(planetId, dx, dy);

  @override
  void rotateSolarSystem(double dx, double dy) =>
      _builder.rotateSolarSystem(dx, dy);

  @override
  void setRotationVelocity({
    String? planetId,
    required double angularX,
    required double angularY,
  }) {
    _rotationVelocityPlanetId = planetId;
    _rotationVelocityX = angularX;
    _rotationVelocityY = angularY;
  }

  @override
  void orbitBy(double dx, double dy) => _rig.orbitBy(dx, dy);

  @override
  void pinch(double scale) => _rig.pinch(scale);

  @override
  void dispose() {
    _rotationVelocityX = 0.0;
    _rotationVelocityY = 0.0;
    _animator?.detach();
    _textures.dispose();
    _geometries.dispose();
  }
}
