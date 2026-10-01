import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'avatar_exhaust_plume.dart';

/// Draws the thruster exhaust: the nodes, materials and blend modes that put
/// [ExhaustPlume]'s particles on screen.
///
/// The plume is four separate emitters rather than one because the four regions
/// of a rocket flame do not want the same treatment. Fire and sparks *add*
/// light, so overlapping puffs brighten each other into a hot core and the
/// order they draw in does not matter. Smoke *absorbs*, so it has to go through
/// the depth-sorted translucent pass or it would brighten the background behind
/// it instead of hiding it. The sparks are drawn stretched along their
/// direction of travel, which is the whole visual difference between a spark
/// and a dot of light.
///
/// Each layer sits on its own node so a spin of the rocket body cannot drag the
/// whole plume around with it, and so the throttle can reach each layer
/// independently.
class AvatarExhaust {
  AvatarExhaust({
    this.sprite,
    ExhaustPlume? simulation,
  }) {
    plume = simulation ?? ExhaustPlume();
    coreEmitter = _buildEmitter(
      plume.core,
      _additive(opacity: 1.0),
    );
    flameEmitter = _buildEmitter(
      plume.flame,
      _additive(opacity: 1.0),
    )
      // A horizontally mirrored puff reads as a different puff, so a batch of
      // them never looks like a repeating pattern.
      ..randomFlipX = true;
    smokeEmitter = _buildEmitter(
      plume.smoke,
      _alpha()
        // Dissolve through the rocket instead of cutting a hard intersection
        // edge where vapour passes the fins.
        ..softDepthFade = 0.12,
    )
      ..randomFlipX = true;
    emberEmitter = _buildEmitter(
      plume.embers,
      _additive(opacity: 1.0),
    )
      ..facing = BillboardFacing.velocityStretched
      ..velocityStretch = 0.055;

    _buildNozzleGlow();

    coreNode
      ..rotation = emitDown
      ..addComponent(coreEmitter);
    flameNode
      ..rotation = emitDown
      ..addComponent(flameEmitter);
    smokeNode
      ..rotation = emitDown
      ..addComponent(smokeEmitter);
    emberNode
      ..rotation = emitDown
      ..addComponent(emberEmitter);

    // Nothing in the plume is a drag target. The glow node matters most: it is
    // a camera-facing quad that swings across the engine as the rocket moves,
    // so leaving it pickable would make it swallow taps aimed at the rocket.
    for (final node in [coreNode, flameNode, smokeNode, emberNode, glowNode]) {
      node.raycastable = false;
      pivot.add(node);
    }
  }

  /// The soft-puff sprite every layer is drawn with, or `null` for the
  /// engine's 1x1 white placeholder while the sprite is still uploading.
  ///
  /// Injected rather than uploaded here so the scene layer owns GPU work and
  /// this stays constructible in a test.
  TextureSource? sprite;

  /// The plume's particle simulation.
  late final ExhaustPlume plume;

  /// Group node. Attach this to the rocket's body, not to its root, so the
  /// plume inherits hover and bank but not the drag yaw.
  final Node pivot = Node(name: 'avatar-exhaust-pivot');

  /// Hot inner throat.
  final Node coreNode = Node(name: 'exhaust-core');

  /// Bright cyan body of the flame.
  final Node flameNode = Node(name: 'exhaust-flame');

  /// Cool trailing vapour.
  final Node smokeNode = Node(name: 'exhaust-smoke');

  /// Sparks.
  final Node emberNode = Node(name: 'exhaust-embers');

  /// The soft glow covering the seam between the engine bell and the flame.
  final Node glowNode = Node(name: 'exhaust-glow');

  late final ParticleEmitterComponent coreEmitter;
  late final ParticleEmitterComponent flameEmitter;
  late final ParticleEmitterComponent smokeEmitter;
  late final ParticleEmitterComponent emberEmitter;

  /// The light the plume casts on the rocket.
  final PointLight _nozzleLight =
      PointLight(color: vm.Vector3(0.35, 0.78, 1.0), intensity: 0.0);

