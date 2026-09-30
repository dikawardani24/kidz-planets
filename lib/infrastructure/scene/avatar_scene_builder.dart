import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../application/state/avatar_squash.dart';
import '../../application/state/avatar_state.dart';
import '../../application/state/explorer_state.dart';
import 'avatar_exhaust.dart';
import 'avatar_exhaust_plume.dart';
import 'avatar_exhaust_texture.dart';
import 'avatar_face_projection.dart';
import 'avatar_geometry.dart';
import 'avatar_materials.dart';

/// Builds and owns the Chubby Cartoon Rocket Ship Mascot graph.
///
/// A delightful, adorable miniature rocket ship with a glossy red body,
/// crisp white nosecone, glowing porthole window, sunny yellow fins,
/// and dynamic planetary reactions.
class AvatarSceneBuilder {
  AvatarSceneBuilder({required this.geometries, required this.materials});

  final AvatarGeometryFactory geometries;
  final AvatarMaterialFactory materials;

  final Node avatarRoot = Node(name: 'avatar-root');
  final Node bodyRoot = Node(name: 'avatar-body');
  final Node targetPivot = Node(name: 'avatar-target');
  final Node exhaustGroupNode = Node(name: 'avatar-exhaust');

  /// The layered particle plume, attached once the engine's shader library
  /// can supply the sprite materials it needs.
  AvatarExhaust? _exhaust;

  /// Set while that attach is in flight, so a burst of rebuilds cannot queue
  /// several plumes onto the same node.
  bool _exhaustPending = false;

  /// The plume's current throttle, `0` to `1`.
  ///
  /// Latched from [setRotation] (which knows the flight speed) and consumed by
  /// [tick] (which is what actually steps the particles), because the two are
  /// called from different places in the frame.
  double _requestedThrottle = ExhaustPlume.idleThrottle;

  /// Elapsed seconds as of the previous [tick], used to derive the frame delta
  /// the plume steps by. Null before the first tick, when there is no previous
  /// frame to measure from.
  double? _lastTickSeconds;

  UnlitMaterial? _portholeMaterial;

  /// The reaction currently being played, and when it started.
  ///
  /// Reactions animate as transforms of the parts the rocket already has. New
  /// meshes for eyes and a mouth are deliberately *not* added here: that is
  /// what blanked the scene once already, and a missing face must never be able
  /// to take the Explorer down with it. The readable cartoon face is drawn over
  /// the window by the widget layer instead.
  AvatarReaction _reaction = AvatarReaction.none;
  double? _reactionStartedAt;

  /// The body pose as of the last [tick], reported to the 2D face so it lands
  /// on the window and not beside it.
  double _hover = 0;
  double _tilt = 0;
  double _spin = 0;

  /// Where the rocket body is on the current frame.
  AvatarBodyMotion get bodyMotion =>
      AvatarBodyMotion(hover: _hover, tilt: _tilt, spin: _spin);

