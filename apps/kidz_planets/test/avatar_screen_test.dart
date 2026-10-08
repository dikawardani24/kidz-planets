import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avatar/scene.dart';
import 'package:avatar/state.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:kidz_planets/presentation/screens/avatar_screen.dart';
import 'package:kidz_planets/presentation/widgets/panels/mission_companion.dart';

import 'helpers/localized_app.dart';

/// A stand-in for the GPU-backed avatar scene.
///
/// Records which bodies the UI asked for so the tests can prove the preview
/// and the companion follow the selection, not just the state object.
class _FakeScene implements AvatarSceneController {
  final List<AvatarType> requestedTypes = [];

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
  Future<void> setAvatarType(AvatarType type) async {
    requestedTypes.add(type);
  }

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
  void setImpactSquash(double scale) {}

  @override
  void showTarget({required bool visible, required Color color}) {}

  @override
  void dispose() {}
}

Future<ProviderContainer> _pumpPage(
  WidgetTester tester,
  _FakeScene scene,
) async {
  await tester.pumpWidget(
    localizedApp(Scaffold(body: AvatarScreen(controllerFactory: () => scene))),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(AvatarScreen)));
}

void main() {
  group('AvatarScreen', () {
    testWidgets('shows the stage, both choices and the select action', (
      tester,
    ) async {
      await _pumpPage(tester, _FakeScene());

      expect(find.text('My Avatar'), findsOneWidget);
      expect(find.text('🚀'), findsOneWidget);
      expect(find.text('👨‍🚀'), findsOneWidget);
      expect(find.text('Rocket'), findsOneWidget);
      expect(find.text('Astronaut'), findsOneWidget);
      expect(find.text('Select Avatar'), findsOneWidget);
      // The saved choice carries the badge from the start.
      expect(find.text('Current'), findsOneWidget);
    });

    testWidgets('tapping a card previews that avatar', (tester) async {
      final scene = _FakeScene();
      await _pumpPage(tester, scene);

      await tester.tap(find.text('👨‍🚀'));
      await tester.pumpAndSettle();

      expect(scene.requestedTypes, contains(AvatarType.astronaut));
      // Nothing is saved by previewing: the badge stays on the rocket.
      expect(find.text('Current'), findsOneWidget);
    });

    testWidgets('select saves the previewed avatar and leaves the page', (
      tester,
    ) async {
      final scene = _FakeScene();
      final container = await _pumpPage(tester, scene);
      container.read(appShellProvider.notifier).openAvatarPage();

      await tester.tap(find.text('👨‍🚀'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select Avatar'));
      // No settle: the button shows an indeterminate spinner until the page
      // unmounts, which never happens in this direct pump.
      await tester.pump();
      await tester.pump();

      expect(container.read(avatarSelectionProvider), AvatarType.astronaut);
      expect(container.read(appShellProvider).avatarPageVisible, isFalse);
    });

    testWidgets('back leaves without saving', (tester) async {
      final container = await _pumpPage(tester, _FakeScene());
      container.read(appShellProvider.notifier).openAvatarPage();

      await tester.tap(find.text('👨‍🚀'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(container.read(avatarSelectionProvider), AvatarType.rocket);
      expect(container.read(appShellProvider).avatarPageVisible, isFalse);
    });

    testWidgets('switching back and forth previews each body once', (
      tester,
    ) async {
      final scene = _FakeScene();
      await _pumpPage(tester, scene);

      await tester.tap(find.text('👨‍🚀'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🚀'));
      await tester.pumpAndSettle();

      // Opening body plus one swap per card tap; re-tapping the staged card
      // is a no-op rather than a reload.
      expect(scene.requestedTypes, [
        AvatarType.rocket,
        AvatarType.astronaut,
        AvatarType.rocket,
      ]);
    });
  });

  group('MissionCompanion avatar switching', () {
    testWidgets('a new selection reaches the Explorer scene', (tester) async {
      final scene = _FakeScene();
      await tester.pumpWidget(
        localizedApp(
          Scaffold(body: MissionCompanion(controllerFactory: () => scene)),
        ),
      );
      await tester.pump();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MissionCompanion)),
      );

      await container
          .read(avatarSelectionProvider.notifier)
          .select(AvatarType.astronaut);
      // No settle: the companion's frame ticker never stops, so existing
      // companion tests pump fixed frames instead.
      await tester.pump();
      await tester.pump();

      expect(scene.requestedTypes, contains(AvatarType.astronaut));
      expect(tester.takeException(), isNull);
    });
  });
}
