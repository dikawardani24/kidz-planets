import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Creates shared geometries keyed by value (SRP: geometry only).
///
/// Radius-keyed cache keeps sibling planets that coincidentally share a
/// radius on the same GPU buffers. Sphere tessellation is fixed so the
/// cache key stays a single double.
class GeometryFactory {
  GeometryFactory();

  final Map<double, SphereGeometry> _spheres = {};
  final Map<String, RingGeometry> _rings = {};
  final Map<String, TorusGeometry> _tori = {};
  final Map<double, MeshGeometry> _saturnRingSystems = {};

  SphereGeometry sphere(double radius) => _spheres.putIfAbsent(
    radius,
    () => SphereGeometry(radius: radius, segments: 48, rings: 32),
  );

  /// Flat orbit ring in the XZ plane.
  RingGeometry orbitRing(double radius) => _rings.putIfAbsent(
    'orbit:$radius',
    () => RingGeometry(
      innerRadius: radius - 0.045,
      outerRadius: radius + 0.045,
      segments: 128,
    ),
  );

  /// One combined Saturn ring mesh containing the broad bands, fine ringlets,
  /// and the tiny edge-support planes needed at grazing angles.
  ///
  /// The old implementation represented every ring layer as its own Node + Mesh
  /// + Material. That is visually useful while authoring, but expensive to submit:
  /// the final ring system is one immutable mesh and one material, with opacity
  /// carried by vertex colors. The three physical torus edge profiles remain
  /// separate because they provide genuine thickness at exact edge-on views.
  MeshGeometry saturnRingSystem(double planetRadius) =>
      _saturnRingSystems.putIfAbsent(planetRadius, () {
        final builder = GeometryBuilder(deduplicate: false);
        const segments = 128;
        const edgeAngle = 0.022;

        void addAnnulus({
          required double inner,
          required double outer,
          required double opacity,
          required double rotationX,
        }) {
          final normal = vm.Vector3(
            0,
            math.cos(rotationX),
            math.sin(rotationX),
          );
          final color = vm.Vector4(0.88, 0.83, 0.70, opacity);
          for (var i = 0; i < segments; i++) {
            final a0 = i * math.pi * 2 / segments;
            final a1 = (i + 1) * math.pi * 2 / segments;
            final c0 = math.cos(a0);
            final s0 = math.sin(a0);
            final c1 = math.cos(a1);
            final s1 = math.sin(a1);

            vm.Vector3 point(double radius, double c, double s) {
              final y = -radius * s * math.sin(rotationX);
              final z = radius * s * math.cos(rotationX);
              return vm.Vector3(radius * c, y, z);
            }

            builder.color(color).normal(normal);
            final a = builder.addVertex(point(inner, c0, s0));
            final b = builder.addVertex(point(outer, c0, s0));
            final c = builder.addVertex(point(outer, c1, s1));
            final d = builder.addVertex(point(inner, c1, s1));
            builder
              ..addTriangle(a, b, c)
              ..addTriangle(a, c, d);
          }
        }

        const broad = <({double inner, double outer, double opacity})>[
          (inner: 1.22, outer: 1.53, opacity: 0.16),
          (inner: 1.54, outer: 1.96, opacity: 0.28),
          (inner: 2.03, outer: 2.28, opacity: 0.20),
        ];
        for (final band in broad) {
          final inner = planetRadius * band.inner;
          final outer = planetRadius * band.outer;
          addAnnulus(inner: inner, outer: outer, opacity: band.opacity, rotationX: 0);
          addAnnulus(inner: inner, outer: outer, opacity: band.opacity * 0.18, rotationX: edgeAngle);
          addAnnulus(inner: inner, outer: outer, opacity: band.opacity * 0.18, rotationX: -edgeAngle);
        }

        const strands = <({double radius, double width, double opacity})>[
          (radius: 1.255, width: 0.010, opacity: 0.18),
          (radius: 1.285, width: 0.006, opacity: 0.32),
          (radius: 1.335, width: 0.012, opacity: 0.20),
          (radius: 1.375, width: 0.006, opacity: 0.34),
          (radius: 1.415, width: 0.009, opacity: 0.22),
          (radius: 1.465, width: 0.014, opacity: 0.30),
          (radius: 1.515, width: 0.008, opacity: 0.26),
          (radius: 1.575, width: 0.012, opacity: 0.42),
          (radius: 1.625, width: 0.007, opacity: 0.26),
          (radius: 1.685, width: 0.015, opacity: 0.48),
          (radius: 1.755, width: 0.009, opacity: 0.30),
          (radius: 1.825, width: 0.018, opacity: 0.54),
          (radius: 1.885, width: 0.010, opacity: 0.34),
          (radius: 2.045, width: 0.008, opacity: 0.28),
          (radius: 2.085, width: 0.012, opacity: 0.42),
          (radius: 2.135, width: 0.007, opacity: 0.30),
          (radius: 2.185, width: 0.015, opacity: 0.46),
          (radius: 2.235, width: 0.009, opacity: 0.30),
          (radius: 2.275, width: 0.006, opacity: 0.18),
          (radius: 2.335, width: 0.012, opacity: 0.38),
          (radius: 2.352, width: 0.004, opacity: 0.52),
          (radius: 2.405, width: 0.004, opacity: 0.10),
          (radius: 2.445, width: 0.006, opacity: 0.07),
        ];
        for (final strand in strands) {
          final inner = planetRadius * (strand.radius - strand.width / 2);
          final outer = planetRadius * (strand.radius + strand.width / 2);
          addAnnulus(inner: inner, outer: outer, opacity: strand.opacity, rotationX: 0);
          addAnnulus(inner: inner, outer: outer, opacity: strand.opacity * 0.18, rotationX: edgeAngle);
          addAnnulus(inner: inner, outer: outer, opacity: strand.opacity * 0.18, rotationX: -edgeAngle);
        }

        return builder.build(retainCpuData: false);
      });

