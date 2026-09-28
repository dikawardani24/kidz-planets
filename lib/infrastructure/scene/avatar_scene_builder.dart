import 'dart:math' as math;

import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../application/state/avatar_state.dart';
import '../../application/state/explorer_state.dart';
import 'avatar_geometry.dart';
import 'avatar_materials.dart';

/// Builds and owns the sleek Sci-Fi Robot / Space Drone companion graph.
///
/// Clean, adorable, high-tech floating robot buddy with a glowing digital visor screen,
/// anti-gravity thruster ring, comms antenna, and dynamic planetary reactions.
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

  Node? _antennaNode;
  Node? _leftPod;
  Node? _rightPod;

  UnlitMaterial? _visorMaterial;
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
    final chassisMat = materials.chassis();
    final trimMat = materials.trim();
    final visorMat = materials.visorScreen();
    final beaconMat = materials.beacon();

    _visorMaterial = visorMat;

    // Main spherical robot chassis
    bodyRoot.add(
      _mesh('chassis', geometries.chassis(), chassisMat)
        ..position = vm.Vector3(0, 0.05, 0),
    );

    // Digital visor screen face
    bodyRoot.add(
      _mesh('visor', geometries.visorScreen(), visorMat)
        ..position = vm.Vector3(0, 0.05, -0.145),
    );

    // Anti-gravity thruster ring at base
    bodyRoot.add(
      _mesh('thruster-ring', geometries.thrusterRing(), trimMat)
        ..position = vm.Vector3(0, -0.14, 0),
    );

    // Side floating sensor pods
    _leftPod = _mesh('pod-left', geometries.sidePod(), trimMat)
      ..position = vm.Vector3(-0.20, 0.05, 0);
    _rightPod = _mesh('pod-right', geometries.sidePod(), trimMat)
      ..position = vm.Vector3(0.20, 0.05, 0);
    bodyRoot
      ..add(_leftPod!)
      ..add(_rightPod!);

    // Antenna stem and glowing beacon
    bodyRoot.add(
      _mesh('antenna-stem', geometries.antennaStem(), trimMat)
        ..position = vm.Vector3(0, 0.22, 0),
    );
    _antennaNode = _mesh('antenna-tip', geometries.antennaTip(), beaconMat)
      ..position = vm.Vector3(0, 0.30, 0);
    bodyRoot.add(_antennaNode!);
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
      // Shivering / vibrating when cold
      hover = math.sin(t * 30.0) * 0.008;
      tilt = math.sin(t * 20.0) * 0.08;
    } else if (isHotWorld) {
      // Fast bobbing when hot
      hover = math.sin(t * 8.0) * 0.03;
      tilt = 0.15;
    } else if (idleAction == AvatarIdleAction.dancing) {
      hover = math.sin(t * 9.0).abs() * 0.06;
      tilt = math.sin(t * 6.0) * 0.25;
    } else if (idleAction == AvatarIdleAction.thinking) {
      hover = math.sin(t * 2.0) * 0.01;
      tilt = -0.15;
    } else if (idleAction == AvatarIdleAction.sitting) {
      hover = -0.10;
    } else {
      // Gentle floating hover
      hover = math.sin(t * 3.0) * 0.018;
    }

    bodyRoot
      ..position = vm.Vector3(0, hover + 0.02, 0)
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), tilt);

    // Antenna pulse
    final pulseRate = isIceWorld ? 15.0 : (isHotWorld ? 12.0 : 3.0);
    _antennaNode?.position = vm.Vector3(
      math.sin(t * pulseRate) * 0.03,
      0.30,
      0,
    );

    _setVisorColor(mood, idleAction, selectedPlanetId);
  }

  void _setVisorColor(AvatarMood mood, AvatarIdleAction idleAction, String? selectedPlanetId) {
    final material = _visorMaterial;
    if (material == null) return;
    final color = switch (selectedPlanetId) {
      'neptune' || 'uranus' || 'pluto' => const Color(0xFF38BDF8), // Freezing ice blue
      'sun' || 'mercury' || 'venus' => const Color(0xFFFBBF24), // Scorching orange/yellow
      _ => switch (idleAction) {
          AvatarIdleAction.dancing => const Color(0xFF10B981),
          AvatarIdleAction.thinking => const Color(0xFF8B5CF6),
          AvatarIdleAction.sitting => const Color(0xFF64748B),
          AvatarIdleAction.flying => const Color(0xFF06B6D4),
          AvatarIdleAction.sendingHeart => const Color(0xFFEC4899),
          AvatarIdleAction.none => switch (mood) {
              AvatarMood.instruction => const Color(0xFF38BDF8),
              AvatarMood.searching => const Color(0xFF0EA5E9),
              AvatarMood.wrong => const Color(0xFF7C3AED),
              AvatarMood.retry => const Color(0xFF8B7CFF),
              AvatarMood.success => const Color(0xFFF59E0B),
            },
        },
    };
    if (_visorColor == color) return;
    _visorColor = color;
    material.baseColorFactor = vm.Vector4(
      color.r.toDouble(),
      color.g.toDouble(),
      color.b.toDouble(),
      1.0,
    );
  }

  Color? _visorColor;

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
