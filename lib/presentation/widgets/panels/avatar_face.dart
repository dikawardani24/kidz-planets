import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../application/state/avatar_squash.dart';
import '../../../application/state/avatar_state.dart';
import '../../../infrastructure/scene/avatar_face_projection.dart';

/// The companion's cartoon face, painted over its 3D window.
///
/// The face is drawn by Flutter rather than built from scene meshes on purpose.
/// Adding eye and mouth meshes to the companion scene is what blanked the whole
/// Explorer once, and a face is the least important thing on that screen: here
/// it can never take the 3D render down with it, and it costs one small paint
/// pass per frame. The projection it draws against is the *same* camera and
/// node maths the scene uses, so it still sits on the window and moves with the
/// rocket as it hovers, tilts and spins.
class AvatarFace extends StatelessWidget {
  const AvatarFace({
    super.key,
    required this.box,
    required this.pose,
    required this.motion,
    this.phase = 0,
    this.squash = 1,
  });

  /// Size of the companion box the face is drawn inside.
  final Size box;

  /// The companion's pose: this is what the child rotates.
  final AvatarState pose;

  /// The rocket body's own animation for this frame.
  final AvatarBodyMotion motion;

  /// Running clock in seconds, for the expressions that move (talking,
  /// laughing).
  ///
  /// In seconds rather than `0..1` because it is fed by the same running total
  /// as the throw physics. An unbounded clock lets the expression and the toy
  /// agree on how much time has passed, which a wrapped one cannot.
  final double phase;

  /// How much the body is squashed by an impact, `1` meaning undeformed.
  ///
  /// The face is painted over the 3D body's window, so when the body is
  /// deformed the face has to be deformed by the same amount, or it reads as
  /// floating in front of the toy rather than sitting in its window.
  final double squash;

  /// Below this much facing the window is nearly edge-on, and half a face
  /// squashed onto its side reads as a drawing error rather than as a turning
  /// toy. The face simply steps aside until the child turns it back.
  static const double minimumFacing = 0.18;

  @override
  Widget build(BuildContext context) {
    final projection = AvatarFaceProjection.forBox(
      box,
      yaw: pose.yaw,
      pitch: pose.pitchClamped,
      motion: motion,
    );
    if (projection.radius <= 0 || projection.facing < minimumFacing) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      size: box,
      painter: AvatarFacePainter(
        projection: projection,
        reaction: pose.reaction,
        phase: phase,
        squash: squash,
      ),
    );
  }
}

/// Which eyes and which mouth the face is showing.
enum AvatarEye { open, wide, happy, droopy, halfClosed, spiral, sparkle }

enum AvatarMouth {
  smile,
  grin,
  openSmall,
  openWide,
  frown,
  flat,
  wavy,
  talking,
}

/// One frame of the face.
class AvatarExpression {
  const AvatarExpression({required this.eyes, required this.mouth});

  final AvatarEye eyes;
  final AvatarMouth mouth;

  @override
  bool operator ==(Object other) =>
      other is AvatarExpression && other.eyes == eyes && other.mouth == mouth;

  @override
  int get hashCode => Object.hash(eyes, mouth);
}

/// The face for [reaction] at looping [phase] (0..1).
///
/// Kept pure and separate from the painter so every expression can be checked
/// without rendering anything: what matters is that a sad companion is drawn
/// sad, not how the arc happens to be stroked.
AvatarExpression avatarExpression(AvatarReaction reaction, double phase) {
  return switch (reaction) {
    AvatarReaction.none => const AvatarExpression(
      eyes: AvatarEye.open,
      mouth: AvatarMouth.smile,
    ),
    AvatarReaction.happy => const AvatarExpression(
      eyes: AvatarEye.happy,
      mouth: AvatarMouth.grin,
    ),
    AvatarReaction.laughing => const AvatarExpression(
      eyes: AvatarEye.happy,
      mouth: AvatarMouth.openWide,
    ),
    AvatarReaction.surprised => const AvatarExpression(
      eyes: AvatarEye.wide,
      mouth: AvatarMouth.openSmall,
    ),
    AvatarReaction.sad => const AvatarExpression(
      eyes: AvatarEye.droopy,
      mouth: AvatarMouth.frown,
    ),
    AvatarReaction.dizzy => const AvatarExpression(
      eyes: AvatarEye.spiral,
      mouth: AvatarMouth.wavy,
    ),
    AvatarReaction.sleepy => const AvatarExpression(
      eyes: AvatarEye.halfClosed,
      mouth: AvatarMouth.flat,
    ),
    AvatarReaction.excited => const AvatarExpression(
      eyes: AvatarEye.sparkle,
      mouth: AvatarMouth.grin,
    ),
    // Confused is the asking wobble: one eye wide, one narrowed. The face
    // reads as a question rather than as a second kind of surprise.
    AvatarReaction.confused => const AvatarExpression(
      eyes: AvatarEye.wide,
      mouth: AvatarMouth.wavy,
    ),
    // Talking *is* the mouth animation: it opens and shuts about three times a
    // second, which is what makes a silent companion look like it is speaking.
    AvatarReaction.talking => AvatarExpression(
      eyes: AvatarEye.open,
      mouth: math.sin(phase * math.pi * 6) > 0
          ? AvatarMouth.openSmall
          : AvatarMouth.talking,
    ),
  };
}