  /// Thin torus used as a physical edge profile for Saturn's rings.
  ///
  /// Flat RingGeometry has zero projected area when viewed edge-on, so it
  /// can legitimately vanish. These thin toruses preserve subtle thickness.
  TorusGeometry saturnEdgeRing(double radius, double tubeRadius) =>
      _tori.putIfAbsent(
        'saturn-edge:$radius:$tubeRadius',
        () => TorusGeometry(
          radius: radius,
          tubeRadius: tubeRadius,
          radialSegments: 128,
          tubularSegments: 8,
        ),
      );

  /// Starfield-friendly large inverted sphere.
  SphereGeometry get starDome => _spheres.putIfAbsent(
    -999.0,
    () => SphereGeometry(radius: 220, segments: 32, rings: 16),
  );

  /// One-line cache census for the `scene.build` stats log.
  String describeCache() =>
      'spheres=${_spheres.length} rings=${_rings.length} tori=${_tori.length} '
      'saturnSystems=${_saturnRingSystems.length}';

  void dispose() {
    _spheres.clear();
    _rings.clear();
    _tori.clear();
    _saturnRingSystems.clear();
  }
}

/// Creates materials from loaded textures (SRP: materials only, DIP:
/// depends on [TextureProvider], not on Flutter asset APIs).
class PlanetMaterialFactory {
  PlanetMaterialFactory({this._debugTint});

  final Color? _debugTint;

  /// Lit planet surface: texture x white factor, matte dielectric.
  ///
  /// Lit by the scene's default studio environment so craters and bands
  /// read as real 3D. Falls back to a flat tint when [texture] is null
  /// (e.g. texture failed to decode on this GPU).
  PhysicallyBasedMaterial planet({
    required TextureSource? texture,
    required Color fallback,
  }) {
    final material = PhysicallyBasedMaterial(baseColorTexture: texture);
    if (texture == null) {
      final c = _debugTint ?? fallback;
      material.baseColorFactor = vm.Vector4(c.r, c.g, c.b, 1.0);
    }
    material.metallicFactor = 0.0;
    material.roughnessFactor = 0.9;
    return material;
  }

  /// Glowing sun: unlit HDR-amber texture, always bright.
  UnlitMaterial sun({required TextureSource? texture}) {
    final material = UnlitMaterial(colorTexture: texture);
    if (texture == null) {
      material.baseColorFactor = vm.Vector4(2.2, 1.35, 0.35, 1.0);
    }
    return material;
  }

  /// Flat translucent orbit path.
  UnlitMaterial orbitPath(Color color) {
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(color.r, color.g, color.b, 0.55)
      ..alphaMode = AlphaMode.blend
      ..doubleSided = true;
  }

  /// Saturn ring band inspired by NASA's translucent ring imagery.
  UnlitMaterial saturnRing({TextureSource? texture, double opacity = 0.8}) {
    final material = UnlitMaterial(colorTexture: texture);
    material.alphaMode = AlphaMode.blend;
    material.doubleSided = true;
    // Soft icy-beige rather than a saturated gold. Alpha is intentionally low:
    // NASA imagery shows the rings are translucent and reveal Saturn/shadows.
    material.baseColorFactor = vm.Vector4(0.88, 0.83, 0.70, opacity);
    return material;
  }


  /// Material for the combined Saturn ring mesh. Individual ring opacity is
  /// carried by vertex colors so all ring layers can share one draw/material.
  UnlitMaterial saturnCombinedRing() {
    final material = UnlitMaterial();
    material.alphaMode = AlphaMode.blend;
    material.doubleSided = true;
    material.baseColorFactor = vm.Vector4(1.0, 1.0, 1.0, 1.0);
    material.vertexColorWeight = 1.0;
    return material;
  }

  /// Starfield dome: unlit, inside-out via [doubleSided].
  UnlitMaterial starDome({required TextureSource? texture}) {
    final material = UnlitMaterial(colorTexture: texture);
    if (texture == null) {
      material.baseColorFactor = vm.Vector4(0.008, 0.012, 0.03, 1.0);
    }
    material.doubleSided = true;
    return material;
  }
}
