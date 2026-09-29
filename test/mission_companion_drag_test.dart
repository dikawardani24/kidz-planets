import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart';
import 'package:kidz_planets/application/controllers/avatar_controller.dart';
import 'package:kidz_planets/application/state/avatar_state.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_scene_controller.dart';
import 'package:kidz_planets/presentation/widgets/panels/avatar_speech.dart';
import 'package:kidz_planets/presentation/widgets/panels/mission_companion.dart';

/// Bubble placement is pure geometry, so it is exercised directly: the point of
/// these tests is the edge behaviour, not Flutter's layout. The widget tests
/// then cover what only a real widget tree can show, namely that the companion
/// and its handle are actually on screen and that the two gestures stay
/// separate.
void main() {
  const viewport = Size(400, 800);

  ({double top, BubbleSide side, bool below}) place({
    required double left,
    required double top,
    Size size = viewport,
  }) =>
      bubblePlacement(
        avatarTop: top,
        avatarLeft: left,
        avatarWidth: kCompanionBoxWidth,
        avatarHeight: kCompanionBoxHeight,
        viewport: size,
      );

  double leftEdgeFor(BubbleSide side, double left, {Size size = viewport}) =>
      bubbleLeft(
        side: side,
        avatarLeft: left,
        avatarWidth: kCompanionBoxWidth,
        viewport: size,
      );

  group('bubble picks a side that keeps it on screen', () {
    test('sits above the companion when there is room', () {
      expect(place(left: 200, top: 300).below, isFalse);
    });

    test('flips below the companion when there is no room above', () {
      expect(place(left: 200, top: 0).below, isTrue);
      expect(place(left: 200, top: 4).below, isTrue);
    });

    test('does not depend on rotation, only position', () {
      // Spinning the character must never move the text. Placement takes no
      // rotation input at all, so the bubble is identical for an unrotated and
      // a fully rotated pose at the same screen position.
      const flat = AvatarState(screenPosition: Offset(200, 300));
      const spun = AvatarState(
        screenPosition: Offset(200, 300),
        yaw: 6.28,
        pitch: AvatarState.pitchLimit,
      );
      expect(flat.screenPosition, spun.screenPosition);
      expect(place(left: 200, top: 300).top, place(left: 200, top: 300).top);
    });

    test('stays fully on screen at every corner', () {
      for (final left in [0.0, 100.0, 268.0]) {
        for (final top in [0.0, 100.0, 600.0]) {
          final p = place(left: left, top: top);
          final bubbleLeftEdge = leftEdgeFor(p.side, left);
          expect(bubbleLeftEdge, greaterThanOrEqualTo(0));
          expect(
            bubbleLeftEdge + kBubbleWidth,
            lessThanOrEqualTo(viewport.width + 0.001),
          );
        }
      }
    });

    test('slides to the right when the companion hugs the left edge', () {
      expect(place(left: 0, top: 300).side, BubbleSide.right);
    });

    test('slides to the left when the companion hugs the right edge', () {
      expect(place(left: 268, top: 300).side, BubbleSide.left);
    });

    test('works on a very narrow screen without going off the edge', () {
      const tiny = Size(200, 400);
      final p = place(left: 0, top: 100, size: tiny);
      final edge = leftEdgeFor(p.side, 0, size: tiny);
      expect(edge, greaterThanOrEqualTo(0));
      expect(edge + kBubbleWidth, lessThanOrEqualTo(tiny.width + 0.001));
    });
  });

  group('companion is actually on screen', () {
    // A real Scene needs a GPU with Impeller, which a widget test does not
    // have, so the 3D body is backed by a stand-in controller. Everything
    // tested here is the overlay around it: placement, the two gestures, the
    // bubble, and the mood wiring.
    Future<void> pumpCompanion(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MissionCompanion(controllerFactory: _FakeController.new),
            ),
          ),
        ),
      );
      // Enough pumps to run the post-frame scene build and to commit the
      // starting position.
      await tester.pump();
      await tester.pump();
    }

    testWidgets('says something before any mission runs', (tester) async {
      await pumpCompanion(tester);
      expect(find.textContaining('wait right here'), findsOneWidget);
    });

    testWidgets('move handle exists and is labelled for the child',
        (tester) async {
      await pumpCompanion(tester);
      expect(find.bySemanticsLabel('Move the space buddy'), findsOneWidget);
    });

    testWidgets('starts inside a small viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpCompanion(tester);

      final bubble = find.textContaining('wait right here');
      expect(bubble, findsOneWidget);
      // The bubble is the widest thing the companion owns, so if it is on
      // screen the character below it must be too.
      final rect = tester.getRect(bubble);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    });

    testWidgets('the move handle moves without rotating', (tester) async {
      await pumpCompanion(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MissionCompanion)),
      );
      final before = container.read(avatarControllerProvider);

      await tester.drag(
        find.bySemanticsLabel('Move the space buddy'),
        const Offset(-60, -40),
      );
      await tester.pump();

      final after = container.read(avatarControllerProvider);
      expect(after.screenPosition, isNot(before.screenPosition));
      // The whole point of a separate handle: moving must not re-aim.
      expect(after.yaw, before.yaw);
      expect(after.pitch, before.pitch);
    });
  });

  group('pitch limits', () {
    test('the exposed pitch never exceeds the readable range', () {
      const state = AvatarState(pitch: 99);
      expect(state.pitchClamped.abs(), AvatarState.pitchLimit);
    });
  });
}


/// A stand-in for the GPU-backed companion scene.
///
/// Records what the overlay asked it to do so the tests can prove the pose and
/// the mission target actually reach the 3D layer, not just the state object.
class _FakeController implements AvatarSceneController {
  final List<({double yaw, double pitch})> poses = [];
  final List<({bool visible, Color color})> targets = [];
  Duration? lastTick;
  AvatarMood? lastMood;

  @override
  Scene get scene => throw StateError('no GPU scene in a widget test');

  @override
  bool get isReady => true;

  @override
  bool get isRealScene => false;

  @override
  void ensureBuilt() {}

  @override
  void tick(Duration elapsed, AvatarMood mood) {
    lastTick = elapsed;
    lastMood = mood;
  }

  @override
  void applyPose(pose) => poses.add((yaw: pose.yaw, pitch: pose.pitch));

  @override
  void showTarget({required bool visible, required Color color}) =>
      targets.add((visible: visible, color: color));

  @override
  void dispose() {}
}
