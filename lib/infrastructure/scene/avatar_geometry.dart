import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Geometry for the mission companion (SRP: geometry only).
///
/// Every shape is defined to build a distinct, professional chibi astronaut
/// with clear armor plating, helmet, shoulder pauldrons, belt, and boots.
class AvatarGeometryFactory {
  AvatarGeometryFactory();

  final Map<String, MeshGeometry> _cache = {};

  /// Upper chest suit body.
  MeshGeometry torso() => _cache.putIfAbsent(
        'torso',
        () => CapsuleGeometry(
          radius: 0.16,
          height: 0.22,
          radialSegments: 22,
          capRings: 6,
        ),
      );

  /// Lower waist suit section.
  MeshGeometry waist() => _cache.putIfAbsent(
        'waist',
        () => CapsuleGeometry(
          radius: 0.145,
          height: 0.08,
          radialSegments: 20,
          capRings: 4,
        ),
      );

  /// Suit belt separating upper and lower body.
  MeshGeometry belt() => _cache.putIfAbsent(
        'belt',
        () => CapsuleGeometry(
          radius: 0.15,
          height: 0.04,
          radialSegments: 20,
          capRings: 3,
        ),
      );

  /// Neck collar ring connecting torso and helmet.
  MeshGeometry collar() => _cache.putIfAbsent(
        'collar',
        () => CapsuleGeometry(
          radius: 0.12,
          height: 0.05,
          radialSegments: 16,
          capRings: 3,
        ),
      );

  /// Shoulder pauldrons for armored spacesuit look.
  MeshGeometry shoulderPad() => _cache.putIfAbsent(
        'shoulder-pad',
        () => SphereGeometry(radius: 0.068, segments: 14, rings: 8),
      );

  MeshGeometry head() => _cache.putIfAbsent(
        'head',
        () => SphereGeometry(radius: 0.135, segments: 20, rings: 12),
      );

  /// Large rounded bubble helmet.
  MeshGeometry helmet() => _cache.putIfAbsent(
        'helmet',
        () => SphereGeometry(radius: 0.162, segments: 24, rings: 14),
      );

  /// Side comms/ear pods on the helmet.
  MeshGeometry helmetEar() => _cache.putIfAbsent(
        'helmet-ear',
        () => SphereGeometry(radius: 0.035, segments: 12, rings: 8),
      );

  /// Distinct curved visor.
  MeshGeometry visor() => _cache.putIfAbsent(
        'visor',
        () => CapsuleGeometry(
          radius: 0.10,
          height: 0.12,
          radialSegments: 16,
          capRings: 6,
        ),
      );

  MeshGeometry pack() => _cache.putIfAbsent(
        'pack',
        () => CuboidGeometry(vm.Vector3(0.23, 0.25, 0.13)),
      );

  /// Oxygen tanks on the backpack (PLSS).
  MeshGeometry oxygenTank() => _cache.putIfAbsent(
        'oxygen-tank',
        () => CapsuleGeometry(
          radius: 0.038,
          height: 0.19,
          radialSegments: 12,
          capRings: 4,
        ),
      );

  /// Chest control panel module for life support.
  MeshGeometry chestPanel() => _cache.putIfAbsent(
        'chest-panel',
        () => CuboidGeometry(vm.Vector3(0.13, 0.085, 0.035)),
      );

  /// Cute interactive buttons on the chest control panel.
  MeshGeometry chestButton() => _cache.putIfAbsent(
        'chest-button',
        () => SphereGeometry(radius: 0.015, segments: 10, rings: 6),
      );

  MeshGeometry arm() => _cache.putIfAbsent(
        'arm',
        () => CapsuleGeometry(
          radius: 0.046,
          height: 0.14,
          radialSegments: 12,
          capRings: 4,
        ),
      );

  /// Rounded space glove at the end of each arm.
  MeshGeometry glove() => _cache.putIfAbsent(
        'glove',
        () => SphereGeometry(radius: 0.052, segments: 14, rings: 8),
      );

  MeshGeometry leg() => _cache.putIfAbsent(
        'leg',
        () => CapsuleGeometry(
          radius: 0.058,
          height: 0.16,
          radialSegments: 12,
          capRings: 4,
        ),
      );

  MeshGeometry boot() => _cache.putIfAbsent(
        'boot',
        () => CapsuleGeometry(
          radius: 0.068,
          height: 0.05,
          radialSegments: 12,
          capRings: 4,
        ),
      );

  /// Heavy lunar boot sole.
  MeshGeometry bootSole() => _cache.putIfAbsent(
        'boot-sole',
        () => CuboidGeometry(vm.Vector3(0.062, 0.022, 0.092)),
      );

  MeshGeometry badge() => _cache.putIfAbsent(
        'badge',
        () => SphereGeometry(radius: 0.030, segments: 10, rings: 6),
      );

  MeshGeometry antennaStem() => _cache.putIfAbsent(
        'antenna-stem',
        () => CapsuleGeometry(
          radius: 0.012,
          height: 0.11,
          radialSegments: 6,
          capRings: 2,
        ),
      );

  MeshGeometry antennaTip() => _cache.putIfAbsent(
        'antenna-tip',
        () => SphereGeometry(radius: 0.030, segments: 12, rings: 8),
      );

  /// Stand-in for the mission's target planet.
  MeshGeometry target() => _cache.putIfAbsent(
        'target',
        () => SphereGeometry(radius: 0.085, segments: 18, rings: 12),
      );

  void dispose() => _cache.clear();
}
