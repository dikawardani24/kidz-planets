import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// The simulation behind the rocket's thruster exhaust, with no scene graph and
/// no materials in it.
///
/// The previous plume was two nested capsule meshes scaled by a sine wave,
/// which reads as a translucent pill no matter how it is animated: hard
/// silhouette, no internal motion, no smoke, and it burned identically while
/// the rocket was flying and while it sat parked.
///
/// A real rocket plume has four distinct regions, and this reproduces them as
/// four independent systems so each can move on its own terms:
///
/// * **core** - the white-hot throat, tiny, fast, short-lived.
/// * **flame** - the bright cyan body, turbulent, the main visual mass.
/// * **smoke** - cool vapour that lingers, expands and fades, alpha blended so
///   it absorbs what is behind it rather than glowing.
/// * **embers** - sparks flung out on stretched billboards.
///
/// Only the simulation lives here; the nodes, materials and blend modes that
/// draw it are [AvatarExhaust]'s job. Keeping them apart means the throttle,
/// the emission curves and the particle behaviour are plain Dart that can be
/// reasoned about and tested without a GPU.
class ExhaustPlume {
  ExhaustPlume({this.seed = 1337}) {
    _buildCore();
    _buildFlame();
    _buildSmoke();
    _buildEmbers();
  }

  /// Seed for every system's spawn randomness, so a plume is reproducible.
  final int seed;

  /// The white-hot throat.
  late final ParticleSystem core;

  /// The bright cyan body of the flame.
  late final ParticleSystem flame;

  /// Cool trailing vapour.
  late final ParticleSystem smoke;

  /// Flung sparks.
  late final ParticleSystem embers;

  /// Every layer, in draw order.
  List<ParticleSystem> get systems => [core, flame, smoke, embers];

  /// Emission and speed multiplier, smoothed toward the requested throttle.
  double _throttle = 0.55;
  double _throttleTarget = 0.55;

  /// How fast the throttle chases its target, per second.
  ///
  /// A rocket does not open its throttle instantly, and the lag is most of
  /// what makes a change in burn read as thrust rather than as a fade.
  static const double _throttleResponse = 5.5;

  /// The current throttle, `0` (idle) to `1` (full burn).
  double get throttle => _throttle;

  /// Requests a throttle level. [tick] eases toward it rather than snapping.
  void setThrottle(double value) {
    _throttleTarget = value.clamp(0.0, 1.0);
  }

  /// The throttle a parked rocket holds.
  ///
  /// A floor, not zero: a dark engine reads as broken rather than as idle.
  static const double idleThrottle = 0.36;

  /// How hard the engine should be burning, for a given flight speed in
  /// logical pixels per seconds.
  ///
  /// A rocket under thrust makes more thrust, so the plume is driven by how
  /// fast the companion is actually travelling rather than being a constant
  /// decoration.
  static double throttleForSpeed(double speed) {
    const idle = idleThrottle;
    // Saturates around a brisk throw, so a fast fling cannot blow the plume
    // out of the companion's box.
    const fullThrustSpeed = 900.0;
    final boost = (speed / fullThrustSpeed).clamp(0.0, 1.0);
    return idle + (1.0 - idle) * boost;
  }

  void _buildCore() {
    core = ParticleSystem(
      maxParticles: 130,
      shape: const ConeEmitterShape(angle: 0.24, radius: 0.024),
      spawner: Spawner(rate: 150),
      lifetime: const UniformFloat(0.12, 0.24),
      // Fast and short: the core is a bright nozzle wash, not a trail.
      startSpeed: const UniformFloat(0.9, 1.5),
      startSize: const UniformFloat(0.06, 0.11),
      startRotation: const UniformFloat(0.0, math.pi * 2.0),
      startColor: GradientColor(
        ColorGradient([
          ColorStop(0.0, vm.Vector4(1.0, 1.0, 1.0, 1.0)),
          ColorStop(0.45, vm.Vector4(0.88, 0.98, 1.0, 1.0)),
          ColorStop(1.0, vm.Vector4(0.40, 0.85, 1.0, 0.0)),
        ]),
      ),
      modules: [
        // Shrinks as it fades, so the throat tapers instead of ending flat.
        SizeOverLifeModule(
          CurveFloat(
            ParticleCurve([
              ParticleKeyframe(0.0, 1.0),
              ParticleKeyframe(1.0, 0.35),
            ]),
          ),
        ),
        ColorOverLifeModule(
          GradientColor(
            ColorGradient([
              ColorStop(0.0, vm.Vector4(1.0, 1.0, 1.0, 1.0)),
              ColorStop(0.5, vm.Vector4(0.80, 0.97, 1.0, 1.0)),
              ColorStop(1.0, vm.Vector4(0.25, 0.70, 1.0, 0.0)),
            ]),
          ),
        ),
        LinearDragModule(2.4),
      ],
      seed: seed,
    );
  }

