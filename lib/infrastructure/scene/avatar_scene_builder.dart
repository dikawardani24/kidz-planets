import 'dart:math' as math;

import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../application/state/avatar_state.dart';
import '../../application/state/explorer_state.dart';
import 'avatar_geometry.dart';
import 'avatar_materials.dart';

/// Builds and owns the companion's flutter_scene graph (SRP: scene only).
///
/// The character is built from primitives rather than loaded from a file: it
/// keeps the download and the texture-memory budget at zero, it renders on
/// every device the app already supports, and it means the companion can never
/// fail to appear. Everything here is deliberately small — a few dozen
/// triangles, one light, no shadows — because this scene is an overlay that
/// draws on top of the solar system, not a second hero render.
///
/// Node layout:
///
/// ```text
/// scene
///  ├─ light
///  └─ avatarRoot        <- yaw (turn) and pitch (tilt) are written here
///      ├─ bodyRoot      <- idle bob, mood bounce, and the "wrong" slump
///      │   ├─ torso, head, helmet, visor, backpack, limbs...
///      ├─ targetPivot   <- the 3D stand-in for the mission's target planet
///      └─ shadow
/// ```
class AvatarSceneBuilder {
  AvatarSceneBuilder({
    required this.geometries,
    required this.materials,
  });

  final AvatarGeometryFactory geometries;
  final AvatarMaterialFactory materials;

  /// Turn and tilt. The widget writes [AvatarState.yaw]/[AvatarState.pitch]
  /// here, so rotation is a model transform rather than a camera move. That
  /// is what lets the companion be turned and moved independently, and what
  /// keeps it facing the child instead of swinging out of view.
  final Node avatarRoot = Node(name: 'avatar-root');

  /// Inner node for idle and mood motion, so a gesture never fights the
  /// animation: a drag moves the root, the bob moves this.
  final Node bodyRoot = Node(name: 'avatar-body');

  final Node targetPivot = Node(name: 'avatar-target');

  Node? _antennaNode;
  Node? _leftArm;
  Node? _rightArm;

  // Materials are held directly rather than dug back out of the scene graph:
  // the visor and the target are recoloured every time the mood or the
  // mission changes, and keeping the reference means that is a plain field
  // write instead of a graph walk on a path that runs per frame.
  UnlitMaterial? _visorMaterial;
  UnlitMaterial? _targetMaterial;

  /// Builds the graph under [scene].
  void build(Scene scene) {
    // The companion floats over the solar system rather than sitting in it, so
    // it gets its own small key light. No skybox: the overlay must stay
    // transparent over the scene underneath it.
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
    final trim = materials.trim();
    final visor = materials.visor();
    final pack = materials.pack();

    // Torso: a capsule reads as a soft, friendly suit without needing a rig.
    bodyRoot.add(
      _mesh('torso', geometries.torso(), suit)
        ..position = vm.Vector3(0, 0.02, 0),
    );

    // Backpack, behind the torso in +Z (the child looks down -Z).
    bodyRoot.add(
      _mesh('pack', geometries.pack(), pack)
        ..position = vm.Vector3(0, 0.04, 0.20),
    );

    // Head and helmet. The helmet is a slightly larger sphere than the head so
    // a rim of it always shows, which is what makes it read as a helmet rather
    // than a bald head.
    bodyRoot.add(
      _mesh('head', geometries.head(), suit)..position = vm.Vector3(0, 0.40, 0),
    );
    bodyRoot.add(
      _mesh('helmet', geometries.helmet(), materials.glass())..position =
          vm.Vector3(0, 0.40, 0),
    );

    // The visor faces the child, and its colour is the closest thing this
    // character has to a face: it is what changes with mood.
    _visorMaterial = visor;
    bodyRoot.add(
      _mesh('visor', geometries.visor(), visor)
        ..position = vm.Vector3(0, 0.395, -0.155),
    );

    // Arms. Kept as their own nodes so the idle sway and the success raise can
    // move them without rebuilding anything.
    _leftArm = _mesh('arm-left', geometries.arm(), suit)
      ..position = vm.Vector3(-0.215, 0.03, 0);
    _rightArm = _mesh('arm-right', geometries.arm(), suit)
      ..position = vm.Vector3(0.215, 0.03, 0);
    bodyRoot
      ..add(_leftArm!)
      ..add(_rightArm!);

    // Legs.
    bodyRoot
      ..add(
        _mesh('leg-left', geometries.leg(), suit)
          ..position = vm.Vector3(-0.085, -0.26, 0),
      )
      ..add(
        _mesh('leg-right', geometries.leg(), suit)
          ..position = vm.Vector3(0.085, -0.26, 0),
      );

    // Boots, so the character is not just legs on nothing.
    bodyRoot
      ..add(
        _mesh('boot-left', geometries.boot(), trim)
          ..position = vm.Vector3(-0.085, -0.40, -0.01),
      )
      ..add(
        _mesh('boot-right', geometries.boot(), trim)
          ..position = vm.Vector3(0.085, -0.40, -0.01),
      );

    // Chest badge: a small unlit disc that reads at any angle and gives the
    // suit a front, which is what sells the direction it is facing.
    bodyRoot.add(
      _mesh('badge', geometries.badge(), materials.badge())..position =
          vm.Vector3(0, 0.05, -0.175),
    );

    // Antenna. The bobbing tip is the companion's "talking" tell.
    bodyRoot.add(
      _mesh('antenna-stem', geometries.antennaStem(), trim)
        ..position = vm.Vector3(0, 0.60, 0.02),
    );
    _antennaNode = _mesh('antenna-tip', geometries.antennaTip(), materials.badge())
      ..position = vm.Vector3(0, 0.66, 0.02);
    bodyRoot.add(_antennaNode!);
  }

