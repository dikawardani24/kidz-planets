import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Materials for the mission companion (SRP: materials only).
///
/// The suit is a lit PBR material so it responds to the scene light and reads
/// as a real 3D object rather than a flat sticker. The visor, badge, and
/// target are unlit: they are the character's face and its signal to the child,
/// and they need to stay legible at any angle, in any mood, and at ~120px.
class AvatarMaterialFactory {
  AvatarMaterialFactory();

  /// Suit: matte white dielectric, a touch of metallic so it catches a
  /// highlight and does not go flat.
  PhysicallyBasedMaterial suit() {
    final material = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.93, 0.95, 1.0, 1.0)
      ..metallicFactor = 0.10
      ..roughnessFactor = 0.45;
    return material;
  }

  /// Coloured trim: boots, antenna stem, and suit accents.
  PhysicallyBasedMaterial trim() {
    final material = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.28, 0.36, 0.62, 1.0)
      ..metallicFactor = 0.05
      ..roughnessFactor = 0.60;
    return material;
  }

  /// Backpack, kept darker so the silhouette has depth from behind too.
  PhysicallyBasedMaterial pack() {
    final material = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.72, 0.75, 0.82, 1.0)
      ..metallicFactor = 0.20
      ..roughnessFactor = 0.50;
    return material;
  }

  /// Helmet: near-transparent, so the head reads inside it.
  UnlitMaterial glass() {
    final material = UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.72, 0.85, 1.0, 0.28);
    return material;
  }

  /// The visor. Its colour is swapped per mood by the builder, which is this
  /// character's closest equivalent to a facial expression.
  UnlitMaterial visor() {
    final material = UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.12, 0.23, 0.54, 1.0);
    return material;
  }

  /// Chest badge and antenna tip: small unlit accents that stay readable from
  /// any angle.
  UnlitMaterial badge() {
    final material = UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.98, 0.75, 0.14, 1.0);
    return material;
  }

  /// Stand-in for the mission target. Tinted to the real planet's colour at
  /// runtime, so it is recognisably the same world the child is exploring.
  UnlitMaterial target() {
    final material = UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.22, 0.74, 1.0, 1.0);
    return material;
  }
}
