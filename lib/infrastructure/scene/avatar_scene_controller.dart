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

  /// Whether [scene] is a real GPU-backed scene.
  ///
  /// A `Scene` cannot be constructed without a GPU with Impeller, so widget
  /// tests inject a stand-in controller. The body checks this to draw nothing
  /// instead of asking for a scene that does not exist; everything else in the
  /// overlay works identically either way.
  bool get isRealScene;

  /// Builds the scene graph. Idempotent, so the widget can call it from a
  /// post-frame callback without having to track whether it already ran.
  void ensureBuilt();
  void tick(Duration elapsed, AvatarMood mood);
  void applyPose(AvatarState pose);
  void showTarget({required bool visible, required Color color});
  void dispose();
}

/// Owns the companion's own [Scene] and drives it from the avatar state.
///
/// This is a separate scene from the solar system, and deliberately so: the
/// companion needs its own camera, its own light, and a transparent background
/// so it can sit on top of the planets as an overlay. Folding it into the
/// solar system scene would tie the companion's position to the orbit camera
/// and make "move" and "rotate" fight each other.
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

  /// Fixed camera framing the character.
  ///
  /// It never moves. All turning is done on the model, which is what makes the
  /// companion's rotation independent of where it sits on screen and stops the
  /// camera swinging when a child spins the character.
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
  void tick(Duration elapsed, AvatarMood mood) => _builder.tick(elapsed, mood);

  @override
  void applyPose(AvatarState pose) => _builder.setRotation(pose);

  @override
  void showTarget({required bool visible, required Color color}) =>
      _builder.showTarget(visible: visible, color: color);

  @override
  void dispose() {
    _builder.detachFrom(_scene);
    _geometries.dispose();
  }
}
