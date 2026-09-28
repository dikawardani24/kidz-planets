import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Materials for the mission companion (SRP: materials only).
///
/// Provides rich PBR and unlit materials for a distinct, polished astronaut suit.
class AvatarMaterialFactory {
  AvatarMaterialFactory();

  /// Suit: matte white dielectric with subtle specularity.
  PhysicallyBasedMaterial suit() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.95, 0.96, 1.0, 1.0)
      ..metallicFactor = 0.08
      ..roughnessFactor = 0.40;
  }

  /// Helmet dome: smooth, glossy white helmet shell.
  PhysicallyBasedMaterial helmetDome() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.97, 0.98, 1.0, 1.0)
      ..metallicFactor = 0.15
      ..roughnessFactor = 0.25;
  }

  /// Coloured trim: boots, gloves, belt, shoulder pauldrons, and suit accents.
  PhysicallyBasedMaterial trim() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.24, 0.35, 0.70, 1.0)
      ..metallicFactor = 0.15
      ..roughnessFactor = 0.50;
  }

  /// Belt accent material.
  PhysicallyBasedMaterial belt() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.18, 0.22, 0.30, 1.0)
      ..metallicFactor = 0.25
      ..roughnessFactor = 0.45;
  }

  /// Boot soles: heavy dark grip material.
  PhysicallyBasedMaterial sole() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.12, 0.14, 0.18, 1.0)
      ..metallicFactor = 0.05
      ..roughnessFactor = 0.85;
  }

  /// Backpack and life support equipment.
  PhysicallyBasedMaterial pack() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.78, 0.81, 0.88, 1.0)
      ..metallicFactor = 0.25
      ..roughnessFactor = 0.45;
  }

  /// Oxygen tanks on backpack: sleek metallic silver-blue.
  PhysicallyBasedMaterial tank() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.85, 0.89, 0.95, 1.0)
      ..metallicFactor = 0.45
      ..roughnessFactor = 0.30;
  }

  /// Chest control panel module.
  PhysicallyBasedMaterial chestPanel() {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.20, 0.24, 0.32, 1.0)
      ..metallicFactor = 0.35
      ..roughnessFactor = 0.38;
  }

  /// Kid-friendly vibrant unlit buttons for the chest console.
  UnlitMaterial buttonRed() => UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.96, 0.25, 0.25, 1.0);

  UnlitMaterial buttonGreen() => UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.15, 0.88, 0.42, 1.0);

  UnlitMaterial buttonYellow() => UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.98, 0.82, 0.12, 1.0);

  /// The visor. Sleek modern obsidian dark mirror finish (SpaceX EVA style).
  UnlitMaterial visor() {
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.08, 0.10, 0.15, 1.0);
  }

  /// Chest badge and antenna tip.
  UnlitMaterial badge() {
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.98, 0.72, 0.12, 1.0);
  }

  /// Stand-in for the mission target.
  UnlitMaterial target() {
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.22, 0.74, 1.0, 1.0);
  }
}
