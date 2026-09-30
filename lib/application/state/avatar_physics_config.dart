/// Tuning for the companion's throw, bounce and roll.
///
/// Every constant the feel of a throw depends on lives here, so the numbers
/// can be changed in one place instead of hunted for across the controller and
/// the widget that drives it.
///
/// [friction] and [restitution] are the two that actually decide whether a
/// throw reads as physical. Friction is the cost of rolling on nothing in
/// particular, and restitution is the cost of hitting a wall.
abstract final class AvatarPhysicsConfig {
  /// How much speed a bounce keeps, `0` to `1`.
  ///
  /// 0.72 means a hard throw loses about a quarter of its speed per wall, which
  /// is what makes a second bounce visibly shorter than the first rather than
  /// every bounce being identical.
  static const double restitution = 0.72;

  /// The fraction of velocity a throw keeps each 1/60th of a second.
  ///
  /// Expressed per frame rather than per second on purpose: it is the number
  /// that matches how fast the toy visibly slows, and [perSecond] below
  /// converts it for the frame-rate-independent path.
  static const double friction = 0.985;

  /// Below this speed, in logical pixels per second, the throw is over.
  ///
  /// Anything smaller than this cannot move the toy a visible distance in a
  /// frame, so continuing to integrate it would only produce an endless crawl
  /// of sub-pixel micro-movement that never quite settles.
  static const double stopVelocity = 35.0;

  /// The cap on a single throw's speed, in logical pixels per second.
  ///
  /// A stuttered frame or a wild pointer spike must not be able to launch the
  /// companion off screen; at this speed a throw crosses a phone-sized viewport
  /// in about a third of a second, which is already a hard throw.
  static const double maxThrowVelocity = 3000.0;

  /// The impact speed a full-strength reaction is designed around.
  ///
  /// This is the speed a hard fling actually carries into a wall, measured from
  /// a throw released at [maxThrowVelocity] across a phone-sized viewport:
  /// friction takes a few hundred pixels per second off it before the first
  /// contact. It is deliberately lower than [maxThrowVelocity], because
  /// normalising impact feedback against the cap means almost nothing ever
  /// reaches full strength. A wall hit at the cap needs a throw no child
  /// produces, so an impact measured against it comes out at a fraction of the
  /// level it was designed for, which for the sound is the difference between
  /// an audible thud and something the speaker never reproduces.
  static const double impactReferenceSpeed = 1800.0;

  /// The largest frame delta the simulation will integrate, in seconds.
  ///
  /// A frame this long is about two missed frames at 30 fps. Clamping here is
  /// what stops the app returning from the background from teleporting the
  /// companion across the screen on a single enormous step.
  static const double maxDeltaTime = 0.032;

  /// A throw slower than this is treated as a release, not a throw.
  ///
  /// Below this the momentum is not worth simulating: the companion would creep
  /// a few pixels and stop, which reads as the snap-to-a-halt this is meant to
  /// replace.
  static const double minThrowVelocity = 60.0;

  /// Radian per second of yaw per logical pixel per second of throw speed.
  ///
  /// Scaled so a hard throw tumbles the toy several times over its flight,
  /// while a gentle one barely tips it.
  ///
  /// A per-frame friction factor silently changes the feel of a throw with the
  /// frame rate: at 120 fps the toy would coast twice as far. The step therefore
  /// raises this friction to a power proportional to the elapsed time, so the
  /// decay depends on wall-clock seconds and a throw covers the same distance on
  /// a 30 fps phone as on a 120 fps one.
  static const double spinPerPixel = 0.0022;

  /// The same, for pitch.
  ///
  /// Deliberately weaker than yaw: the toy is a rocket that sits upright, so
  /// tumbling sideways reads as flight while pitching reads as falling over.
  static const double tipPerPixel = 0.0011;

  /// The cap on how fast the toy may spin, in radians per second.
  ///
  /// Without it, [spinPerPixel] times a hard throw's speed works out to tens of
  /// radians per second: the toy would blur through several revolutions per
  /// frame, which reads as noise rather than as one object turning over.
  static const double maxSpin = 6.0;

