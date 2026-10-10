import 'package:avatar/scene.dart';
import 'package:avatar/state.dart';
import 'package:core/l10n.dart';
import 'package:core/platform.dart';
import 'package:core/time.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets/state.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:kidz_planets/application/state/providers.dart';
import 'package:kidz_planets/presentation/screens/avatar_screen.dart';
import 'package:kidz_planets/presentation/tv/tv_explorer_controller.dart';
import 'package:kidz_planets/presentation/tv/tv_nav_target.dart';
import 'package:kidz_planets/presentation/tv/tv_providers.dart';
import 'package:kidz_planets/presentation/tv/tv_remote_handler.dart';

/// A stand-in for the GPU-backed avatar scene.
class _FakeAvatarScene implements AvatarSceneController {
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

/// Camera-free stand-in for the Explore scene.
class _FakeTvScene implements TvSceneOps {
  PerspectiveCamera camera = PerspectiveCamera(
    fovRadiansY: 0.85,
    position: vm.Vector3(0, 0, 46),
    target: vm.Vector3.zero(),
    up: vm.Vector3(0, 1, 0),
  );

  final List<String> flightRequests = [];

  @override
  void rotateView(double dxPx, double dyPx) {}
  @override
  void rotateObject(String planetId, double dxPx, double dyPx) {}
  @override
  void pinchTowardBody(double scaleFactor, String planetId) {}
  @override
  PerspectiveCamera buildCamera(ExplorerState ui) => camera;
  @override
  bool shouldAutoEnterDetail(String planetId, PerspectiveCamera camera) =>
      false;
  @override
  double prepareSeamlessSelection(String planetId, PerspectiveCamera camera) =>
      0.8;
  @override
  double markZoomProgress(String planetId, PerspectiveCamera camera) => 0;
  @override
  void cancelZoomFlight() {}
  @override
  void resetOverview() {}
  @override
  void startZoomToDetail(String planetId, PerspectiveCamera camera) {
    flightRequests.add(planetId);
  }

  @override
  bool get zoomFlightActive => false;
  @override
  Offset? projectBodyCenter(
    String planetId,
    PerspectiveCamera camera,
    Size viewSize,
  ) => null;
}

class _Harness {
  _Harness({
    required this.container,
    required this.tv,
    required this.explorer,
    required this.tvScene,
    required this.avatarScene,
  });