  void _buildFlame() {
    flame = ParticleSystem(
      maxParticles: 320,
      // A wider cone than the core: the flame spreads as it leaves the throat.
      shape: const ConeEmitterShape(angle: 0.50, radius: 0.05),
      spawner: Spawner(rate: 90),
      lifetime: const UniformFloat(0.30, 0.54),
      startSpeed: const UniformFloat(0.55, 1.05),
      startSize: const UniformFloat(0.13, 0.25),
      // Visible variation between puffs that were born on the same frame.
      startRotation: const UniformFloat(0.0, math.pi * 2.0),
      startAngularVelocity: const UniformFloat(-1.5, 1.5),
      startColor: GradientColor(
        ColorGradient([
          ColorStop(0.0, vm.Vector4(0.75, 0.98, 1.0, 1.0)),
          ColorStop(1.0, vm.Vector4(0.10, 0.45, 1.0, 0.0)),
        ]),
      ),
      modules: [
        // Grows as it fades: fire expands as it mixes with the air around it.
        SizeOverLifeModule(
          CurveFloat(
            ParticleCurve([
              ParticleKeyframe(0.0, 0.60),
              ParticleKeyframe(0.45, 1.30),
              ParticleKeyframe(1.0, 2.00),
            ]),
          ),
        ),
        ColorOverLifeModule(
          GradientColor(
            ColorGradient([
              // Additive blending means a puff's alpha *is* how much light it
              // contributes, so these run high right through the middle of life.
              // Holding most of the flame near full alpha until 70% of its life is
              // what makes the plume read as a solid body of fire rather than as a
              // wash of pale smoke that happens to be blue.
              ColorStop(0.0, vm.Vector4(0.85, 0.99, 1.0, 1.0)),
              ColorStop(0.45, vm.Vector4(0.38, 0.88, 1.0, 0.90)),
              ColorStop(0.75, vm.Vector4(0.14, 0.58, 1.0, 0.45)),
              ColorStop(1.0, vm.Vector4(0.06, 0.28, 0.85, 0.0)),
            ]),
          ),
        ),
        // Curl noise is what separates fire from a smooth gradient: it gives
        // the licking, rolling edge a real flame always has.
        TurbulenceModule(
          strength: 1.8,
          frequency: 11.0,
          // Scrolling the field downstream makes the flame stream away from
          // the nozzle instead of just churning in place.
          scroll: vm.Vector3(0.0, 2.2, 0.0),
          seed: seed + 1,
        ),
        LinearDragModule(1.25),
        const RotationModule(),
      ],
      seed: seed + 2,
    );
  }

  void _buildSmoke() {
    smoke = ParticleSystem(
      maxParticles: 200,
      // A hemisphere rather than a cone: vapour fills the space behind the
      // rocket instead of staying in a neat cone.
      shape: const SphereEmitterShape(radius: 0.05, hemisphere: true),
      spawner: Spawner(rate: 26),
      // Long-lived, which is the whole point of smoke: it hangs around after
      // the flame has gone.
      lifetime: const UniformFloat(0.8, 1.5),
      startSpeed: const UniformFloat(0.14, 0.34),
      startSize: const UniformFloat(0.13, 0.22),
      startRotation: const UniformFloat(0.0, math.pi * 2.0),
      startAngularVelocity: const UniformFloat(-0.8, 0.8),
      startColor: GradientColor(
        ColorGradient([
          ColorStop(0.0, vm.Vector4(0.80, 0.90, 1.0, 0.42)),
          ColorStop(1.0, vm.Vector4(0.45, 0.60, 0.85, 0.0)),
        ]),
      ),
      modules: [
        SizeOverLifeModule(
          CurveFloat(
            ParticleCurve([
              ParticleKeyframe(0.0, 0.8),
              ParticleKeyframe(1.0, 2.6),
            ]),
          ),
        ),
        ColorOverLifeModule(
          GradientColor(
            ColorGradient([
              ColorStop(0.0, vm.Vector4(0.82, 0.92, 1.0, 0.46)),
              ColorStop(0.4, vm.Vector4(0.62, 0.74, 0.92, 0.30)),
              ColorStop(1.0, vm.Vector4(0.40, 0.52, 0.80, 0.0)),
            ]),
          ),
        ),
        TurbulenceModule(
          strength: 0.9,
          frequency: 5.0,
          scroll: vm.Vector3(0.0, 0.8, 0.0),
          seed: seed + 3,
        ),
        // Strong drag, so smoke loses the rocket's push almost immediately and
        // then drifts rather than trailing like a rigid tail.
        LinearDragModule(3.2),
        const RotationModule(),
      ],
      seed: seed + 4,
    );
  }

