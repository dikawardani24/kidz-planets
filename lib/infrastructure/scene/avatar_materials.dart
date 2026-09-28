import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Materials for the sleek Sci-Fi Robot / Space Drone companion.
class AvatarMaterialFactory {
  AvatarMaterialFactory();

  /// Chassis: polished metallic white / silver PBR material.
  PhysicallyBasedMaterial chassis() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.92, 0.94, 0.98, 1.0)
      ..metallicFactor = 0.40
      ..roughnessFactor = 0.25;
  }

  /// Metallic trim / accents.
  PhysicallyBasedMaterial trim() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.18, 0.45, 0.85, 1.0)
      ..metallicFactor = 0.50
      ..roughnessFactor = 0.30;
  }

  /// Digital visor screen: glowing high-tech cyan/blue display.
  UnlitMaterial visorScreen() {
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.08, 0.75, 0.98, 1.0);
  }

  /// Antenna glowing beacon.
  UnlitMaterial beacon() {
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.98, 0.82, 0.15, 1.0);
  }

  /// Stand-in for the mission target.
  UnlitMaterial target() {
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.22, 0.74, 1.0, 1.0);
  }
}
