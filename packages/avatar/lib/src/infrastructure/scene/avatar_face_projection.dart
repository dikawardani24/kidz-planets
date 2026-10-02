import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:vector_math/vector_math.dart' as vm;

import 'avatar_geometry.dart';

/// The rocket body's own animation pose for one frame.
///
/// The 3D layer animates the body by itself (hovering, banking, spinning), and
/// the 2D face is painted by Flutter on top of that render. Reporting the body
/// pose is what keeps the face stuck to the window instead of floating beside
/// it while the companion bounces.
class AvatarBodyMotion {
  const AvatarBodyMotion({this.hover = 0, this.tilt = 0, this.spin = 0});

  /// The pose a companion that has not been ticked yet holds.
  static const AvatarBodyMotion rest = AvatarBodyMotion();

  /// Offset along the rocket's own up axis, in body units.
  final double hover;

  /// Bank about the rocket's forward axis, in radians.
  final double tilt;

  /// Spin about the rocket's own up axis, in radians.
  final double spin;

  @override
  bool operator ==(Object other) =>
      other is AvatarBodyMotion &&
      other.hover == hover &&
      other.tilt == tilt &&
      other.spin == spin;

  @override
  int get hashCode => Object.hash(hover, tilt, spin);
}

/// Where the rocket's window lands inside the companion's 3D viewport.
///
/// Pure geometry, so the widget layer can draw a face exactly over the window
/// without asking the renderer anything: it repeats the same camera and node
/// transforms the scene applies. The camera constants mirror
/// [AvatarSceneControllerImpl.camera], and the window constants come from
/// [AvatarPorthole], so the picture this describes is the one on screen.
class AvatarFaceProjection {
  const AvatarFaceProjection({
    required this.centre,
    required this.radius,
    required this.facing,
  });

  /// Centre of the window in box-local pixels, origin at the box's top-left.
  final Offset centre;

  /// Projected radius of the window, in pixels.
  final double radius;

  /// Face readability factor. The face is a camera-facing billboard, so it
  /// stays fully readable even when the rocket body tumbles upside down or
  /// turns away during a throw. Kept as a field for painter compatibility.
  final double facing;

  /// Vertical field of view of the companion's camera, in radians.
  static const double cameraFovRadiansY = 0.62;

  /// Distance from the camera to the rocket's centre.
  static const double cameraDistance = 1.75;

  /// Height of the camera's look-at target.
  static const double cameraTargetY = 0.02;

  /// The window's centre, projected for a companion [pose] and body [motion].
  static AvatarFaceProjection forBox(
    Size box, {
    required double yaw,
    required double pitch,
    AvatarBodyMotion motion = AvatarBodyMotion.rest,
  }) {
    if (box.isEmpty) {
      return const AvatarFaceProjection(
        centre: Offset.zero,
        radius: 0,
        facing: 0,
      );
    }

    // The body's own animation, applied first because it is a child transform.
    final bodyRotation =
        vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), motion.tilt) *
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), motion.spin);
    // Then the child's rotation of the whole toy, matching setRotation().
    final avatarRotation =
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw) *
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), pitch);

    final windowInBody = vm.Vector3(
      0,
      AvatarPorthole.height,
      AvatarPorthole.depth,
    );
    final windowInWorld = avatarRotation.rotated(
      bodyRotation.rotated(windowInBody) + vm.Vector3(0, motion.hover, 0),
    );

    // The face looks down the rocket's nose, so it is the window normal - not
    // the window's position - that says whether the child can see it.
    // The rocket body is allowed to tumble freely, but the cartoon face is
    // intentionally a camera-facing billboard. Previously this value faded
    // the face whenever the body became edge-on or upside down, which made a
    // fast throw turn the companion into a faceless rocket. The face remains
    // attached to the projected window position while its drawing itself is
    // kept upright by AvatarFacePainter.
    const facing = 1.0;

    final depth = windowInWorld.z + cameraDistance;
    if (depth <= 0) {
      return const AvatarFaceProjection(
        centre: Offset.zero,
        radius: 0,
        facing: 0,
      );
    }

    // Focal length in pixels, from the vertical field of view the camera was
    // built with: a point one unit in front of the camera spreads over
    // tan(fovY / 2) body units across half the viewport's height.
    final focalLength = (box.height / 2) / math.tan(cameraFovRadiansY / 2);
    final scale = focalLength / depth;

    return AvatarFaceProjection(
      centre: Offset(
        box.width / 2 + windowInWorld.x * scale,
        box.height / 2 - (windowInWorld.y - cameraTargetY) * scale,
      ),
      radius: AvatarPorthole.radius * scale,
      facing: facing,
    );
  }
}
