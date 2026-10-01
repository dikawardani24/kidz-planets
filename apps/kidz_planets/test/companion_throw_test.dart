import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart';
import 'package:kidz_planets/application/controllers/avatar_controller.dart';
import 'package:kidz_planets/application/state/avatar_physics_config.dart';
import 'package:kidz_planets/application/state/avatar_state.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_face_projection.dart';
import 'package:kidz_planets/infrastructure/scene/avatar_scene_controller.dart';
import 'package:kidz_planets/presentation/widgets/panels/companion_safe_area.dart';
import 'package:kidz_planets/presentation/widgets/panels/mission_companion.dart';

import 'helpers/localized_app.dart';

/// A stand-in for the GPU scene that records what the overlay asked of it.
class _FakeController implements AvatarSceneController {
  final List<double> squashes = [];

  @override
  Scene get scene => throw StateError('no GPU scene in a widget test');

  @override
  bool get isReady => true;

  @override
  bool get isRealScene => false;

  @override
  AvatarBodyMotion get bodyMotion => AvatarBodyMotion.rest;

  @override
  void ensureBuilt() {}

  @override
  void setImpactSquash(double scale) => squashes.add(scale);

  @override
  void tick(
    Duration elapsed,
    AvatarMood mood,
    AvatarIdleAction idleAction,
    String? selectedPlanetId,
  ) {}

  @override
  void applyPose(AvatarState pose) {}

  @override
  void applyReaction(AvatarReaction reaction) {}

  @override
  void showTarget({required bool visible, required Color color}) {}

  @override
  void dispose() {}
}

/// Pumps the companion over a provider scope the test can read from.
///
/// The scope is the app's own rather than a hand-made container, so that taking
/// the tree down also disposes the controller. The controller owns a six-second
/// flight-style timer that it only cancels when it is disposed, so a container
/// that outlived the tree would leave that timer pending and fail the test on
/// the timer instead of on the throw.
Future<({_FakeController scene, ProviderContainer container})> _pump(
  WidgetTester tester, {
  Size size = const Size(400, 800),
  EdgeInsets viewPadding = EdgeInsets.zero,
  bool disableAnimations = false,
}) async {
  final scene = _FakeController();

  // The window is set on the view rather than by wrapping the tree in a
  // `MediaQuery`, because the companion reads the real one. A `MediaQuery`
  // override would leave the layout still the size of the test surface, so a
  // toy that sized itself from its constraints would be tested on something
  // the app never shows it.
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    localizedApp(
      Builder(
        builder: (context) {
          // The view supplies the size; only the insets and the motion
          // preference are layered on top, and both belong to `MediaQuery`,
          // which is where the app reads them from too.
          final inherited = MediaQuery.of(context);
          return MediaQuery(
            data: inherited.copyWith(
              padding: viewPadding,
              disableAnimations: disableAnimations,
            ),
            child: Stack(
              children: [MissionCompanion(controllerFactory: () => scene)],
            ),
          );
        },
      ),
    ),
  );
  // Two frames: one to run the post-frame scene build, one to commit the
  // starting position.
  await tester.pump();
  await tester.pump();
  return (
    scene: scene,
    container: ProviderScope.containerOf(
      tester.element(find.byType(MissionCompanion)),
    ),
  );
}

/// Takes the tree down at the end of a test.
///
/// This belongs inside the test body rather than in a teardown, because the
/// pending-timer check runs before teardowns. Unmounting the companion disposes
/// its controller, and that is what cancels the flight-style timer and the park
/// hold a throw starts.
///
/// `pumpAndSettle` is not an option: the frame clock is a ticker that runs for
/// as long as the widget is mounted, so there is never a settled frame to wait
/// for.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

/// The far corner the toy may reach on the phone-sized viewport these tests use.
///
/// Derived once here so every test throws into the same region the widget
/// derives, rather than each one restating the arithmetic and drifting.
final _bounds = Offset(
  400 - kCompanionBoxWidth - 8,
  800 - kCompanionBoxHeight - 8,
);

/// How far the toy got from where it was released, over a fixed run of frames.
Future<double> _peakTravel(
  ProviderContainer container,
  WidgetTester tester,
  Duration frame,
) async {
  var peak = 0.0;
  final start = container.read(avatarControllerProvider).screenPosition!.dx;
  for (var i = 0; i < 20; i++) {
    await tester.pump(frame);
    final dx = container.read(avatarControllerProvider).screenPosition!.dx;
    if (dx - start > peak) peak = dx - start;
  }
  return peak;
}

