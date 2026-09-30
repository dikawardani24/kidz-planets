import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Materials for the Chubby Cartoon Rocket Ship Mascot.
class AvatarMaterialFactory {
  AvatarMaterialFactory();

  /// Rocket body: vibrant, glossy space red.
  PhysicallyBasedMaterial rocketBody() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.95, 0.22, 0.25, 1.0)
      ..metallicFactor = 0.20
      ..roughnessFactor = 0.30;
  }

  /// Nosecone & accents: crisp white.
  PhysicallyBasedMaterial whiteAccent() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.97, 0.98, 1.0, 1.0)
      ..metallicFactor = 0.10
      ..roughnessFactor = 0.25;
  }

  /// Fins: sunny yellow.
  PhysicallyBasedMaterial fins() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.98, 0.82, 0.15, 1.0)
      ..metallicFactor = 0.15
      ..roughnessFactor = 0.40;
  }

  /// Porthole window: glowing cyan/blue glass.
  UnlitMaterial porthole() {
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.12, 0.75, 0.98, 1.0);
  }

  /// Stand-in for the mission target.
  UnlitMaterial target() {
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.22, 0.74, 1.0, 1.0);
  }

}