/// Draws an [AvatarExpression] around the projected window.
class AvatarFacePainter extends CustomPainter {
  const AvatarFacePainter({
    required this.projection,
    required this.reaction,
    required this.phase,
    this.squash = 1,
  });

  final AvatarFaceProjection projection;
  final AvatarReaction reaction;
  final double phase;
  final double squash;

  /// Face ink: a dark navy that reads on both the cyan window and the red body.
  static const Color ink = Color(0xFF10203F);
  static const Color cheek = Color(0xFFFF7EA8);

  @override
  void paint(Canvas canvas, Size size) {
    final unit = projection.radius;
    if (unit <= 0) return;

    final opacity = projection.facing;
    final expression = avatarExpression(reaction, phase);

    canvas.save();
    canvas.translate(projection.centre.dx, projection.centre.dy);
    // The impact squash comes first, because it is a transform of the whole
    // body and the facing below is a transform of the face within it. The same
    // [AvatarSquash] the 3D body uses, so the two cannot drift apart.
    final squashAxes = AvatarSquash.axes(squash);
    canvas.scale(squashAxes.dx, squashAxes.dy);
    // Squashing the face sideways is the cheap way to show the rocket turning:
    // at 45 degrees the face is half as wide, and it is gone at 90.
    canvas.scale(opacity, 1);
    if (expression.mouth == AvatarMouth.grin ||
        expression.mouth == AvatarMouth.openWide) {
      _paintCheeks(canvas, unit, opacity);
    }
    _paintEyes(canvas, expression.eyes, unit, opacity);
    _paintMouth(canvas, expression.mouth, unit, opacity);
    canvas.restore();
  }

  Paint _fill(Color color, double opacity) =>
      Paint()..color = color.withValues(alpha: opacity);