void main() {
  const frame = Duration(milliseconds: 16);

  group('a released fling actually moves', () {
    testWidgets('the toy keeps travelling after the finger lifts', (
      tester,
    ) async {
      final container = (await _pump(tester)).container;
      final notifier = container.read(avatarControllerProvider.notifier);

      // Placed and thrown inside one interaction, with no frame in between.
      // A pump here would give the idle flight circuit a frame to write its own
      // position over the placement, and the throw would leave from the home
      // corner instead of from where the toy was let go.
      notifier.placeAt(const Offset(40, 400), maxPosition: _bounds);
      final before = container.read(avatarControllerProvider).screenPosition!;

      notifier.launchWithVelocity(
        velocity: const Offset(1200, 0),
        maxPosition: _bounds,
        minPosition: const Offset(8, 105),
      );
      expect(notifier.isThrowing, isTrue);

      // A launched companion is parked as well as moving, so the frame loop
      // used to return before anything integrated the velocity and the toy
      // stopped exactly where it was let go. This is the regression that made a
      // flick feel like a drop.
      await tester.pump(frame);
      await tester.pump(frame);

      final after = container.read(avatarControllerProvider).screenPosition!;
      expect(
        after.dx,
        greaterThan(before.dx),
        reason: 'the toy is still moving after the release',
      );
      expect(
        container.read(avatarControllerProvider).velocity,
        isNot(Offset.zero),
      );

      // Let the tree go: see [_finish].
      await _finish(tester);
    });

    testWidgets('the toy settles rather than drifting forever', (tester) async {
      final container = (await _pump(tester)).container;
      final notifier = container.read(avatarControllerProvider.notifier);

      notifier.launchWithVelocity(
        velocity: const Offset(1500, 900),
        maxPosition: _bounds,
        minPosition: const Offset(8, 105),
      );

      // A repeating ticker never settles on its own, so this is only true if
      // the simulation reaches its own stop and the frame loop lets go of it.
      for (var i = 0; i < 2000 && notifier.isThrowing; i++) {
        await tester.pump(frame);
      }

      expect(notifier.isThrowing, isFalse);
      expect(container.read(avatarControllerProvider).velocity, Offset.zero);

      // Let the tree go: see [_finish].
      await _finish(tester);
    });

    testWidgets('the toy stays clear of the bars while it bounces', (
      tester,
    ) async {
      final container = (await _pump(
        tester,
        viewPadding: const EdgeInsets.only(top: 47),
      )).container;
      final notifier = container.read(avatarControllerProvider.notifier);

      // The bounds the widget derives for itself, rather than a second copy of
      // the arithmetic: this asserts the toy stayed inside the region it was
      // actually given, and still fails if that region is wrong.
      final safeArea = CompanionSafeArea.forViewport(
        const Size(400, 800),
        const EdgeInsets.only(top: 47),
      );

      notifier.launchWithVelocity(
        velocity: const Offset(-2500, -2500),
        maxPosition: safeArea.max,
        minPosition: safeArea.min,
      );

      for (var i = 0; i < 400; i++) {
        await tester.pump(frame);
        final position = container
            .read(avatarControllerProvider)
            .screenPosition!;
        expect(
          position.dx,
          inInclusiveRange(safeArea.min.dx, safeArea.max.dx),
          reason: 'escaped the left or right edge at frame $i',
        );
        expect(
          position.dy,
          inInclusiveRange(safeArea.min.dy, safeArea.max.dy),
          reason: 'settled behind a bar at frame $i',
        );
      }

      // Let the tree go: see [_finish].
      await _finish(tester);
    });
  });

  group('a drag stays inside the region the bars leave', () {
    testWidgets('the toy cannot be dragged under the status bar or off the '
        'left edge', (tester) async {
      final container = (await _pump(
        tester,
        viewPadding: const EdgeInsets.only(top: 47),
      )).container;
      final notifier = container.read(avatarControllerProvider.notifier);
      final safeArea = CompanionSafeArea.forViewport(
        const Size(400, 800),
        const EdgeInsets.only(top: 47),
      );

      notifier.placeAt(safeArea.max, maxPosition: safeArea.max);

      // A long drag in one direction, well past every edge. A companion that
      // only respected the far corner would end up under the status bar and the
      // top bar, where the child could not see it or grab it again.
      for (var i = 0; i < 20; i++) {
        notifier.moveBy(
          delta: const Offset(-120, -120),
          maxPosition: safeArea.max,
          minPosition: safeArea.min,
        );
      }

      final position = container.read(avatarControllerProvider).screenPosition!;
      expect(position.dx, safeArea.min.dx);
      expect(position.dy, safeArea.min.dy);

      // And the other way, so neither edge is a one-way clamp.
      for (var i = 0; i < 40; i++) {
        notifier.moveBy(
          delta: const Offset(120, 120),
          maxPosition: safeArea.max,
          minPosition: safeArea.min,
        );
      }
      final other = container.read(avatarControllerProvider).screenPosition!;
      expect(other.dx, safeArea.max.dx);
      expect(other.dy, safeArea.max.dy);

      // Let the park hold go before the tree goes, as [_finish] expects.
      await tester.pump(const Duration(seconds: 11));

      // Let the tree go: see [_finish].
      await _finish(tester);
    });
  });

  group('an impact reaches the 3D layer', () {
    testWidgets('a hard throw squashes the body and then lets it go', (
      tester,
    ) async {
      final harness = await _pump(tester);
      final notifier = harness.container.read(
        avatarControllerProvider.notifier,
      );

      notifier.launchWithVelocity(
        velocity: const Offset(2600, 0),
        maxPosition: _bounds,
        minPosition: const Offset(8, 105),
      );

      for (var i = 0; i < 40 && harness.scene.squashes.isEmpty; i++) {
        await tester.pump(frame);
      }

      expect(
        harness.scene.squashes,
        isNotEmpty,
        reason: 'the toy hit a wall and nothing reacted',
      );
      // A squash is a deformation, so it has to be less than one, and a
      // released toy has to be given back to full size.
      expect(harness.scene.squashes.first, lessThan(1.0));

      // Bounded, not `pumpAndSettle`: the frame clock never settles while the
      // companion is mounted, so the wait has to be for the squash's own
      // duration rather than for the tree to go quiet.
      await tester.pump(AvatarPhysicsConfig.impactDuration * 2);
      expect(harness.scene.squashes.last, 1.0);

      // Let the tree go: see [_finish].
      await _finish(tester);
    });

    testWidgets('a throw too slow to bounce does not squash', (tester) async {
      final harness = await _pump(tester);
      final notifier = harness.container.read(
        avatarControllerProvider.notifier,
      );

      notifier.placeAt(const Offset(40, 400), maxPosition: _bounds);
      notifier.launchWithVelocity(
        velocity: const Offset(AvatarPhysicsConfig.minThrowVelocity + 10, 0),
        maxPosition: _bounds,
        minPosition: const Offset(8, 105),
      );

      for (var i = 0; i < 10; i++) {
        await tester.pump(frame);
      }

      // Below the impact threshold the toy is settling, not bouncing, and
      // squashing each of those would turn the end of a throw into a rattle.
      expect(harness.scene.squashes.where((s) => s < 1.0), isEmpty);

      // Let the tree go: see [_finish].
      await _finish(tester);
    });
  });

  group('reduced motion', () {
    testWidgets('a throw is calmer but still happens', (tester) async {
      final normal = (await _pump(tester)).container;
      normal.read(avatarControllerProvider.notifier)
        // Left edge, thrown right, so the toy has somewhere to go: released
        // from the edge it starts on, the first frame of travel only ever gets
        // taken away by the wall it is already against.
        ..placeAt(const Offset(40, 400), maxPosition: _bounds)
        ..launchWithVelocity(
          velocity: const Offset(2400, 0),
          maxPosition: _bounds,
          minPosition: const Offset(8, 105),
        );
      final normalPeak = await _peakTravel(normal, tester, frame);

      final calm = (await _pump(tester, disableAnimations: true)).container;
      calm.read(avatarControllerProvider.notifier)
        ..placeAt(const Offset(40, 400), maxPosition: _bounds)
        ..launchWithVelocity(
          velocity: const Offset(2400, 0),
          maxPosition: _bounds,
          minPosition: const Offset(8, 105),
        );
      final calmPeak = await _peakTravel(calm, tester, frame);

      // Peak travel, rather than where the toy ended up: at full strength this
      // throw crosses the screen and comes back off the far wall, so its final
      // position can be closer to the start than a calmer throw's. Comparing
      // endpoints would test where the toy happened to stop, not how far it
      // went.
      //
      // Removing the throw altogether would be worse than a calmer one: the
      // child flicked, and the toy has to go somewhere.
      expect(calmPeak, greaterThan(0));
      expect(calmPeak, lessThan(normalPeak));

      // Let the tree go: see [_finish].
      await _finish(tester);
    });
  });
}
