import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// The rocket's round window, in body space.
///
/// The mesh, the node that places it and the 2D face painted over it all have
/// to agree on these three numbers, so they live together here rather than as
/// three copies that can drift apart.
class AvatarPorthole {
  /// Radius of the window mesh, in body units.
  static const double radius = 0.075;

  /// Height of the window's centre on the rocket body.
  static const double height = 0.08;

  /// How far the window sits in front of the body's centre line. Negative is
  /// towards the camera, which is where the front of the rocket is.
  static const double depth = -0.30;
}

/// Geometry for the Chubby Cartoon Rocket Ship Mascot.
///
/// A brand new, unique shape: a friendly little cartoon rocket ship with
/// a round nosecone, porthole window, little wings/fins, and engine thruster.
class AvatarGeometryFactory {
  AvatarGeometryFactory();

  final Map<String, MeshGeometry> _cache = {};

  /// Main rocket fuselage body.
  MeshGeometry rocketBody() => _cache.putIfAbsent(
        'rocket-body',
        () => CapsuleGeometry(radius: 0.14, height: 0.32, radialSegments: 22, capRings: 6),
      );

  /// Rounded rocket nosecone.
  MeshGeometry noseCone() => _cache.putIfAbsent(
        'nose-cone',
        () => SphereGeometry(radius: 0.14, segments: 20, rings: 10),
      );

  /// Front porthole window.
  MeshGeometry porthole() => _cache.putIfAbsent(
        'porthole',
        () => SphereGeometry(
          radius: AvatarPorthole.radius,
          segments: 18,
          rings: 12,
        ),
      );

  /// Rocket side fins / wings.
  MeshGeometry fin() => _cache.putIfAbsent(
        'fin',
        () => CuboidGeometry(vm.Vector3(0.06, 0.12, 0.03)),
      );

  /// Rocket engine base nozzle.
  MeshGeometry engineNozzle() => _cache.putIfAbsent(
        'engine-nozzle',
        () => CapsuleGeometry(radius: 0.08, height: 0.06, radialSegments: 16, capRings: 3),
      );

  /// Stand-in for the mission target.
  MeshGeometry target() => _cache.putIfAbsent(
        'target',
        () => SphereGeometry(radius: 0.085, segments: 18, rings: 12),
      );

  void dispose() => _cache.clear();
}