  final ProviderContainer container;
  final TvExplorerController tv;
  final ExplorerController explorer;
  final _FakeTvScene tvScene;
  final _FakeAvatarScene avatarScene;
}

/// Pumps the production stack — Explore background plus the avatar overlay —
/// under the real [TvRemoteHandler] in TV mode.
Future<_Harness> _pumpAvatarTv(WidgetTester tester) async {
  tester.view.physicalSize =
      const Size(800, 1200) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final explorer = ExplorerController(clock: SimulationClock());
  final tvScene = _FakeTvScene();
  final avatarScene = _FakeAvatarScene();
  final tv = TvExplorerController(
    explorer: explorer,
    scene: tvScene,
    bodyIds: const ['mercury', 'venus', 'earth', 'mars'],
    replayNarration: (_) {},
    selectDebounce: Duration.zero,
    hintTimeout: const Duration(milliseconds: 50),
    chromeTimeout: const Duration(milliseconds: 50),
  );
  final container = ProviderContainer(
    overrides: [
      tvModeOverrideProvider.overrideWith((ref) => true),
      explorerControllerProvider.overrideWith((ref) => explorer),
      tvSceneOpsProvider.overrideWith((ref) => tvScene),
      tvExplorerControllerProvider.overrideWith((ref) => tv),
    ],
  );
  addTearDown(container.dispose);
  // A background TV control below the overlay: if D-pad focus ever escapes
  // the avatar page, traversal can land here and the tests below catch it.
  // The avatar opener mirrors the production top bar: registered in Menu
  // Mode, parked out in Planet Mode, and the restore target on close.
  final openerCalls = <int>[];
  Widget backgroundProbe() => Positioned(
    left: 40,
    right: 40,
    bottom: 8,
    height: 40,
    child: TvFocusable(onSelect: () {}, child: const SizedBox.expand()),
  );
  Widget backgroundOpener() => Positioned.fromRect(
    rect: const Rect.fromLTWH(80, 60, 56, 56),
    child: TvNavTarget(
      id: 'chrome:avatar',
      control: TvChromeControl.other,
      onSelect: () => openerCalls.add(1),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: kSupportedLocales,
        home: TvRemoteHandler(
          child: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                backgroundProbe(),
                backgroundOpener(),
                Consumer(
                  builder: (context, ref, _) {
                    final open = ref.watch(
                      appShellProvider.select((s) => s.avatarPageVisible),
                    );
                    if (!open) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: AvatarScreen(controllerFactory: () => avatarScene),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return _Harness(
    container: container,
    tv: tv,
    explorer: explorer,
    tvScene: tvScene,
    avatarScene: avatarScene,
  );
}

Future<void> _openPage(WidgetTester tester, _Harness h) async {
  h.container.read(appShellProvider.notifier).openAvatarPage();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Sends a raw remote key exactly as Android delivers it, settling frames.
Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Whether the focused control lives inside the avatar page.
bool _avatarOwnsFocus(WidgetTester tester) {
  final detectors = tester.widgetList<FocusableActionDetector>(
    find.descendant(
      of: find.byType(AvatarScreen),
      matching: find.byType(FocusableActionDetector),
    ),
  );
  final primary = FocusManager.instance.primaryFocus;
  if (primary == null) return false;
  return detectors.any((d) => identical(d.focusNode, primary));
}

/// Whether the avatar card showing [emoji] currently holds primary focus.
bool _cardFocused(WidgetTester tester, String emoji) {
  final detector = tester.widget<FocusableActionDetector>(
    find.ancestor(
      of: find.text(emoji),
      matching: find.byType(FocusableActionDetector),
    ),
  );
  final node = detector.focusNode;
  return node != null && node.hasPrimaryFocus;
}

/// Whether the big select action currently holds primary focus.
bool _selectFocused(WidgetTester tester) {
  final detector = tester.widget<FocusableActionDetector>(
    find.ancestor(
      of: find.text('Select Avatar'),
      matching: find.byType(FocusableActionDetector),
    ),
  );
  final node = detector.focusNode;
  return node != null && node.hasPrimaryFocus;
}

void main() {
  group('avatar TV navigation', () {
    testWidgets('opening focuses the equipped avatar card', (tester) async {
      final h = await _pumpAvatarTv(tester);
      await _openPage(tester, h);

      expect(find.byType(AvatarScreen), findsOneWidget);
      expect(_avatarOwnsFocus(tester), isTrue);
      expect(_cardFocused(tester, '🚀'), isTrue);
    });

    testWidgets('left/right moves between cards without equipping', (
      tester,
    ) async {
      final h = await _pumpAvatarTv(tester);
      await _openPage(tester, h);

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_cardFocused(tester, '👨‍🚀'), isTrue);
      expect(_avatarOwnsFocus(tester), isTrue);
      // Focus moved only: nothing saved, nothing staged away.
      expect(h.container.read(avatarSelectionProvider), AvatarType.rocket);

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_cardFocused(tester, '🚀'), isTrue);
      expect(h.container.read(avatarSelectionProvider), AvatarType.rocket);
    });

    testWidgets('OK on a card previews without saving', (tester) async {
      final h = await _pumpAvatarTv(tester);
      await _openPage(tester, h);

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.select);

      expect(h.avatarScene.requestedTypes, contains(AvatarType.astronaut));
      // Previewed, not equipped: the badge stays on the rocket.
      expect(h.container.read(avatarSelectionProvider), AvatarType.rocket);
      expect(find.text('Current'), findsOneWidget);
      expect(h.container.read(appShellProvider).avatarPageVisible, isTrue);
    });

    testWidgets('down reaches Select and OK commits the staged choice', (
      tester,
    ) async {
      final h = await _pumpAvatarTv(tester);
      await _openPage(tester, h);

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.select);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_selectFocused(tester), isTrue);

      await _press(tester, LogicalKeyboardKey.select);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(h.container.read(avatarSelectionProvider), AvatarType.astronaut);
      expect(h.container.read(appShellProvider).avatarPageVisible, isFalse);
    });

    testWidgets('up reaches Back and OK leaves without saving', (tester) async {
      final h = await _pumpAvatarTv(tester);
      await _openPage(tester, h);

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.select);
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_avatarOwnsFocus(tester), isTrue);

      await _press(tester, LogicalKeyboardKey.select);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(h.container.read(avatarSelectionProvider), AvatarType.rocket);
      expect(h.container.read(appShellProvider).avatarPageVisible, isFalse);
    });

    testWidgets('D-pad never drives Explore behind the overlay', (
      tester,
    ) async {
      final h = await _pumpAvatarTv(tester);
      await _openPage(tester, h);

      for (final key in const [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ]) {
        await _press(tester, key);
      }
      await _press(tester, LogicalKeyboardKey.select);

      expect(h.explorer.state.markedTargetId, isNull);
      expect(h.explorer.state.selectedPlanetId, isNull);
      expect(h.tvScene.flightRequests, isEmpty);
      // Focus never escaped to the background probe or the scene scope.
      expect(_avatarOwnsFocus(tester), isTrue);
    });

    testWidgets('BACK closes once and restores valid Explore focus', (
      tester,
    ) async {
      final h = await _pumpAvatarTv(tester);
      await _openPage(tester, h);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.select);

      await _press(tester, LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Closed exactly once, staged choice discarded.
      expect(h.container.read(appShellProvider).avatarPageVisible, isFalse);
      expect(h.container.read(avatarSelectionProvider), AvatarType.rocket);
      // Nothing unwound behind the overlay.
      expect(h.explorer.state.markedTargetId, isNull);
      expect(h.explorer.state.selectedPlanetId, isNull);
      // A second BACK finds no page and stays harmless.
      await _press(tester, LogicalKeyboardKey.escape);
      expect(h.container.read(appShellProvider).avatarPageVisible, isFalse);
      // Focus is back on the Explore scene scope: valid, live, and never a
      // disposed avatar node.
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tvScene');
      expect(tester.takeException(), isNull);
    });

    testWidgets('BACK in Menu Mode restores focus to the opener', (
      tester,
    ) async {
      final h = await _pumpAvatarTv(tester);
      // Menu Mode behind the page: the opener registers and stays reachable.
      h.tv.switchToMenu();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await _openPage(tester, h);
      expect(_avatarOwnsFocus(tester), isTrue);

      await _press(tester, LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(h.container.read(appShellProvider).avatarPageVisible, isFalse);
      expect(h.tv.state.focusMode, TvFocusMode.menu);
      // The opener (top-bar avatar button id) owns the cursor again, the
      // detail-free Explore state is untouched, and nothing fired behind us.
      expect(h.tv.state.spatialFocusId, 'chrome:avatar');
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'tvTarget:chrome:avatar',
      );
      expect(h.explorer.state.markedTargetId, isNull);
      expect(h.explorer.state.selectedPlanetId, isNull);
      expect(h.tvScene.flightRequests, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reopening leaves no stale or duplicated focus', (
      tester,
    ) async {
      final h = await _pumpAvatarTv(tester);
      await _openPage(tester, h);
      await _press(tester, LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await _openPage(tester, h);

      expect(find.byType(AvatarScreen), findsOneWidget);
      expect(_cardFocused(tester, '🚀'), isTrue);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_cardFocused(tester, '👨‍🚀'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('focus ring and equipped badge stay distinct', (tester) async {
      final h = await _pumpAvatarTv(tester);
      await _openPage(tester, h);

      // Move focus to the astronaut while the rocket stays equipped.
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_cardFocused(tester, '👨‍🚀'), isTrue);
      // The badge still marks the rocket card, not the focused one.
      final badge = find.text('Current');
      expect(badge, findsOneWidget);
      final badgeCard = find.ancestor(
        of: badge,
        matching: find.byType(FocusableActionDetector),
      );
      final rocketCard = find.ancestor(
        of: find.text('🚀'),
        matching: find.byType(FocusableActionDetector),
      );
      expect(badgeCard, findsOneWidget);
      expect(
        tester.widget<FocusableActionDetector>(badgeCard).focusNode,
        same(tester.widget<FocusableActionDetector>(rocketCard).focusNode),
      );
    });

    testWidgets('touch taps keep working in TV mode', (tester) async {
      final h = await _pumpAvatarTv(tester);
      await _openPage(tester, h);

      await tester.tap(find.text('👨‍🚀'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.avatarScene.requestedTypes, contains(AvatarType.astronaut));
      expect(h.container.read(avatarSelectionProvider), AvatarType.rocket);
    });
  });
}
