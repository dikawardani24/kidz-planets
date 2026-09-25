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

  SphereGeometry sphere(double radius) => _spheres.putIfAbsent(
        radius,
        () => SphereGeometry(
          radius: radius,
          segments: 48,
          rings: 32,
        ),
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

  /// Saturn-style band in the XZ plane.
  RingGeometry saturnBand(double inner, double outer) =>
      _rings.putIfAbsent(
        'band:$inner:$outer',
        () => RingGeometry(
          innerRadius: inner,
          outerRadius: outer,
          segments: 128,
        ),
      );

  /// Starfield-friendly large inverted sphere.
  SphereGeometry get starDome => _spheres.putIfAbsent(
        -999.0,
        () => SphereGeometry(radius: 220, segments: 32, rings: 16),
      );

  void dispose() {
    _spheres.clear();
    _rings.clear();
  }
}

/// Creates materials from loaded textures (SRP: materials only, DIP:
/// depends on [TextureProvider], not on Flutter asset APIs).
class PlanetMaterialFactory {
  PlanetMaterialFactory({Color? debugTint}) : _debugTint = debugTint;

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
    final material = PhysicallyBasedMaterial(
      baseColorTexture: texture,
    );
    if (texture == null) {
      final c = _debugTint ?? fallback;
      material.baseColorFactor =
          vm.Vector4(c.r, c.g, c.b, 1.0);
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
      ..baseColorFactor =
          vm.Vector4(color.r, color.g, color.b, 0.55)
      ..alphaMode = AlphaMode.blend
      ..doubleSided = true;
  }

  /// Saturn band: strip texture, double-sided so it reads from below.
  UnlitMaterial saturnRing({required TextureSource? texture}) {
    final material = UnlitMaterial(colorTexture: texture);
    if (texture == null) {
      material.baseColorFactor = vm.Vector4(0.89, 0.79, 0.55, 0.85);
    }
    material.alphaMode = AlphaMode.blend;
    material.doubleSided = true;
    return material;
  }

  /// Starfield dome: unlit, inside-out via [doubleSided].
  UnlitMaterial starDome({required TextureSource? texture}) {
    final material = UnlitMaterial(colorTexture: texture);
    if (texture == null) {
      material.baseColorFactor =
          vm.Vector4(0.008, 0.012, 0.03, 1.0);
    }
    material.doubleSided = true;
    return material;
  }
}
