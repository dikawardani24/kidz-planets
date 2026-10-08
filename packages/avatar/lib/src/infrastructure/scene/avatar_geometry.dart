import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// How big the imported rocket body is drawn inside the companion's viewport.
///
/// The body is the bundled Kenney GLB, whose authored bounds are about
/// 0.57 x 1.00 x 0.41 units, and [rocket] is the node scale that sizes it.
/// [tuned] is the scale the companion's physics, camera and porthole anchor were
/// originally laid out against; [growth] is how much larger the body is drawn
/// than that, because the painted face was reading as oversized against it: the
/// eyes and mouth are the same size they always were, and the body grew around
/// them instead.
///
/// Kept as one number rather than a literal at the call site because the porthole
/// anchor and the exhaust are both positions *on* the body, so they have to move
/// with it; see [AvatarPorthole] and `AvatarSceneBuilder._buildBody`.
class AvatarBodyScale {
  const AvatarBodyScale._();

  /// Node scale the companion's layout was originally tuned around.
  static const double tuned = 0.42;

  /// How much bigger than [tuned] the body is drawn.
  ///
  /// The face is drawn at a fixed size, so this is the only lever on how large
  /// the companion reads. At [tuned] the painted face is wider than the rocket;
  /// 1.3 only just put the body around it and still read as a toy, so the body
  /// is drawn most of the way up to the edge of its viewport instead: the model
  /// is 1.0 units tall, so 1.7 keeps it inside the companion's 132 x 148 box
  /// even when it is tumbling (its worst-case diagonal is then ~108px of the
  /// 148px available).
  static const double growth = 1.7;

  /// Scale the imported rocket node is built with.
  static const double rocket = tuned * growth;

  /// Scale the imported astronaut node is built with.
  ///
  /// The astronaut GLB is authored at roughly the same height as the rocket
  /// (about one unit), so it shares the grown scale: the two read as the
  /// same size toy in the same viewport, and switching bodies never
  /// re-frames the companion.
  static const double astronaut = tuned * growth;
}

/// The rocket's round window, in body space.
///
/// The mesh, the node that places it and the 2D face painted over it all have
/// to agree on these three numbers, so they live together here rather than as
/// three copies that can drift apart.
class AvatarPorthole {
  const AvatarPorthole._();

  /// Radius of the window mesh, in body units.
  ///
  /// This is the *only* thing that sets how large the painted face is: eye
  /// radius, eye spacing and mouth size are all multiples of it. It is
  /// deliberately not tied to [AvatarBodyScale], so growing the body cannot
  /// shrink or enlarge the face.
  static const double radius = 0.075;

  /// Height of the window's centre on the rocket body.
  ///
  /// Scales with [AvatarBodyScale.growth] because this is a point *on* the body:
  /// a bigger body puts its window that much further from the origin, and
  /// leaving this behind would slide the painted face down the fuselage.
  ///
  /// Expressed against the grown body rather than as an absolute height, so it
  /// lands in the same place on the window at any size - roughly two fifths of
  /// the way down the fuselage, which is where this model's window is.
  static const double height = 0.05 * AvatarBodyScale.growth;

  /// How far the window sits in front of the body's centre line. Negative is
  /// towards the camera, which is where the front of the rocket is.
  ///
  /// Deliberately *not* scaled with the body, unlike [height]. The face is a
  /// camera-facing billboard rather than geometry on the model, so this only
  /// feeds the perspective term that decides its on-screen size - scaling it
  /// would silently resize the eyes and mouth, which is the opposite of what
  /// growing the body was for.
  static const double depth = -0.30;
}

/// Geometry for the Chubby Cartoon Rocket Ship Mascot.
///
/// A brand new, unique shape: a friendly little cartoon rocket ship with
/// a round nosecone, porthole window, little wings/fins, and engine thruster.
class AvatarGeometryFactory {
  AvatarGeometryFactory();

  final Map<String, MeshGeometry> _cache = {};

  /// Main rocket fuselage body.
  MeshGeometry rocketBody() => _cache.putIfAbsent(
    'rocket-body',
    () => CapsuleGeometry(
      radius: 0.14,
      height: 0.32,
      radialSegments: 22,
      capRings: 6,
    ),
  );

  /// Rounded rocket nosecone.
  MeshGeometry noseCone() => _cache.putIfAbsent(
    'nose-cone',
    () => SphereGeometry(radius: 0.14, segments: 20, rings: 10),
  );

  /// Front porthole window.
  MeshGeometry porthole() => _cache.putIfAbsent(
    'porthole',
    () =>
        SphereGeometry(radius: AvatarPorthole.radius, segments: 18, rings: 12),
  );

  /// Rocket side fins / wings.
  MeshGeometry fin() => _cache.putIfAbsent(
    'fin',
    () => CuboidGeometry(vm.Vector3(0.06, 0.12, 0.03)),
  );

  /// Rocket engine base nozzle.
  MeshGeometry engineNozzle() => _cache.putIfAbsent(
    'engine-nozzle',
    () => CapsuleGeometry(
      radius: 0.08,
      height: 0.06,
      radialSegments: 16,
      capRings: 3,
    ),
  );

  /// Stand-in for the mission target.
  MeshGeometry target() => _cache.putIfAbsent(
    'target',
    () => SphereGeometry(radius: 0.085, segments: 18, rings: 12),
  );

  void dispose() => _cache.clear();
}
