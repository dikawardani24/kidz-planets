import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/avatar_state.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_face_projection.dart';
import 'package:kidz_planets/presentation/widgets/panels/avatar_face.dart';

/// The face is the part of the companion a child actually reads. Its geometry
/// is checked in [avatarExpression], and this file checks the two things only a
/// widget tree can show: that it is painted at all, and that it steps aside
/// when the rocket is turned around.
void main() {
  const box = Size(132, 148);

  group('expressions', () {
    test('the resting face is a plain friendly one', () {
      final face = avatarExpression(AvatarReaction.none, 0);
      expect(face.eyes, AvatarEye.open);
      expect(face.mouth, AvatarMouth.smile);
    });

    test('each reaction gets the face the brief asks for', () {
      expect(
        avatarExpression(AvatarReaction.happy, 0),
        const AvatarExpression(eyes: AvatarEye.happy, mouth: AvatarMouth.grin),
      );
      expect(
        avatarExpression(AvatarReaction.sad, 0),
        const AvatarExpression(eyes: AvatarEye.droopy, mouth: AvatarMouth.frown),
      );
      expect(
        avatarExpression(AvatarReaction.surprised, 0),
        const AvatarExpression(eyes: AvatarEye.wide, mouth: AvatarMouth.openSmall),
      );
      expect(
        avatarExpression(AvatarReaction.sleepy, 0),
        const AvatarExpression(
            eyes: AvatarEye.halfClosed, mouth: AvatarMouth.flat),
      );
      expect(
        avatarExpression(AvatarReaction.dizzy, 0),
        const AvatarExpression(eyes: AvatarEye.spiral, mouth: AvatarMouth.wavy),
      );
      expect(
        avatarExpression(AvatarReaction.laughing, 0),
        const AvatarExpression(
            eyes: AvatarEye.happy, mouth: AvatarMouth.openWide),
      );
      expect(
        avatarExpression(AvatarReaction.excited, 0),
        const AvatarExpression(eyes: AvatarEye.sparkle, mouth: AvatarMouth.grin),
      );
    });

    test('every reaction has an expression', () {
      for (final reaction in AvatarReaction.values) {
        for (final phase in [0.0, 0.25, 0.5, 0.75]) {
          final face = avatarExpression(reaction, phase);
          expect(AvatarEye.values, contains(face.eyes), reason: '$reaction');
          expect(AvatarMouth.values, contains(face.mouth), reason: '$reaction');
        }
      }
    });

    test('talking moves its mouth', () {
      // A third of a cycle apart, so the mouth is open on one and shut on the
      // other: that alternation *is* the talking animation.
      final open = avatarExpression(AvatarReaction.talking, 0.05);
      final shut = avatarExpression(AvatarReaction.talking, 0.25);

      expect(open.mouth, AvatarMouth.openSmall);
      expect(shut.mouth, AvatarMouth.talking);
      expect(open.eyes, shut.eyes, reason: 'only the mouth moves');
    });
  });

  group('on screen', () {
    Widget face(AvatarState pose) => Directionality(
          textDirection: TextDirection.ltr,
          child: AvatarFace(
            box: box,
            pose: pose,
            motion: AvatarBodyMotion.rest,
          ),
        );

    testWidgets('a companion facing the child is painted', (tester) async {
      await tester.pumpWidget(face(const AvatarState()));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('a companion turned all the way around has no face to show',
        (tester) async {
      await tester.pumpWidget(face(const AvatarState(yaw: 3.14159)));
      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('a companion tipped well over still shows its face',
        (tester) async {
      // Halfway to the pitch limit: the window is still turned towards the
      // child, so the face comes with it.
      await tester.pumpWidget(face(const AvatarState(pitch: 0.9)));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('a companion at the pitch limit has looked away', (tester) async {
      // 86 degrees is nearly edge-on, and a face squashed to 7% of its width
      // reads as a drawing error rather than as a turning toy, so it steps
      // aside until the child tips it back.
      await tester.pumpWidget(face(const AvatarState(pitch: AvatarState.pitchLimit)));
      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('a reaction changes what the face shows', (tester) async {
      await tester.pumpWidget(face(const AvatarState()));
      final resting = tester.widget<CustomPaint>(find.byType(CustomPaint).last);
      await tester.pumpWidget(
        face(const AvatarState(reaction: AvatarReaction.sad)),
      );
      final sad = tester.widget<CustomPaint>(find.byType(CustomPaint).last);

      expect(resting.painter, isNot(sad.painter));
      expect(
        (resting.painter as AvatarFacePainter).reaction,
        AvatarReaction.none,
        reason: 'the resting face is the resting expression',
      );
      expect((sad.painter as AvatarFacePainter).reaction, AvatarReaction.sad);
    });
  });
}
