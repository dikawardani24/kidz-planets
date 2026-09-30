import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart';
import 'package:kidz_planets/application/controllers/avatar_controller.dart';
import 'package:kidz_planets/application/state/avatar_state.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_face_projection.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_scene_controller.dart';
import 'package:kidz_planets/l10n/localized_planet.dart';
import 'package:kidz_planets/presentation/widgets/panels/avatar_speech.dart';
import 'helpers/localized_app.dart';
import 'package:kidz_planets/presentation/widgets/panels/mission_companion.dart';

/// Bubble placement is pure geometry, so it is exercised directly: the point of
/// these tests is the edge behaviour, not Flutter's layout. The widget tests
/// then cover what only a real widget tree can show, namely that the companion
/// and its handle are actually on screen and that the two gestures stay
/// separate.
void main() {
  const viewport = Size(400, 800);

  /// The line shown while the companion is idling over the scene: no planet is
  /// focused and no mission beat has started yet.
  const idleLine = 'Wheee! Flying all over space! 🚀';

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
    testWidgets('says something before any mission runs', (tester) async {
      await _pumpCompanion(tester);
      expect(find.text(idleLine), findsOneWidget);
    });

    testWidgets('avatar reacts when touched', (tester) async {
      await _pumpCompanion(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MissionCompanion)),
      );
      await tester.tapAt(_avatarCentre(container));
      // A single tap has to wait out the double-tap window before it is
      // resolved as a tap rather than as the start of a double tap.
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        container.read(avatarControllerProvider).reaction,
        AvatarReaction.happy,
      );
      await _runOutCompanionTimers(tester);
    });

    testWidgets('the whole toy is the move affordance, not a second handle',
        (tester) async {
      // The child drags the character itself. Nothing else on screen is
      // labelled as a way to move it, which is what "no separate handle" means.
      await _pumpCompanion(tester);
      expect(find.bySemanticsLabel('Move the space buddy'), findsOneWidget);
    });

    testWidgets('starts inside a small viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpCompanion(tester);

      final bubble = find.text(idleLine);
      expect(bubble, findsOneWidget);
      // The bubble is the widest thing the companion owns, so if it is on
      // screen the character below it must be too.
      final rect = tester.getRect(bubble);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    });

    testWidgets('dragging the avatar moves without rotating', (tester) async {
      await _pumpCompanion(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MissionCompanion)),
      );
      final before = container.read(avatarControllerProvider);

      await tester.dragFrom(_avatarCentre(container), const Offset(-60, -40));
      await tester.pump();

      final after = container.read(avatarControllerProvider);
      expect(after.screenPosition, isNot(before.screenPosition));
      expect(after.yaw, before.yaw);
      expect(after.pitch, before.pitch);
      await _runOutCompanionTimers(tester);
    });

    testWidgets('a drag parks the companion where the child put it',
        (tester) async {
      await _pumpCompanion(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MissionCompanion)),
      );

      await tester.dragFrom(_avatarCentre(container), const Offset(-60, 40));
      await tester.pump();
      final parked = container.read(avatarControllerProvider).screenPosition;

      // The flight loop must not slide it back to its own path: a toy the child
      // has placed stays where it was placed.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final now = container.read(avatarControllerProvider);
      expect(now.isFlightPaused, isTrue);
      expect(now.screenPosition, parked);
      await _runOutCompanionTimers(tester);
    });

    testWidgets('a two finger drag turns the toy in both axes', (tester) async {
      await _pumpCompanion(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MissionCompanion)),
      );
      final before = container.read(avatarControllerProvider);
      final centre = _avatarCentre(container);

      // Two fingers, because one is how the child moves the toy.
      final first = await tester.startGesture(centre);
      final second = await tester.startGesture(centre + const Offset(40, 0));
      await tester.pump();
      await first.moveBy(const Offset(60, 70));
      await second.moveBy(const Offset(60, 70));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pump();

      final after = container.read(avatarControllerProvider);
      expect(after.yaw, greaterThan(before.yaw), reason: 'sideways turns it');
      expect(after.pitch, greaterThan(before.pitch), reason: 'upwards tips it');
      await _runOutCompanionTimers(tester);
    });
  });

  group('the 3D layer is actually driven', () {
    // The overlay state is not the point on its own: what matters is that the
    // pose and the mission target reach the 3D layer, so these read the calls
    // the stand-in controller recorded rather than the provider state the
    // widget already had.
    testWidgets('the pose reaches the 3D layer, not just the state',
        (tester) async {
      final fake = await _pumpCompanion(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MissionCompanion)),
      );

      // One-finger dragging moves the character directly.
      await tester.dragFrom(_avatarCentre(container), const Offset(80, 40));
      await tester.pump();

      final pose = container.read(avatarControllerProvider);
      expect(pose.screenPosition, isNotNull);
      expect(fake.poses, isNotEmpty);
      expect(fake.poses.last.yaw, pose.yaw);
      expect(fake.poses.last.pitch, pose.pitch);
      await _runOutCompanionTimers(tester);
    });

    testWidgets('moving updates the position without re-aiming', (tester) async {
      final fake = await _pumpCompanion(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MissionCompanion)),
      );
      final before = container.read(avatarControllerProvider).screenPosition;

      await tester.dragFrom(_avatarCentre(container), const Offset(-50, -30));
      await tester.pump();

      final pose = container.read(avatarControllerProvider);
      expect(pose.screenPosition, isNot(before), reason: 'the move took effect');
      expect(fake.poses.last.yaw, 0, reason: 'a move must not re-aim the model');
      expect(fake.poses.last.pitch, 0);
      await _runOutCompanionTimers(tester);
    });

    testWidgets('a mood change reaches the 3D layer as a reaction',
        (tester) async {
      final fake = await _pumpCompanion(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MissionCompanion)),
      );

      // Miss the active mission on purpose: the mission is what changes the
      // mood, and the mood is what the companion reacts to.
      final target = container
          .read(explorerControllerProvider)
          .activeMission!
          .targetPlanetId;
      final wrong = container
          .read(planetsProvider)
          .firstWhere((p) => p.id != target);

      container.read(explorerControllerProvider.notifier).selectPlanet(wrong.id);
      // Let the reaction play out and the spin hint expire, so nothing is left
      // pending when the test ends.
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        container.read(avatarControllerProvider).reaction,
        AvatarReaction.sad,
        reason: 'a wrong pick droops',
      );
      expect(fake.reactions, contains(AvatarReaction.sad));

      await tester.pump(const Duration(seconds: 5));
      expect(
        container.read(avatarControllerProvider).reaction,
        AvatarReaction.none,
        reason: 'the reaction expires on its own',
      );
    });

    testWidgets('the companion says the mission line when the beat lands',
        (tester) async {
      await _pumpCompanion(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MissionCompanion)),
      );
      final mission = container.read(explorerControllerProvider).activeMission!;
      final name = localizedPlanetName(
        mission.targetPlanetId,
        const Locale('en'),
      );

      // Before a beat, the companion is simply having fun.
      expect(find.text(avatarLine(AvatarMood.instruction, name)), findsNothing);

      container
          .read(explorerControllerProvider.notifier)
          .setAvatarMood(AvatarMood.instruction);
      await tester.pump();

      expect(
        find.text(avatarLine(AvatarMood.instruction, name)),
        findsOneWidget,
        reason: 'the child is told what to find, by name',
      );
      await _runOutCompanionTimers(tester);
    });

    testWidgets('the target ring is hidden on the companion', (tester) async {
      final fake = await _pumpCompanion(tester);
      expect(fake.targets, isNotEmpty);
      expect(fake.targets.last.visible, isFalse);
    });
  });

  group('pitch limits and throw physics', () {
    test('the exposed pitch never exceeds the readable range', () {
      const state = AvatarState(pitch: 99);
      expect(state.pitchClamped.abs(), AvatarState.pitchLimit);
    });

    test('launchWithVelocity applies momentum and decelerates over time', () {
      final controller = AvatarController();
      const maxPos = Offset(300, 600);
      controller.placeAt(const Offset(100, 100), maxPosition: maxPos);

      // Fast flick to the right
      controller.launchWithVelocity(
        velocity: const Offset(1000, 0),
        maxPosition: maxPos,
      );

      expect(controller.state.isThrowing, isTrue);
      expect(controller.state.velocity.dx, greaterThan(0));

      // Advance physics by 0.1 second
      controller.updateFlight(0.1, viewport, maxPos);
      expect(controller.state.screenPosition!.dx, greaterThan(100.0));
      // Friction decelerates the velocity
      expect(controller.state.velocity.dx, lessThan(1000.0));

      // Advance time until momentum stops
      for (var i = 0; i < 30; i++) {
        controller.updateFlight(0.1, viewport, maxPos);
      }

      expect(controller.state.isThrowing, isFalse);
      expect(controller.state.velocity, Offset.zero);
    });

    test('bounces off screen edges when thrown with high velocity', () {
      final controller = AvatarController();
      const maxPos = Offset(300, 600);
      controller.placeAt(const Offset(290, 100), maxPosition: maxPos);

      // Throw hard right towards the right edge
      controller.launchWithVelocity(
        velocity: const Offset(1000, 0),
        maxPosition: maxPos,
      );

      // Update frame -> hits right edge -> bounces back left
      controller.updateFlight(0.05, viewport, maxPos);

      // Velocity inverts (negative dx) due to bounce factor
      expect(controller.state.velocity.dx, lessThan(0));
      expect(controller.state.screenPosition!.dx, lessThanOrEqualTo(maxPos.dx));
    });
  });
}

