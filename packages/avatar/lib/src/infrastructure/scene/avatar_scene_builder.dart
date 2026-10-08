import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:avatar/state.dart';

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

  /// Scale the imported body is built at.
  ///
  /// Read through here rather than off [AvatarBodyScale] at the call site so a
  /// test can pin the one number the rest of the companion's layout is measured
  /// against without having to load the model to look at it.
  double get bodyScale => _type == AvatarType.astronaut
      ? AvatarBodyScale.astronaut
      : AvatarBodyScale.rocket;

  /// Which body is currently worn.
  ///
  /// Set before [build] for the opening body and through [setAvatarType] for
  /// every later switch. Only the model node, its scale and the rocket-only
  /// attachments depend on it: pose, physics, reactions and sound are all
  /// model-agnostic.
  AvatarType _type = AvatarType.rocket;

  /// The layered particle plume, attached once the engine's shader library
  /// can supply the sprite materials it needs.
  AvatarExhaust? _exhaust;

  /// Imported GLB body. The procedural model remains as a safe fallback if
  /// the bundled asset cannot be loaded on a device/build.
  Node? _importedBody;
  bool _bodyLoadPending = false;

  /// Guards overlapping switches: a slow load that finishes after a newer
  /// switch started must not put the stale body back on screen.
  int _loadToken = 0;

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
    // The bundled GLB is now the avatar's primary and only body model.
    // Keep the face window and exhaust as lightweight scene overlays so the
    // existing reactions, physics, and 2D expressions continue to work.
    //
    // The plume anchors to the model's engine nozzle, which sits at the bottom
    // of the body, so it moves down with [AvatarBodyScale.growth]: scaling the
    // rocket without this would leave the exhaust hanging in the air below it.
    exhaustGroupNode.position = vm.Vector3(
      0,
      -0.20 * AvatarBodyScale.growth,
      0,
    );
    bodyRoot.add(exhaustGroupNode);
    _updateExhaustVisibility();
    unawaited(_attachImportedBody());
    unawaited(_attachExhaust());
  }

  /// Switches the worn body, loading the new model before the old one leaves.
  ///
  /// The swap is staged so the companion never pops to an empty viewport: the
  /// previous body stays visible until its replacement is ready, and a load
  /// failure keeps it indefinitely rather than stranding the child with no
  /// companion. Safe to call before [build]; the choice is then simply
  /// recorded and loaded when the body root arrives.
  Future<void> setAvatarType(AvatarType type) async {
    if (type == _type && _importedBody != null) return;
    _type = type;
    // Before build the body root is not in the scene yet and there is nothing
    // to swap: _buildBody loads the recorded type when it arrives. Loading
    // here as well would race it — a fast load that finishes first would be
    // discarded as detached, and the build's own attach already returned on
    // the pending flag, leaving no body at all.
    if (bodyRoot.parent == null && _importedBody == null) return;
    await _attachImportedBody();
  }

  /// Rocket-only attachments follow the body: the exhaust plume belongs to
  /// an engine the astronaut does not have, and the painted face belongs to
  /// the rocket's window.
  void _updateExhaustVisibility() {
    exhaustGroupNode.visible = _type == AvatarType.rocket;
  }

  /// Loads and normalizes the bundled body model for the current [_type].
  ///
  /// Kenney's source asset is authored inside a kit coordinate space, so its
  /// scene root is translated back to the avatar origin and scaled to match
  /// the existing companion viewport. The per-type scale owns that size:
  /// it is also what [AvatarPorthole.height] and the exhaust anchor are measured
  /// against, so the painted face stays on the window of whatever size the body
  /// is drawn at.
  Future<void> _attachImportedBody() async {
    if (_bodyLoadPending) return;
    _bodyLoadPending = true;
    final token = ++_loadToken;
    try {
      await Scene.initializeStaticResources();
      final body = await loadScene(_type.assetPath);
      // A newer switch started while this one was in flight: drop the stale
      // body rather than flashing it for a frame.
      if (token != _loadToken) return;
      if (avatarRoot.parent == null) return;

      body
        ..name = 'avatar-glb-body'
        ..raycastable = false
        // rocket_baseA.glb is authored at (2, 0, 1.5) in the Kenney kit.
        // Center it around the same origin used by the old avatar; the size is
        // the per-type body scale.
        ..position = vm.Vector3.zero()
        ..scale = vm.Vector3.all(bodyScale);
      final previous = _importedBody;
      bodyRoot.add(body);
      _importedBody = body;
      if (previous != null && previous.parent != null) {
        previous.parent!.remove(previous);
      }
      _updateExhaustVisibility();
    } catch (error, stackTrace) {
      debugPrint(
        'AvatarSceneBuilder: imported body unavailable; keeping previous '
        'body: $error\\n$stackTrace',
      );
    } finally {
      _bodyLoadPending = false;
    }
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

  /// The pose the companion holds while it is simply being itself: a hover,
  /// and never a lean.
  ///
  /// The rocket is a friend standing next to the child, not an aeroplane, so
  /// every resting pose keeps its longitudinal axis vertical. That matters
  /// most for [AvatarIdleAction.flying], which is what the companion spends
  /// almost all of its time in: it used to bank 0.35 rad into every circuit,
  /// which parked the toy permanently leaning to one side, and selecting a hot
  /// planet left it leaning 0.15 rad even while idle. Yaw and pitch still come
  /// from a throw and are recovered to zero by the controller; nothing here is
  /// allowed to reintroduce a resting lean on top of that.
  ///
  /// [AvatarIdleAction.dancing] is the one exception, and it is deliberate: the
  /// wobble is the dance, and it is symmetric about vertical, so the rocket
  /// still passes through straight rather than resting off-plumb.
  @visibleForTesting
  static ({double hover, double tilt}) idlePose({
    required double t,
    required AvatarIdleAction idleAction,
    required String? selectedPlanetId,
  }) {
    final isIceWorld = const {
      'neptune',
      'uranus',
      'pluto',
    }.contains(selectedPlanetId);
    final isHotWorld = const {
      'sun',
      'mercury',
      'venus',
    }.contains(selectedPlanetId);

    if (isIceWorld) {
      // A shiver you can see in the hover, not a lean.
      return (hover: math.sin(t * 30.0) * 0.008, tilt: 0);
    }
    if (isHotWorld) {
      return (hover: math.sin(t * 8.0) * 0.03, tilt: 0);
    }
    switch (idleAction) {
      case AvatarIdleAction.dancing:
        return (
          hover: math.sin(t * 9.0).abs() * 0.07,
          tilt: math.sin(t * 6.0) * 0.3,
        );
      case AvatarIdleAction.thinking:
        return (hover: math.sin(t * 2.0) * 0.01, tilt: 0);
      case AvatarIdleAction.sitting:
        return (hover: -0.12, tilt: 0);
      case AvatarIdleAction.flying:
        return (hover: math.sin(t * 6.0) * 0.04, tilt: 0);
      case AvatarIdleAction.none:
      case AvatarIdleAction.sendingHeart:
        return (hover: math.sin(t * 3.0) * 0.02, tilt: 0);
    }
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

    // Resting pose: a hover, and never a lean. Reactions below are the only
    // thing allowed to tip the rocket over.
    final idle = idlePose(
      t: t,
      idleAction: idleAction,
      selectedPlanetId: selectedPlanetId,
    );
    var hover = idle.hover;
    var tilt = idle.tilt;

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
      case AvatarReaction.confused:
        // The asking wobble: a small side-to-side tilt that stalls and
        // settles, so it reads as a question rather than a spin.
        tilt += ramp * math.sin(reactionTime * 7.0) * 0.14;
        spin += ramp * math.sin(reactionTime * 3.5) * 0.10;
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
    // A hidden plume is not stepped: the astronaut has no engine, so its
    // particles would burn CPU for pixels that are never drawn.
    if (exhaust != null && exhaustGroupNode.visible) {
      exhaust.plume
        ..setThrottle(target)
        ..tick(dt, flickerPhase: t);
      exhaust.applyThrottle();
    }

    _hover = hover;
    _tilt = tilt;
    _spin = spin;
  }

  void showTarget({required bool visible, required Color color}) {
    targetPivot.visible = false;
  }

  void detachFrom(Scene scene) {
    scene.remove(avatarRoot);
  }
}
