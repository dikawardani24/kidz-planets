import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Geometry for the mission companion (SRP: geometry only).
///
/// Every shape is cached by its defining numbers so the character is built from
/// a fixed, small set of GPU buffers no matter how many times it is rebuilt,
/// and the tessellation is deliberately low: this character is roughly 120px
/// on screen, so extra segments would cost fill rate and buy nothing visible.
class AvatarGeometryFactory {
  AvatarGeometryFactory();

  final Map<String, MeshGeometry> _cache = {};

  /// Helmet and torso. A capsule gives a soft suit silhouette without a rig.
  MeshGeometry torso() => _cache.putIfAbsent(
        'torso',
        () => CapsuleGeometry(
          radius: 0.175,
          height: 0.30,
          radialSegments: 20,
          capRings: 6,
        ),
      );

  MeshGeometry head() => _cache.putIfAbsent(
        'head',
        () => SphereGeometry(radius: 0.135, segments: 20, rings: 12),
      );

  /// Slightly larger than [head] so a rim of it always shows, which is what
  /// makes it read as a helmet rather than a bald head.
  MeshGeometry helmet() => _cache.putIfAbsent(
        'helmet',
        () => SphereGeometry(radius: 0.150, segments: 22, rings: 14),
      );

  MeshGeometry visor() => _cache.putIfAbsent(
        'visor',
        () => SphereGeometry(radius: 0.105, segments: 18, rings: 12),
      );

  MeshGeometry pack() => _cache.putIfAbsent(
        'pack',
        () => CuboidGeometry(vm.Vector3(0.22, 0.24, 0.12)),
      );

  MeshGeometry arm() => _cache.putIfAbsent(
        'arm',
        () => CapsuleGeometry(
          radius: 0.052,
          height: 0.14,
          radialSegments: 12,
          capRings: 4,
        ),
      );

  MeshGeometry leg() => _cache.putIfAbsent(
        'leg',
        () => CapsuleGeometry(
          radius: 0.062,
          height: 0.16,
          radialSegments: 12,
          capRings: 4,
        ),
      );

  MeshGeometry boot() => _cache.putIfAbsent(
        'boot',
        () => CapsuleGeometry(
          radius: 0.068,
          height: 0.04,
          radialSegments: 12,
          capRings: 4,
        ),
      );

  MeshGeometry badge() => _cache.putIfAbsent(
        'badge',
        () => SphereGeometry(radius: 0.032, segments: 10, rings: 6),
      );

  MeshGeometry antennaStem() => _cache.putIfAbsent(
        'antenna-stem',
        () => CapsuleGeometry(
          radius: 0.012,
          height: 0.10,
          radialSegments: 6,
          capRings: 2,
        ),
      );

  MeshGeometry antennaTip() => _cache.putIfAbsent(
        'antenna-tip',
        () => SphereGeometry(radius: 0.028, segments: 10, rings: 6),
      );

  /// Stand-in for the mission's target planet.
  MeshGeometry target() => _cache.putIfAbsent(
        'target',
        () => SphereGeometry(radius: 0.085, segments: 18, rings: 12),
      );

  void dispose() => _cache.clear();
}