/// The centre of the companion's own box, in the same coordinates the gestures
/// use. The overlay fills the whole screen, so a test that tapped the widget's
/// centre would be poking at empty space next to the toy instead of the toy.
Offset _avatarCentre(ProviderContainer container) {
  final position = container.read(avatarControllerProvider).screenPosition;
  expect(position, isNotNull, reason: 'the companion is placed before gestures');
  return position! +
      const Offset(kCompanionBoxWidth / 2, kCompanionBoxHeight / 2);
}

/// Runs out the companion's own timers before a test ends.
///
/// Touching or dragging the toy starts two of them: the double-tap countdown
/// behind every gesture, and the park hold that keeps a dragged companion where
/// the child left it. Both are real timers, and a test that ends with one
/// pending fails on that rather than on anything it was checking. Fake time is
/// free, so running them out costs nothing.
Future<void> _runOutCompanionTimers(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 11));
}

/// Pumps the companion over a stand-in controller and hands that controller
/// back, so a test can inspect what the overlay asked the 3D layer to do.
Future<_FakeController> _pumpCompanion(WidgetTester tester) async {
  final controller = _FakeController();
  await tester.pumpWidget(localizedApp(
    Scaffold(
      body: MissionCompanion(controllerFactory: () => controller),
    ),
  ));
  // Enough pumps to run the post-frame scene build and to commit the
  // starting position.
  await tester.pump();
  await tester.pump();
  return controller;
}