  void _buildEmbers() {
    embers = ParticleSystem(
      maxParticles: 96,
      // A wide cone: sparks scatter, they do not follow the flame's axis.
      shape: const ConeEmitterShape(angle: 0.85, radius: 0.03),
      spawner: Spawner(rate: 22),
      lifetime: const UniformFloat(0.22, 0.55),
      startSpeed: const UniformFloat(1.1, 2.2),
      startSize: const UniformFloat(0.016, 0.042),
      startColor: GradientColor(
        ColorGradient([
          ColorStop(0.0, vm.Vector4(1.0, 0.98, 0.85, 1.0)),
          ColorStop(0.5, vm.Vector4(0.75, 0.95, 1.0, 0.8)),
          ColorStop(1.0, vm.Vector4(0.20, 0.55, 1.0, 0.0)),
        ]),
      ),
      modules: [
        SizeOverLifeModule(
          CurveFloat(
            ParticleCurve([
              ParticleKeyframe(0.0, 1.0),
              ParticleKeyframe(1.0, 0.2),
            ]),
          ),
        ),
        ColorOverLifeModule(
          GradientColor(
            ColorGradient([
              ColorStop(0.0, vm.Vector4(1.0, 0.97, 0.80, 1.0)),
              ColorStop(0.6, vm.Vector4(0.60, 0.92, 1.0, 0.7)),
              ColorStop(1.0, vm.Vector4(0.15, 0.50, 1.0, 0.0)),
            ]),
          ),
        ),
        LinearDragModule(1.1),
      ],
      seed: seed + 5,
    );
  }

  /// Advances the throttle and applies it to every layer.
  ///
  /// Deliberately does not step the systems: the emitter components do that
  /// from the engine's own frame delta. This only decides how hard each layer
  /// is burning.
  ///
  /// The flame and core respond fastest (they are what a child reads as
  /// thrust); smoke ramps in last and lingers on the way down, which is what
  /// stops a stop from looking like the plume being switched off.
  void tick(double dt, {required double flickerPhase}) {
    // Clamped so a tab regaining focus, or a rebuild that skips a frame, cannot
    // hand the throttle a multi-second delta and slam it to its target.
    final step = dt.clamp(0.0, 0.1);
    _throttle =
        (_throttle + (_throttleTarget - _throttle) * _throttleResponse * step)
            .clamp(0.0, 1.0);

    // Combustion is never perfectly steady. Two out-of-phase sines beat against
    // each other so the flicker never settles into an obvious loop.
    final flicker =
        1.0 +
        math.sin(flickerPhase * 27.0) * 0.06 +
        math.cos(flickerPhase * 41.0) * 0.04;
    final burn = _throttle * flicker;

    // Idle still needs a visible pilot light, so the core's floor is not zero.
    final coreBurn = 0.18 + 0.82 * burn;
    final flameBurn = 0.10 + 0.90 * burn;
    // Squaring the smoke and embers is what makes them lag: they only really
    // appear once the engine is properly open, and fade out well after it has
    // shut again.
    final smokeBurn = burn * burn;
    final emberBurn = burn * burn * burn;

    core.spawner.rate = 30 + 420 * coreBurn;
    flame.spawner.rate = 20 + 300 * flameBurn;
    smoke.spawner.rate = 6 + 70 * smokeBurn;
    embers.spawner.rate = 4 + 90 * emberBurn;

    // Faster exhaust at a higher throttle, so a hard burn reaches further
    // rather than just burning brighter in the same place.
    core.startSpeed = UniformFloat(0.85, 1.3 + 0.9 * burn);
    flame.startSpeed = UniformFloat(0.55, 0.95 + 0.8 * burn);
    embers.startSpeed = UniformFloat(1.05, 2.0 + 1.3 * burn);

    // The glow flare has to grow and shrink with the flame, or it shows as a
    // bright ring around the base of the plume.
    glowSpread = 0.72 + 0.40 * burn;
    glowHeat = burn;
    lightIntensity = math.max(0.0, 1.45 * burn);
  }

  /// Size of the nozzle glow flare relative to its rest shape.
  double glowSpread = 0.55;

  /// How hot the throat looks, `0` to `1`.
  double glowHeat = 0.55;

  /// Radiance of the throat light.
  ///
  /// The plume lighting the rocket's own white nosecone and engine bell is the
  /// single cheapest cue that the engine is actually on fire.
  double lightIntensity = 0.0;

  /// How far the flame reaches along the plume's own axis.
  ///
  /// The emitter runs along its local `+Y` (the node is turned to point that
  /// way down the rocket), so the furthest particle's `+Y` is how far the
  /// plume has streamed.
  double get flameReach {
    var furthest = 0.0;
    final storage = flame.storage;
    for (var i = 0; i < storage.aliveCount; i++) {
      final depth = storage.posY[i];
      if (depth > furthest) furthest = depth;
    }
    return furthest;
  }

  /// Total live particles across every layer.
  int get liveCount => systems.fold(0, (sum, s) => sum + s.storage.aliveCount);

  /// Steps every layer's simulation by [dt].
  ///
  /// In the running app the emitter components do this from the engine's frame
  /// delta. Exposed so the plume can be exercised on its own.
  void step(double dt) {
    for (final system in systems) {
      system.step(dt);
    }
  }

  /// Stops the plume without clearing the live particles, so an engine that
  /// shuts down fades out instead of vanishing.
  void shutDown() => setThrottle(0);
}
