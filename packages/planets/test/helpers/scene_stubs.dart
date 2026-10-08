import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:planets/domain.dart';
import 'package:planets/scene.dart';
import 'package:planets/state.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Stands in for the real asset cache so scene tests never touch disk.
///
/// `Scene()` and `SphereGeometry` both need a GPU, so the builder is only ever
/// used for its transform maths here: [SolarSystemSceneBuilder.states] and
/// [SolarSystemSceneBuilder.orbitNodes] are plain public maps the tests fill in
/// with bare `Node`s, which needs no rendering backend.
class UnusableTextureProvider implements TextureProvider {
  @override
  Future<TextureSource> get(String assetPath) =>
      throw StateError('scene tests must not load textures: $assetPath');

  @override
  void dispose() {}

  @override
  int get cachedCount => 0;
}

/// A [SolarSystemSceneController] stub for widget tests.
///
/// The real implementation constructs a `Scene()` on creation, which requires
/// the Impeller/Flutter GPU backend that widget-test environments do not have,
/// so any test that would otherwise reach the scene provider gets one of these
/// instead. Only the members widgets actually call are implemented; the rest
/// throw, which is fine because those tests never reach them.
class FakeSceneController implements SolarSystemSceneController {
  final CameraRigState _rig = CameraRigState();

  @override
  CameraRigState get rigState => _rig;

  void _applyScale(double scale) {
    if (!scale.isFinite || scale <= 0) return;
    _rig.radius = (_rig.radius / scale).clamp(1e-4, 1e9);
  }

  @override
  void pinchTowardBody(double scale, String planetId) => _applyScale(scale);

  @override
  void pinchWithFocalPoint(
    double scale, {
    Offset? focalScreenPoint,
    Size? viewSize,
    PerspectiveCamera? camera,
  }) => _applyScale(scale);

  @override
  void resetOverview() {
    _rig
      ..theta = 0.0
      ..phi = 0.32
      ..radius = 46.0
      ..targetX = 0.0
      ..targetY = 0.0
      ..targetZ = 0.0;
  }

  @override
  PerspectiveCamera buildCamera(ExplorerState ui) => PerspectiveCamera(
    fovRadiansY: _rig.fovRadians,
    position: vm.Vector3(0, _rig.radius, 0),
    target: vm.Vector3(0, 0, 0),
    up: vm.Vector3(0, 1, 0),
  );

  @override
  double markZoomProgress(String planetId, PerspectiveCamera camera) => 0.0;

  @override
  void dispose() {}

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeSceneController: ${invocation.memberName}');
}

SolarSystemSceneBuilder makeSceneBuilder() => SolarSystemSceneBuilder(
  textures: UnusableTextureProvider(),
  geometries: GeometryFactory(),
  materials: PlanetMaterialFactory(),
);

/// Registers [id] in the builder's `states` and returns the render state.
PlanetRenderState addBody(
  SolarSystemSceneBuilder builder,
  String id, {
  vm.Vector3? position,
  double radius = 1.0,
  bool isSun = false,
}) {
  final state = PlanetRenderState(
    id: id,
    node: Node(name: id)..position = position ?? vm.Vector3.zero(),
    spinNode: Node(name: '$id:spin'),
    radius: radius,
    isSun: isSun,
  );
  builder.states[id] = state;
  return state;
}

Planet testPlanet({
  String id = 'earth',
  String name = 'Earth',
  double radius = 1.0,
  double orbitRadius = 10.0,
  double orbitSpeed = 0.2,
  double startAngle = 0.0,
  bool isMoon = false,
  bool isSun = false,
  String? parentPlanetId,
  int colorValue = 0xFF0000FF,
}) {
  return Planet(
    id: id,
    name: name,
    tag: 'planet',
    fact: 'A test fact.',
    radius: radius,
    orbitRadius: orbitRadius,
    orbitSpeed: orbitSpeed,
    startAngle: startAngle,
    colorValue: colorValue,
    tiltDegrees: 0,
    textureAsset: 'assets/textures/$id.png',
    diameter: '1',
    temperature: '1',
    dayLength: '1',
    hotspots: const [],
    isMoon: isMoon,
    isSun: isSun,
    parentPlanetId: parentPlanetId,
  );
}