  /// The extra spin a bounce adds, in radians, at a full-speed impact.
  ///
  /// Small on purpose. It exists to make the reversal read as the toy being
  /// knocked rather than as its motion glitching, and anything larger would
  /// fight the steady roll the throw has already built up.
  static const double impactKick = 0.22;

  /// The largest number of wall reflections a single step may resolve.
  ///
  /// A hard throw reflects off a wall about once every twenty frames, so four is
  /// already generous. It is a backstop rather than a real limit: it exists so a
  /// collapsed bounds rectangle, where every reflection lands on the same spot,
  /// cannot spin forever inside one frame.
  static const int maxBouncesPerStep = 4;

  /// The smallest a throwable region may be, in logical pixels, and still count
  /// as somewhere to throw.
  ///
  /// Below this the region is effectively a single point, and animating a throw
  /// into it would only ever be a snap.
  static const double minRunnableExtent = 1.0;

  /// Extra damping applied when the platform asks for reduced motion.
  ///
  /// A per-frame constant, for the same reason as [friction]: the step raises it
  /// to a power proportional to the elapsed time so the calmer toy settles at
  /// the same rate whatever the refresh rate.
  static const double reducedMotionDamping = 0.94;

  /// The slowest bounce that still counts as an impact worth reacting to.
  ///
  /// Below this the toy is settling rather than bouncing, and playing a sound
  /// or squashing for each of those would turn the last few seconds of a throw
  /// into a rattle.
  static const double impactVelocity = 90.0;

  /// The loudest an impact plays.
  ///
  /// Full scale, unlike the beds and the narration. A bounce is a percussive
  /// transient rather than something to listen to, and it has to be heard over
  /// the mission bed it lands on; the sample itself peaks below full scale, so
  /// playing it at one still leaves headroom rather than clipping.
  static const double impactVolume = 1.0;

  /// The quietest an impact plays, as a fraction of [impactVolume].
  ///
  /// Well above zero, and the reason the gentle end has to be this high: a
  /// graze the child cannot hear is indistinguishable from the toy silently
  /// failing to bounce, which is the exact failure this sound exists to fix.
  ///
  /// This is a floor rather than a curve shape, and it is what the range is
  /// spent on. The whole useful span of impact speeds is roughly 200 to 2000,
  /// and the level a phone speaker is known to reproduce is about 0.65, so
  /// every real bounce has to sit above that: any contrast taken below it is
  /// contrast the child never hears, at the cost of the feedback itself.
  static const double impactMinVolume = 0.55;

  /// How much of a wall hit an impact squashes the toy, as a fraction of its
  /// size, at [impactReferenceSpeed].
  ///
  /// Deep enough to read at a glance on a small screen, and short-lived enough
  /// that it does not become the new shape of the toy.
  static const double impactSquashDepth = 0.14;

  /// How long an impact squash takes to relax back to a round toy.
  ///
  /// Long enough to be seen at all, short enough that a fast throw bouncing
  /// several times in a second does not smear into a continuous wobble.
  static const Duration impactDuration = Duration(milliseconds: 100);

  /// The shortest gap between two impact sounds, in milliseconds.
  ///
  /// A fast throw can cross a small viewport in a handful of frames; without a
  /// floor the bounces would overlap into a continuous buzz.
  static const int impactCooldownMs = 70;

  /// How much of a throw survives when the platform asks for reduced motion.
  ///
  /// The toy still goes where it was thrown, so the gesture keeps its meaning,
  /// but it settles quickly instead of careening around the screen. Removing
  /// the throw entirely would break the one-to-one relationship between the
  /// child's flick and what the toy does, which is worse than a calmer flick.
  static const double reducedMotionThrowScale = 0.35;

  /// Scales a bounce's contribution to the squash animation.
  ///
  /// Reduced motion needs a gentler impact as well as a gentler throw, since
  /// the squash is the most eye-catching part of a bounce.
  static const double reducedMotionImpactScale = 0.4;
}