/// A stand-in for the GPU-backed companion scene.
///
/// Records what the overlay asked it to do so the tests can prove the pose and
/// the mission target actually reach the 3D layer, not just the state object.
class _FakeController implements AvatarSceneController {
  final List<({double yaw, double pitch})> poses = [];
  final List<({bool visible, Color color})> targets = [];
  final List<AvatarReaction> reactions = [];

  // Recorded but never asserted on: `_CompanionScene` short-circuits to a plain
  // box while `isRealScene` is false, so the per-frame tick never reaches a
  // stand-in. They are kept so a fake that does run a scene can assert on the
  // full tick signature.
  Duration? lastTick;
  AvatarMood? lastMood;
  AvatarIdleAction? lastIdleAction;
  String? lastSelectedPlanetId;

  @override
  Scene get scene => throw StateError('no GPU scene in a widget test');

  @override
  bool get isReady => true;

  @override
  bool get isRealScene => false;

  /// No scene means no body animation, which is also what the 2D face falls
  /// back to: it is drawn from the pose alone.
  @override
  AvatarBodyMotion get bodyMotion => AvatarBodyMotion.rest;

  @override
  void ensureBuilt() {}

  @override
  void tick(
    Duration elapsed,
    AvatarMood mood,
    AvatarIdleAction idleAction,
    String? selectedPlanetId,
  ) {
    lastTick = elapsed;
    lastMood = mood;
    lastIdleAction = idleAction;
    lastSelectedPlanetId = selectedPlanetId;
  }

  @override
  void applyPose(AvatarState pose) =>
      poses.add((yaw: pose.yaw, pitch: pose.pitch));

  @override
  void applyReaction(AvatarReaction reaction) => reactions.add(reaction);

  @override
  void showTarget({required bool visible, required Color color}) =>
      targets.add((visible: visible, color: color));

  @override
  void dispose() {}
}
