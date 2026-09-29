import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../application/state/avatar_state.dart';
import '../../application/state/explorer_state.dart';
import 'avatar_geometry.dart';
import 'avatar_materials.dart';
import 'avatar_scene_builder.dart';

/// Facade over the companion's 3D stack (ISP: one narrow surface for widgets).
abstract class AvatarSceneController {
  Scene get scene;
  bool get isReady;
  bool get isRealScene;

  void ensureBuilt();
  void tick(Duration elapsed, AvatarMood mood, AvatarIdleAction idleAction, String? selectedPlanetId);
  void applyPose(AvatarState pose);
  void applyReaction(AvatarReaction reaction);
  void showTarget({required bool visible, required Color color});
  void dispose();
}

/// Owns the companion's own [Scene] and drives it from the avatar state.
class AvatarSceneControllerImpl implements AvatarSceneController {
  AvatarSceneControllerImpl()
      : _scene = Scene(),
        _geometries = AvatarGeometryFactory(),
        _materials = AvatarMaterialFactory() {
    _builder = AvatarSceneBuilder(
      geometries: _geometries,
      materials: _materials,
    );
  }

  final Scene _scene;
  final AvatarGeometryFactory _geometries;
  final AvatarMaterialFactory _materials;
  late final AvatarSceneBuilder _builder;

  bool _built = false;

  @override
  Scene get scene => _scene;

  @override
  bool get isReady => _built;

  @override
  bool get isRealScene => true;

  static final PerspectiveCamera camera = PerspectiveCamera(
    fovRadiansY: 0.62,
    position: vm.Vector3(0, 0.02, -1.75),
    target: vm.Vector3(0, 0.02, 0),
  );

  @override
  void ensureBuilt() {
    if (_built) return;
    _built = true;
    _builder.build(_scene);
  }

  @override
  void tick(Duration elapsed, AvatarMood mood, AvatarIdleAction idleAction, String? selectedPlanetId) =>
      _builder.tick(elapsed, mood, idleAction, selectedPlanetId);

  @override
  void applyPose(AvatarState pose) => _builder.setRotation(pose);

  @override
  void applyReaction(AvatarReaction reaction) => _builder.setReaction(reaction);

  @override
  void showTarget({required bool visible, required Color color}) =>
      _builder.showTarget(visible: visible, color: color);

  @override
  void dispose() {
    _builder.detachFrom(_scene);
    _geometries.dispose();
  }
}
