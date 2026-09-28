import 'dart:math' as math;

import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../application/state/avatar_state.dart';
import '../../application/state/explorer_state.dart';
import 'avatar_geometry.dart';
import 'avatar_materials.dart';

/// Builds and owns the companion's flutter_scene graph (SRP: scene only).
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
  Node? _leftArm;
  Node? _rightArm;

  UnlitMaterial? _visorMaterial;
  UnlitMaterial? _targetMaterial;

  void build(Scene scene) {
    scene
      ..environmentIntensity = 0.55
      ..add(
        Node(name: 'avatar:light')
          ..addComponent(
            DirectionalLightComponent.aimed(
              DirectionalLight(
                color: vm.Vector3(1.0, 0.97, 0.92),
                intensity: 2.6,
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
    final suit = materials.suit();
    final helmetMat = materials.helmetDome();
    final trim = materials.trim();
    final beltMat = materials.belt();
    final soleMat = materials.sole();
    final visor = materials.visor();
    final pack = materials.pack();
    final panelMat = materials.chestPanel();
    final tankMat = materials.tank();
    final redBtn = materials.buttonRed();
    final greenBtn = materials.buttonGreen();
    final yellowBtn = materials.buttonYellow();

    bodyRoot.add(
      _mesh('torso', geometries.torso(), suit)
        ..position = vm.Vector3(0, 0.02, 0),
    );

    bodyRoot.add(
      _mesh('waist', geometries.waist(), suit)
        ..position = vm.Vector3(0, -0.13, 0),
    );
    bodyRoot.add(
      _mesh('belt', geometries.belt(), beltMat)
        ..position = vm.Vector3(0, -0.10, 0),
    );
    bodyRoot.add(
      _mesh('belt-buckle', geometries.badge(), materials.badge())
        ..position = vm.Vector3(0, -0.10, -0.145),
    );

    bodyRoot.add(
      _mesh('collar', geometries.collar(), trim)
        ..position = vm.Vector3(0, 0.18, 0),
    );

    bodyRoot.add(
      _mesh('chest-panel', geometries.chestPanel(), panelMat)
        ..position = vm.Vector3(0, 0.04, -0.165),
    );
    bodyRoot.add(
      _mesh('btn-red', geometries.chestButton(), redBtn)
        ..position = vm.Vector3(-0.04, 0.05, -0.184),
    );
    bodyRoot.add(
      _mesh('btn-green', geometries.chestButton(), greenBtn)
        ..position = vm.Vector3(0.0, 0.05, -0.184),
    );
    bodyRoot.add(
      _mesh('btn-yellow', geometries.chestButton(), yellowBtn)
        ..position = vm.Vector3(0.04, 0.05, -0.184),
    );

    bodyRoot.add(
      _mesh('pack', geometries.pack(), pack)
        ..position = vm.Vector3(0, 0.05, 0.21),
    );
    bodyRoot.add(
      _mesh('tank-left', geometries.oxygenTank(), tankMat)
        ..position = vm.Vector3(-0.075, 0.05, 0.25),
    );
    bodyRoot.add(
      _mesh('tank-right', geometries.oxygenTank(), tankMat)
        ..position = vm.Vector3(0.075, 0.05, 0.25),
    );

    bodyRoot.add(
      _mesh('helmet', geometries.helmet(), helmetMat)
        ..position = vm.Vector3(0, 0.40, 0),
    );

    bodyRoot.add(
      _mesh('ear-left', geometries.helmetEar(), trim)
        ..position = vm.Vector3(-0.165, 0.40, 0),
    );
    bodyRoot.add(
      _mesh('ear-right', geometries.helmetEar(), trim)
        ..position = vm.Vector3(0.165, 0.40, 0),
    );

    _visorMaterial = visor;
    bodyRoot.add(
      _mesh('visor', geometries.visor(), visor)
        ..position = vm.Vector3(0, 0.39, -0.155),
    );

    bodyRoot.add(
      _mesh('shoulder-left', geometries.shoulderPad(), trim)
        ..position = vm.Vector3(-0.20, 0.12, 0),
    );
    bodyRoot.add(
      _mesh('shoulder-right', geometries.shoulderPad(), trim)
        ..position = vm.Vector3(0.20, 0.12, 0),
    );

    _leftArm = _mesh('arm-left', geometries.arm(), suit)
      ..position = vm.Vector3(-0.215, 0.01, 0);
    _rightArm = _mesh('arm-right', geometries.arm(), suit)
      ..position = vm.Vector3(0.215, 0.01, 0);

    final leftGlove = _mesh('glove-left', geometries.glove(), trim)
      ..position = vm.Vector3(-0.215, -0.09, 0);
    final rightGlove = _mesh('glove-right', geometries.glove(), trim)
      ..position = vm.Vector3(0.215, -0.09, 0);

    bodyRoot
      ..add(_leftArm!)
      ..add(_rightArm!)
      ..add(leftGlove)
      ..add(rightGlove);

    bodyRoot
      ..add(
        _mesh('leg-left', geometries.leg(), suit)
          ..position = vm.Vector3(-0.085, -0.27, 0),
      )
      ..add(
        _mesh('leg-right', geometries.leg(), suit)
          ..position = vm.Vector3(0.085, -0.27, 0),
      )
      ..add(
        _mesh('boot-left', geometries.boot(), trim)
          ..position = vm.Vector3(-0.085, -0.41, -0.01),
      )
      ..add(
        _mesh('boot-right', geometries.boot(), trim)
          ..position = vm.Vector3(0.085, -0.41, -0.01),
      )
      ..add(
        _mesh('sole-left', geometries.bootSole(), soleMat)
          ..position = vm.Vector3(-0.085, -0.44, 0.01),
      )
      ..add(
        _mesh('sole-right', geometries.bootSole(), soleMat)
          ..position = vm.Vector3(0.085, -0.44, 0.01),
      );

    bodyRoot.add(
      _mesh('badge', geometries.badge(), materials.badge())..position =
          vm.Vector3(-0.07, 0.12, -0.17),
    );

    bodyRoot.add(
      _mesh('antenna-stem', geometries.antennaStem(), trim)
        ..position = vm.Vector3(0, 0.60, 0.02),
    );
    _antennaNode = _mesh('antenna-tip', geometries.antennaTip(), materials.badge())
      ..position = vm.Vector3(0, 0.67, 0.02);
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

  void tick(Duration elapsed, AvatarMood mood, AvatarIdleAction idleAction) {
    final t = elapsed.inMicroseconds / 1e6;

    double bob = 0.0;
    double slump = 0.0;
    double armLift = 0.0;
    double bodyTilt = 0.0;

    if (mood == AvatarMood.success || idleAction == AvatarIdleAction.dancing) {
      final speed = idleAction == AvatarIdleAction.dancing ? 9.0 : 7.0;
      bob = math.sin(t * speed).abs() * 0.07;
      armLift = -1.6 + math.sin(t * 7.0) * 0.4;
      bodyTilt = math.sin(t * 6.0) * 0.15;
    } else if (idleAction == AvatarIdleAction.thinking) {
      bob = math.sin(t * 2.0) * 0.008;
      armLift = -0.9;
      bodyTilt = -0.08;
    } else if (idleAction == AvatarIdleAction.sitting) {
      bob = -0.14; // sits down lower
    } else if (idleAction == AvatarIdleAction.flying) {
      bob = math.sin(t * 5.0) * 0.04;
      bodyTilt = 0.2; // flying tilt forward
    } else {
      bob = math.sin(t * 2.2) * 0.010;
    }

    if (mood == AvatarMood.wrong || mood == AvatarMood.retry) {
      bob *= 0.35;
      slump = -0.10;
    }

    bodyRoot
      ..position = vm.Vector3(0, bob + 0.02, 0)
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), slump + bodyTilt);

    final sway = math.sin(t * 1.6) * 0.16;
    _leftArm?.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 0, 1),
      (armLift != 0.0 ? armLift : -0.35) + sway,
    );
    _rightArm?.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 0, 1),
      (armLift != 0.0 ? armLift : -0.35) - sway,
    );

    final talking = mood == AvatarMood.instruction || mood == AvatarMood.retry || idleAction == AvatarIdleAction.dancing || idleAction == AvatarIdleAction.sendingHeart;
    final antennaRate = talking ? 9.0 : 1.5;
    final antennaSwing = talking ? 0.22 : 0.06;
    _antennaNode?.position = vm.Vector3(
      math.sin(t * antennaRate) * antennaSwing,
      0.67,
      0.02,
    );

    _setVisorTint(mood, idleAction);
  }

  void _setVisorTint(AvatarMood mood, AvatarIdleAction idleAction) {
    final material = _visorMaterial;
    if (material == null) return;
    final color = switch (idleAction) {
      AvatarIdleAction.dancing => const Color(0xFF10B981), // Emerald green
      AvatarIdleAction.thinking => const Color(0xFF8B5CF6), // Violet
      AvatarIdleAction.sitting => const Color(0xFF64748B), // Slate
      AvatarIdleAction.flying => const Color(0xFF06B6D4), // Cyan
      AvatarIdleAction.sendingHeart => const Color(0xFFEC4899), // Pink
      AvatarIdleAction.none => switch (mood) {
          AvatarMood.instruction => const Color(0xFF38BDF8),
          AvatarMood.searching => const Color(0xFF0EA5E9),
          AvatarMood.wrong => const Color(0xFF7C3AED),
          AvatarMood.retry => const Color(0xFF8B7CFF),
          AvatarMood.success => const Color(0xFFF59E0B),
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