  /// The 3D stand-in for the mission's target planet.
  ///
  /// Built once and only moved and shown or hidden. The planet it stands for
  /// comes from the active mission, never from a hardcoded id, and swapping it
  /// must not disturb the companion's pose, so this deliberately touches
  /// nothing but [targetPivot].
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
    // Nothing under the companion is ever picked by a raycast: it is an
    // overlay, and a stray hit here would swallow taps meant for the planets
    // behind it.
    node.raycastable = false;
    return node;
  }

  /// Applies the child's turn and tilt.
  ///
  /// Assignment, never in-place mutation: editing the matrix a getter returns
  /// is a silent no-op in flutter_scene, which is the classic way to ship a
  /// rotation that reads back correctly and never moves.
  void setRotation(AvatarState pose) {
    avatarRoot.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      pose.yaw,
    ) * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), pose.pitchClamped);
  }

  /// Per-frame motion for [mood]: idle bob, sway, and mood tells.
  ///
  /// Pure transform math driven by elapsed time, with no widget rebuilds. The
  /// amplitudes are small on purpose — this runs every frame over the top of
  /// an already busy scene, so it has to cost almost nothing.
  void tick(Duration elapsed, AvatarMood mood) {
    final t = elapsed.inMicroseconds / 1e6;

    // Breathing bob. Slower and shallower when idle, faster when celebrating.
    final speed = mood == AvatarMood.success ? 7.0 : 2.2;
    final amplitude = mood == AvatarMood.success ? 0.022 : 0.010;
    var bob = math.sin(t * speed) * amplitude;

    // A disappointed slump, held until the child moves on.
    var slump = 0.0;
    if (mood == AvatarMood.wrong || mood == AvatarMood.retry) {
      bob *= 0.35;
      slump = -0.10;
    }

    // Success: a small celebratory hop plus raised arms.
    if (mood == AvatarMood.success) {
      bob += math.sin(t * speed).abs() * 0.055;
    }

    bodyRoot
      ..position = vm.Vector3(0, bob + 0.02, 0)
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), slump);

    // Arms: gentle idle sway, a raised pair on success, a low pair when the
    // answer was wrong.
    final sway = math.sin(t * 1.6) * 0.16;
    final armLift = switch (mood) {
      AvatarMood.success => -1.9,
      AvatarMood.wrong => 0.5,
      AvatarMood.retry => 0.2,
      AvatarMood.instruction => -0.35,
      AvatarMood.searching => 0.0,
    };
    final armSwing = mood == AvatarMood.success ? 0.35 : 0.0;
    _leftArm?.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 0, 1),
      armLift + sway,
    );
    _rightArm?.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 0, 1),
      armLift - sway,
    );
    if (armSwing > 0) {
      _leftArm?.position = vm.Vector3(-0.215, 0.03 + armSwing * 0.06, 0);
      _rightArm?.position = vm.Vector3(0.215, 0.03 + armSwing * 0.06, 0);
    }

    // The antenna tip bobs faster while talking, which is the companion's
    // visual "speaking" cue. The user chose visual-only communication, so this
    // and the visor are the entire voice.
    final talking = mood == AvatarMood.instruction || mood == AvatarMood.retry;
    final antennaRate = talking ? 9.0 : 1.5;
    final antennaSwing = talking ? 0.22 : 0.06;
    _antennaNode?.position = vm.Vector3(
      math.sin(t * antennaRate) * antennaSwing,
      0.66,
      0.02,
    );

    // Mood-tinted visor: the character's face. Kept as a colour swap on a
    // small emissive material so it reads at any angle and any size.
    _setVisorTint(mood);
  }

  void _setVisorTint(AvatarMood mood) {
    final material = _visorMaterial;
    if (material == null) return;
    final color = switch (mood) {
      AvatarMood.instruction => const Color(0xFF38BDF8),
      AvatarMood.searching => const Color(0xFF1E3A8A),
      AvatarMood.wrong => const Color(0xFF7C3AED),
      AvatarMood.retry => const Color(0xFF8B7CFF),
      AvatarMood.success => const Color(0xFFFBBF24),
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

  /// Shows the stand-in target on the companion's left, so the child can see
  /// what they are looking for without leaving the companion.
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

  /// Detaches the companion from its scene.
  ///
  /// Takes the [Scene] rather than reaching through [Node.parent], because
  /// detaching a subtree is a scene-level operation and this keeps the builder
  /// honest about who owns the graph.
  void detachFrom(Scene scene) {
    scene.remove(avatarRoot);
  }
}