  Paint _stroke(Color color, double opacity, double width) => Paint()
    ..color = color.withValues(alpha: opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  void _paintEyes(Canvas canvas, AvatarEye style, double unit, double opacity) {
    for (final side in const [-1.0, 1.0]) {
      final centre = Offset(side * 0.92 * unit, -0.78 * unit);
      switch (style) {
        case AvatarEye.open:
          canvas.drawCircle(centre, 0.58 * unit, _fill(Colors.white, opacity));
          canvas.drawCircle(
            centre + Offset(side * 0.10 * unit, 0.06 * unit),
            0.29 * unit,
            _fill(ink, opacity),
          );
        case AvatarEye.wide:
          // Bigger whites and much smaller pupils: the classic startled look.
          canvas.drawCircle(centre, 0.74 * unit, _fill(Colors.white, opacity));
          canvas.drawCircle(centre, 0.19 * unit, _fill(ink, opacity));
        case AvatarEye.happy:
          // An upward arc, the ^ in a cartoon ^_^ face.
          canvas.drawArc(
            Rect.fromCircle(center: centre, radius: 0.55 * unit),
            math.pi,
            math.pi,
            false,
            _stroke(ink, opacity, 0.17 * unit),
          );
        case AvatarEye.droopy:
          canvas.drawArc(
            Rect.fromCircle(
              center: centre + Offset(0, 0.20 * unit),
              radius: 0.5 * unit,
            ),
            0,
            math.pi,
            false,
            _stroke(ink, opacity, 0.15 * unit),
          );
        case AvatarEye.halfClosed:
          canvas.drawCircle(
            centre,
            0.5 * unit,
            _fill(Colors.white, opacity * 0.7),
          );
          canvas.drawLine(
            centre + Offset(-0.5 * unit, -0.08 * unit),
            centre + Offset(0.5 * unit, -0.08 * unit),
            _stroke(ink, opacity, 0.16 * unit),
          );
        case AvatarEye.spiral:
          canvas.drawPath(
            _spiral(centre, 0.62 * unit),
            _stroke(ink, opacity, 0.11 * unit),
          );
        case AvatarEye.sparkle:
          canvas.drawCircle(centre, 0.68 * unit, _fill(Colors.white, opacity));
          canvas.drawCircle(centre, 0.30 * unit, _fill(ink, opacity));
          canvas.drawCircle(
            centre + Offset(-0.18 * unit, -0.20 * unit),
            0.12 * unit,
            _fill(Colors.white, opacity),
          );
      }
    }
  }

  void _paintCheeks(Canvas canvas, double unit, double opacity) {
    final paint = _fill(cheek, opacity * 0.55);
    for (final side in const [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(side * 1.65 * unit, 0.45 * unit),
        0.34 * unit,
        paint,
      );
    }
  }

  void _paintMouth(
    Canvas canvas,
    AvatarMouth style,
    double unit,
    double opacity,
  ) {
    final centre = Offset(0, 1.15 * unit);
    switch (style) {
      case AvatarMouth.smile:
        canvas.drawArc(
          Rect.fromCircle(
            center: centre - Offset(0, 0.3 * unit),
            radius: 0.62 * unit,
          ),
          0,
          math.pi,
          false,
          _stroke(ink, opacity, 0.15 * unit),
        );
      case AvatarMouth.grin:
        canvas.drawArc(
          Rect.fromCircle(
            center: centre - Offset(0, 0.28 * unit),
            radius: 0.78 * unit,
          ),
          0,
          math.pi,
          false,
          _stroke(ink, opacity, 0.20 * unit),
        );
      case AvatarMouth.openSmall:
        canvas.drawOval(
          Rect.fromCenter(
            center: centre,
            width: 0.62 * unit,
            height: 0.78 * unit,
          ),
          _fill(ink, opacity),
        );
      case AvatarMouth.openWide:
        canvas.drawOval(
          Rect.fromCenter(
            center: centre,
            width: 1.25 * unit,
            height: 0.95 * unit,
          ),
          _fill(ink, opacity),
        );
      case AvatarMouth.frown:
        canvas.drawArc(
          Rect.fromCircle(
            center: centre + Offset(0, 0.55 * unit),
            radius: 0.66 * unit,
          ),
          math.pi,
          math.pi,
          false,
          _stroke(ink, opacity, 0.15 * unit),
        );
      case AvatarMouth.flat:
        canvas.drawLine(
          centre - Offset(0.34 * unit, 0),
          centre + Offset(0.34 * unit, 0),
          _stroke(ink, opacity, 0.15 * unit),
        );
      case AvatarMouth.wavy:
        canvas.drawPath(
          _wave(centre, unit),
          _stroke(ink, opacity, 0.13 * unit),
        );
      case AvatarMouth.talking:
        canvas.drawOval(
          Rect.fromCenter(
            center: centre,
            width: 0.85 * unit,
            height: 0.5 * unit,
          ),
          _fill(ink, opacity),
        );
    }
  }

  /// A one-and-a-half turn spiral, drawn as a polyline: cheap, and it reads as
  /// "dizzy" without a shader or an animation.
  Path _spiral(Offset centre, double radius) {
    final path = Path();
    const steps = 36;
    for (var i = 0; i <= steps; i++) {
      final progress = i / steps;
      final angle = progress * math.pi * 3;
      final point =
          centre +
          Offset(
            math.cos(angle) * radius * progress,
            math.sin(angle) * radius * progress,
          );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  Path _wave(Offset centre, double width) {
    final path = Path()..moveTo(centre.dx - width, centre.dy);
    path.relativeQuadraticBezierTo(width * 0.5, -width * 0.4, width, 0);
    path.relativeQuadraticBezierTo(width * 0.5, width * 0.4, width, 0);
    return path;
  }

  @override
  bool shouldRepaint(AvatarFacePainter oldDelegate) =>
      oldDelegate.projection.centre != projection.centre ||
      oldDelegate.projection.radius != projection.radius ||
      oldDelegate.projection.facing != projection.facing ||
      oldDelegate.reaction != reaction ||
      oldDelegate.phase != phase ||
      oldDelegate.squash != squash;
}