  void build(Scene scene) {
    scene
      ..environmentIntensity = 0.60
      ..add(
        Node(name: 'avatar:light')..addComponent(
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

    // Side fins / wings
    bodyRoot.add(
      _mesh('fin-left', geometries.fin(), finMat)
        ..position = vm.Vector3(-0.16, -0.10, 0),
    );
    bodyRoot.add(
      _mesh('fin-right', geometries.fin(), finMat)
        ..position = vm.Vector3(0.16, -0.10, 0),
    );

    // Engine bell at the base.
    bodyRoot.add(
      _mesh('engine', geometries.engineNozzle(), whiteMat)
        ..position = vm.Vector3(0, -0.22, 0),
    );

    // The plume hangs off the bell. It is attached asynchronously, because
    // the sprite materials it needs cannot be constructed until the engine's
    // shader library has finished loading, so the group node is parented
    // immediately and filled in as soon as that is safe.
    exhaustGroupNode.position = vm.Vector3(0, AvatarExhaust.nozzleHeight, 0);
    bodyRoot.add(exhaustGroupNode);

    unawaited(_attachExhaust());
  }

  /// Builds the particle plume once the renderer can supply its materials.
  ///
  /// [SpriteMaterial] pulls its shader out of the engine's base shader bundle
  /// in its constructor, unlike every other material in the scene, which
  /// resolves its shader by name on first draw. That makes the plume the one
  /// part of the rocket that cannot be built in the same breath as the body:
  /// `Scene()` starts loading the bundle without waiting for it, so a plume
  /// built on the first frame throws and takes the companion down with it.
  ///
  /// Waiting on the same memoized load the renderer is already doing costs
  /// nothing and removes the ordering trap. A pending build is remembered so a
  /// burst of rebuilds cannot queue several plumes onto the same node, and a
  /// failure is reported rather than thrown, because a missing plume is a
  /// cosmetic loss and must not be able to blank the whole scene.
  Future<void> _attachExhaust() async {
    if (_exhaust != null || _exhaustPending) return;
    _exhaustPending = true;
    try {
      await Scene.initializeStaticResources();
      if (exhaustGroupNode.parent == null) return;

      final sprite = ExhaustSpriteFactory.build();
      final exhaust = AvatarExhaust(sprite: sprite);
      exhaustGroupNode.add(exhaust.pivot);
      _exhaust = exhaust;
    } catch (error, stackTrace) {
      debugPrint(
        'AvatarSceneBuilder: exhaust unavailable, continuing without '
        'it: $error\n$stackTrace',
      );
    } finally {
      _exhaustPending = false;
    }
  }

  void _buildTarget() {
    targetPivot.visible = false;
  }

  Node _mesh(String name, MeshGeometry geometry, Material material) {
    final node = Node(mesh: Mesh(geometry, material))..name = name;
    node.raycastable = false;
    return node;
  }

  /// Deforms the whole body for the moment after an impact.
  ///
  /// Written straight onto the root rather than animated here, because the
  /// caller already has a clock for the impact, and a second one would mean two
  /// animations of the same thing a frame apart.
  void setImpactSquash(double scale) {
    if (scale == 1.0) {
      avatarRoot.scale = vm.Vector3.all(1.0);
      return;
    }
    final axes = AvatarSquash.axes(scale);
    avatarRoot.scale = vm.Vector3(axes.dx, axes.dy, axes.dx);
  }

  void setRotation(AvatarState pose) {
    avatarRoot.rotation =
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), pose.yaw) *
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), pose.pitchClamped);

    _requestedThrottle = ExhaustPlume.throttleForSpeed(pose.velocity.distance);
  }

  /// Starts (or ends) a reaction pose.
  ///
  /// The start time is cleared rather than set, so the next [tick] arms the
  /// reaction clock at zero. Every reaction then begins from its neutral pose
  /// and eases in: without that, starting a wobble mid-swing would snap the
  /// rocket by up to the wobble's whole amplitude.
  void setReaction(AvatarReaction reaction) {
    if (reaction == _reaction) return;
    _reaction = reaction;
    _reactionStartedAt = null;
  }

  /// How long a reaction takes to fade in, in seconds.
  static const double _reactionFadeIn = 0.32;

  /// Smoothstep, so a reaction arrives and leaves without a visible corner.
  static double _ease(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  void tick(
    Duration elapsed,
    AvatarMood mood,
    AvatarIdleAction idleAction,
    String? selectedPlanetId,
  ) {
    final t = elapsed.inMicroseconds / 1e6;

    // Reaction-local clock: zero on the first tick after setReaction, so every
    // reaction animation starts from its neutral pose.
    var reactionTime = 0.0;
    if (_reaction != AvatarReaction.none) {
      _reactionStartedAt ??= t;
      reactionTime = t - _reactionStartedAt!;
    }
    final ramp = _ease(reactionTime / _reactionFadeIn);

    double hover = 0.0;
    double tilt = 0.0;

    final isIceWorld =
        selectedPlanetId == 'neptune' ||
        selectedPlanetId == 'uranus' ||
        selectedPlanetId == 'pluto';
    final isHotWorld =
        selectedPlanetId == 'sun' ||
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

    // Reaction motion, all of it transforms of existing parts and all of it
    // scaled by `ramp`, so a reaction grows in instead of appearing.
    var spin = 0.0;
    switch (_reaction) {
      case AvatarReaction.happy:
        // Energetic bounce with a happy little body wiggle.
        hover += ramp * math.sin(reactionTime * 14.0).abs() * 0.035;
        tilt += ramp * math.sin(reactionTime * 10.0) * 0.12;
      case AvatarReaction.surprised:
        // A quick jump straight up and a lean back, as if startled.
        hover += ramp * 0.045;
        tilt -= ramp * 0.22;
        spin += ramp * math.sin(reactionTime * 6.0) * 0.12;
      case AvatarReaction.sad:
        // Droops, tilts down and holds still: the reduced energy is in the
        // flight speed, which the policy slows down for this reaction.
        hover -= ramp * 0.055;
        tilt -= ramp * 0.12;
        spin += ramp * math.sin(reactionTime * 2.0) * 0.03;
      case AvatarReaction.dizzy:
        // Wobbles and pirouettes: the spin keeps accumulating, so a double tap
        // reads as the companion being spun around rather than nudged.
        tilt += ramp * math.sin(reactionTime * 18.0) * 0.35;
        spin += ramp * reactionTime * 6.0;
      case AvatarReaction.excited:
        hover += ramp * math.sin(reactionTime * 16.0).abs() * 0.055;
        tilt += ramp * math.sin(reactionTime * 12.0) * 0.18;
        spin += ramp * math.sin(reactionTime * 8.0) * 0.25;
      case AvatarReaction.sleepy:
        // Slow, heavy float that barely moves.
        hover -= ramp * 0.03 + ramp * math.sin(reactionTime * 1.2) * 0.008;
        tilt -= ramp * 0.14;
      case AvatarReaction.laughing:
        // A run of small, fast bounces.
        hover += ramp * math.sin(reactionTime * 22.0).abs() * 0.03;
        tilt += ramp * math.sin(reactionTime * 16.0) * 0.08;
      case AvatarReaction.talking:
        // Head bobbing: subtle, because it plays under mission instructions.
        hover += ramp * math.sin(reactionTime * 9.0) * 0.012;
        tilt += ramp * math.sin(reactionTime * 7.0) * 0.05;
      case AvatarReaction.none:
        break;
    }

    bodyRoot
      ..position = vm.Vector3(0, hover, 0)
      ..rotation =
          vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), tilt) *
          vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), spin);

    // The plume steps on its own delta, derived from the elapsed time rather
    // than read from a frame callback, so a rebuild that skips a frame does
    // not hand the particles a zero-length step.
    final dt = _lastTickSeconds == null
        ? 0.0
        : (t - _lastTickSeconds!).clamp(0.0, 0.1).toDouble();
    _lastTickSeconds = t;

    // A sleeping rocket is not under power; every other reaction keeps the
    // engine running, because a startle is not a shutdown.
    final target = _reaction == AvatarReaction.sleepy
        ? 0.12
        : _requestedThrottle;
    final exhaust = _exhaust;
    if (exhaust != null) {
      exhaust.plume
        ..setThrottle(target)
        ..tick(dt, flickerPhase: t);
      exhaust.applyThrottle();
    }

    _hover = hover;
    _tilt = tilt;
    _spin = spin;

    _setPortholeColor(mood, idleAction, selectedPlanetId);
  }

  void _setPortholeColor(
    AvatarMood mood,
    AvatarIdleAction idleAction,
    String? selectedPlanetId,
  ) {
    final material = _portholeMaterial;
    if (material == null) return;
    final color = switch (_reaction) {
      // A reaction overrides the ambient tint for as long as it plays, so the
      // window reads as the companion's mood rather than as the planet's.
      AvatarReaction.happy ||
      AvatarReaction.laughing => const Color(0xFFFF7EB6),
      AvatarReaction.excited => const Color(0xFFFFC93C),
      AvatarReaction.surprised => const Color(0xFFEAF6FF),
      AvatarReaction.sad => const Color(0xFF4C63C8),
      AvatarReaction.dizzy => const Color(0xFFB388FF),
      AvatarReaction.sleepy => const Color(0xFF3F4E92),
      AvatarReaction.talking => const Color(0xFF7DD3FC),
      AvatarReaction.none => switch (selectedPlanetId) {
        'neptune' || 'uranus' || 'pluto' => const Color(0xFF38BDF8),
        'sun' || 'mercury' || 'venus' => const Color(0xFFFBBF24),
        _ => switch (idleAction) {
          AvatarIdleAction.dancing => const Color(0xFF38BDF8),
          AvatarIdleAction.thinking => const Color(0xFF8B5CF6),
          AvatarIdleAction.sitting => const Color(0xFF64748B),
          AvatarIdleAction.flying => const Color(0xFF06B6D4),
          AvatarIdleAction.sendingHeart => const Color(0xFFEC4899),
          AvatarIdleAction.none => const Color(0xFF06B6D4),
        },
      },
    };
    material.baseColorFactor = vm.Vector4(
      color.r.toDouble(),
      color.g.toDouble(),
      color.b.toDouble(),
      1.0,
    );
  }

  void showTarget({required bool visible, required Color color}) {
    targetPivot.visible = false;
  }

  void detachFrom(Scene scene) {
    scene.remove(avatarRoot);
  }
}