  /// The soft additive puff standing in for the nozzle flare.
  late final Sprite _throatGlow;

  /// The flare's resting size, in body units, before the throttle scales it.
  ///
  /// Taller than it is wide, because the glow has to be tall enough to cover
  /// the seam between the engine bell and the first puffs of flame.
  static const double _glowWidth = 0.23;

  static const double _glowHeight = 0.36;

  /// Where the plume leaves the rocket, in body space.
  ///
  /// Just below the engine bell, and the local origin every emitter spawns
  /// from, so a puff is never seen appearing out of nothing.
  static const double nozzleHeight = -0.26;

  /// The plume runs along the rocket's own `-Y`, so the emitters are turned to
  /// point down rather than up.
  static final vm.Quaternion emitDown =
      vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi);

  /// The plume's current throttle, `0` (idle) to `1` (full burn).
  double get throttle => plume.throttle;

  /// The light the plume is currently casting on the rocket.
  double get nozzleLightIntensity => plume.lightIntensity;

  ParticleEmitterComponent _buildEmitter(
    ParticleSystem system,
    SpriteMaterial material,
  ) =>
      ParticleEmitterComponent(system: system, material: material);

  void _buildNozzleGlow() {
    // A soft, camera-facing glow rather than cone geometry. A cone has a hard
    // silhouette, and lit from the front that silhouette *is* a solid white
    // triangle hanging off the engine; the puff sprite has no edge to catch
    // the eye, so the throat reads as light instead of as a shape. Additive
    // for the same reason the flame is additive: light adds, it does not cover.
    _throatGlow = Sprite(
      texture: sprite,
      width: _glowWidth,
      height: _glowHeight,
      facing: BillboardFacing.spherical,
      blendMode: SpriteBlendMode.additive,
    )..color = _glowColor;

    glowNode
      ..position = vm.Vector3(0, nozzleHeight + 0.01, 0)
      ..mesh = _throatGlow.mesh
      // The light sits at the throat, so the plume is what illuminates the
      // rocket's own white nosecone and engine bell.
      ..addComponent(PointLightComponent(_nozzleLight));
  }

  /// An additive copy of the sprite material, for fire and sparks.
  ///
  /// Additive is order independent, so overlapping puffs brighten each other
  /// without needing depth sorting. That stacking is what gives the plume its
  /// hot core.
  SpriteMaterial _additive({required double opacity}) {
    return SpriteMaterial()
      ..colorTexture = sprite
      ..blendMode = SpriteBlendMode.additive
      ..tint = vm.Vector4(1.0, 1.0, 1.0, opacity);
  }

  /// An alpha-blended copy of the sprite material, for smoke.
  ///
  /// Additive smoke would brighten the background and read as more glow, not
  /// as more vapour.
  SpriteMaterial _alpha() {
    return SpriteMaterial()
      ..colorTexture = sprite
      ..blendMode = SpriteBlendMode.alpha
      ..tint = vm.Vector4(1.0, 1.0, 1.0, 1.0);
  }

  /// The glow's linear RGBA: hot near-white in the throat, cooling and fading
  /// as the engine closes down.
  vm.Vector4 get _glowColor => vm.Vector4(
        0.78 + 0.22 * plume.glowHeat,
        0.92,
        1.0,
        0.55 + 0.60 * plume.glowHeat,
      );

  /// Applies the plume's throttle to everything that has to follow it: the
  /// emission rates the simulation uses, the throat light, and the size and
  /// brightness of the nozzle flare.
  ///
  /// Does not step the particles: the emitter components do that from the
  /// engine's own frame delta.
  void applyThrottle() {
    _nozzleLight.intensity = plume.lightIntensity;
    _throatGlow
      ..width = _glowWidth * plume.glowSpread
      // The flare is held a little shorter than it is wide at idle, so the
      // throat does not read as a ball of light on a shut-down engine.
      ..height = _glowHeight * (0.60 + 0.40 * plume.glowHeat)
      ..color = _glowColor;
  }
}
