import 'dart:math' as math;

import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../application/state/avatar_state.dart';
import '../../application/state/explorer_state.dart';
import 'avatar_geometry.dart';
import 'avatar_materials.dart';

/// Builds and owns the Chubby Cartoon Rocket Ship Mascot graph.
///
/// A delightful, adorable miniature rocket ship with a glossy red body,
/// crisp white nosecone, glowing porthole window, sunny yellow fins,
/// and dynamic planetary reactions.
class AvatarSceneBuilder {
  AvatarSceneBuilder({
    required this.geometries,
    required this.materials,
  });

  final AvatarGeometryFactory geometries;
  final AvatarMaterialFactory materials;

  final Node avatarRoot = Node(name: 'avatar-root');
  final Node bodyRoot = Node(name: 'avatar-body');
  final Node targetPivot = Node(name: 'avatar-target');

  UnlitMaterial? _portholeMaterial;
  UnlitMaterial? _targetMaterial;

  void build(Scene scene) {
    scene
      ..environmentIntensity = 0.60
      ..add(
        Node(name: 'avatar:light')
          ..addComponent(
            DirectionalLightComponent.aimed(
              DirectionalLight(
                color: vm.Vector3(1.0, 0.97, 0.92),
                intensity: 2.8,
              ),
              vm.Vector3(0.4, -1.0, 0.6),
            ),
          ),
      );

    avatarRoot.add(bodyRoot);
    scene.add(avatarRoot);

    _buildBody();
    _buildTarget();
  }

  void _buildBody() {
    final bodyMat = materials.rocketBody();
    final whiteMat = materials.whiteAccent();
    final finMat = materials.fins();
    final portholeMat = materials.porthole();

    _portholeMaterial = portholeMat;

    // Rocket fuselage body
    bodyRoot.add(
      _mesh('fuselage', geometries.rocketBody(), bodyMat)
        ..position = vm.Vector3(0, 0, 0),
    );

    // Rounded nosecone
    bodyRoot.add(
      _mesh('nosecone', geometries.noseCone(), whiteMat)
        ..position = vm.Vector3(0, 0.22, 0),
    );

    // Front porthole window
    bodyRoot.add(
      _mesh('porthole', geometries.porthole(), portholeMat)
        ..position = vm.Vector3(0, 0.05, -0.12),
    );

    // Side fins / wings
    bodyRoot.add(
      _mesh('fin-left', geometries.fin(), finMat)
        ..position = vm.Vector3(-0.16, -0.10, 0),
    );
    bodyRoot.add(
      _mesh('fin-right', geometries.fin(), finMat)
        ..position = vm.Vector3(0.16, -0.10, 0),
    );

    // Engine nozzle at base
    bodyRoot.add(
      _mesh('engine', geometries.engineNozzle(), whiteMat)
        ..position = vm.Vector3(0, -0.22, 0),
    );
  }

  void _buildTarget() {
    _targetMaterial = materials.target();
    targetPivot.add(
      _mesh('target-body', geometries.target(), _targetMaterial!),
    );
    targetPivot.add(
      Node(name: 'target-ring')
        ..addComponent(
          DirectionalLightComponent.aimed(
            DirectionalLight(
              color: vm.Vector3(0.35, 0.75, 1.0),
              intensity: 1.6,
            ),
            vm.Vector3(0, -1.0, 0),
          ),
        )
        ..position = vm.Vector3(0, 0, -0.9),
    );
    targetPivot.visible = false;
    avatarRoot.add(targetPivot);
  }

  Node _mesh(String name, MeshGeometry geometry, Material material) {
    final node = Node(mesh: Mesh(geometry, material))..name = name;
    node.raycastable = false;
    return node;
  }

  void setRotation(AvatarState pose) {
    avatarRoot.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      pose.yaw,
    ) * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), pose.pitchClamped);
  }

  void tick(Duration elapsed, AvatarMood mood, AvatarIdleAction idleAction, String? selectedPlanetId) {
    final t = elapsed.inMicroseconds / 1e6;

    double hover = 0.0;
    double tilt = 0.0;

    final isIceWorld = selectedPlanetId == 'neptune' ||
        selectedPlanetId == 'uranus' ||
        selectedPlanetId == 'pluto';
    final isHotWorld = selectedPlanetId == 'sun' ||
        selectedPlanetId == 'mercury' ||
        selectedPlanetId == 'venus';

    if (isIceWorld) {
      hover = math.sin(t * 30.0) * 0.008;
      tilt = math.sin(t * 20.0) * 0.08;
    } else if (isHotWorld) {
      hover = math.sin(t * 8.0) * 0.03;
      tilt = 0.15;
    } else if (idleAction == AvatarIdleAction.dancing) {
      hover = math.sin(t * 9.0).abs() * 0.07;
      tilt = math.sin(t * 6.0) * 0.3;
    } else if (idleAction == AvatarIdleAction.thinking) {
      hover = math.sin(t * 2.0) * 0.01;
      tilt = -0.15;
    } else if (idleAction == AvatarIdleAction.sitting) {
      hover = -0.12;
    } else if (idleAction == AvatarIdleAction.flying) {
      // Rocket banking forward when flying!
      hover = math.sin(t * 6.0) * 0.04;
      tilt = 0.35; // Bank forward in flight
    } else {
      hover = math.sin(t * 3.0) * 0.02;
    }

    bodyRoot
      ..position = vm.Vector3(0, hover, 0)
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), tilt);

    _setPortholeColor(mood, idleAction, selectedPlanetId);
  }

  void _setPortholeColor(AvatarMood mood, AvatarIdleAction idleAction, String? selectedPlanetId) {
    final material = _portholeMaterial;
    if (material == null) return;
    final color = switch (selectedPlanetId) {
      'neptune' || 'uranus' || 'pluto' => const Color(0xFF38BDF8),
      'sun' || 'mercury' || 'venus' => const Color(0xFFFBBF24),
      _ => switch (idleAction) {
          AvatarIdleAction.dancing => const Color(0xFF10B981),
          AvatarIdleAction.thinking => const Color(0xFF8B5CF6),
          AvatarIdleAction.sitting => const Color(0xFF64748B),
          AvatarIdleAction.flying => const Color(0xFF06B6D4),
          AvatarIdleAction.sendingHeart => const Color(0xFFEC4899),
          AvatarIdleAction.none => const Color(0xFF12B981),
        },
    };
    if (_portholeColor == color) return;
    _portholeColor = color;
    material.baseColorFactor = vm.Vector4(
      color.r.toDouble(),
      color.g.toDouble(),
      color.b.toDouble(),
      1.0,
    );
  }

  Color? _portholeColor;

  void showTarget({required bool visible, required Color color}) {
    targetPivot.visible = visible;
    if (!visible) return;
    targetPivot.position = vm.Vector3(-0.62, 0.10, 0);
    final material = _targetMaterial;
    if (material == null || _targetColor == color) return;
    _targetColor = color;
    material.baseColorFactor = vm.Vector4(
      color.r.toDouble(),
      color.g.toDouble(),
      color.b.toDouble(),
      1.0,
    );
  }

  Color? _targetColor;

  void detachFrom(Scene scene) {
    scene.remove(avatarRoot);
  }
}
