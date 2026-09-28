import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Geometry for the sleek Sci-Fi Robot / Space Drone companion.
///
/// Clean, high-tech, adorable floating robot buddy with a digital visor screen,
/// glowing antenna, thruster ring, and compact chassis.
class AvatarGeometryFactory {
  AvatarGeometryFactory();

  final Map<String, MeshGeometry> _cache = {};

  /// Main robot spherical chassis.
  MeshGeometry chassis() => _cache.putIfAbsent(
        'chassis',
        () => SphereGeometry(radius: 0.17, segments: 24, rings: 16),
      );

  /// Digital visor screen face.
  MeshGeometry visorScreen() => _cache.putIfAbsent(
        'visor-screen',
        () => CapsuleGeometry(radius: 0.11, height: 0.13, radialSegments: 18, capRings: 6),
      );

  /// Floating anti-gravity / thruster ring around the base.
  MeshGeometry thrusterRing() => _cache.putIfAbsent(
        'thruster-ring',
        () => CapsuleGeometry(radius: 0.14, height: 0.05, radialSegments: 16, capRings: 3),
      );

  /// Floating side sensor pods / arms.
  MeshGeometry sidePod() => _cache.putIfAbsent(
        'side-pod',
        () => SphereGeometry(radius: 0.045, segments: 12, rings: 8),
      );

  /// Top comms antenna stem.
  MeshGeometry antennaStem() => _cache.putIfAbsent(
        'antenna-stem',
        () => CapsuleGeometry(radius: 0.012, height: 0.12, radialSegments: 6, capRings: 2),
      );

  /// Top antenna glowing beacon orb.
  MeshGeometry antennaTip() => _cache.putIfAbsent(
        'antenna-tip',
        () => SphereGeometry(radius: 0.032, segments: 12, rings: 8),
      );

  /// Stand-in for the mission target.
  MeshGeometry target() => _cache.putIfAbsent(
        'target',
        () => SphereGeometry(radius: 0.085, segments: 18, rings: 12),
      );

  void dispose() => _cache.clear();
}
