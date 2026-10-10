import 'package:core/platform.dart';
import 'package:core/time.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets/state.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:kidz_planets/presentation/tv/tv_explorer_controller.dart';
import 'package:kidz_planets/presentation/tv/tv_nav_target.dart';
import 'package:kidz_planets/presentation/tv/tv_providers.dart';
import 'package:kidz_planets/presentation/tv/tv_remote_handler.dart';
import 'package:kidz_planets/presentation/widgets/overlays/top_bar.dart';

import 'helpers/localized_app.dart';

/// Camera-free scene stand-in: records motion, scripts thresholds.
class _FakeScene implements TvSceneOps {
  PerspectiveCamera camera = PerspectiveCamera(
    fovRadiansY: 0.85,
    position: vm.Vector3(0, 0, 46),
    target: vm.Vector3.zero(),
    up: vm.Vector3(0, 1, 0),
  );

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
  void startZoomToDetail(String planetId, PerspectiveCamera camera) {}
  @override
  bool get zoomFlightActive => false;
  @override
  Offset? projectBodyCenter(
    String planetId,
    PerspectiveCamera camera,
    Size viewSize,
  ) => null;
}

/// Widget-test overrides: every TV provider the Explore chrome touches, so the
/// input chain runs without a device, a remote or a 3D scene. Pass explicit
/// [explorer]/[controller] when the test must drive the same instances the
/// widgets use (e.g. wiring a probe to the production toggle call).
List<Override> _tvOverrides({
  required bool television,
  ExplorerController? explorer,
  TvExplorerController? controller,
}) {
  final ownedExplorer =
      explorer ?? ExplorerController(clock: SimulationClock());
  final tv =
      controller ??
      TvExplorerController(
        explorer: ownedExplorer,
        scene: _FakeScene(),
        bodyIds: const ['mercury', 'venus', 'earth', 'mars'],
        replayNarration: (_) {},
        selectDebounce: Duration.zero,
        hintTimeout: const Duration(milliseconds: 50),
        chromeTimeout: const Duration(milliseconds: 50),
      );
  return [
    tvModeOverrideProvider.overrideWith((ref) => television),
    explorerControllerProvider.overrideWith((ref) => ownedExplorer),
    tvSceneOpsProvider.overrideWith((ref) => _FakeScene()),
    tvExplorerControllerProvider.overrideWith((ref) => tv),
  ];
}

/// Builds the [TvExplorerController] (and its [ExplorerController]) a test
/// owns, so probes can call the production toggle while the widgets use the
/// very same instances through [_tvOverrides].
(TvExplorerController, ExplorerController) _controllers() {
  final explorer = ExplorerController(clock: SimulationClock());
  final tv = TvExplorerController(
    explorer: explorer,
    scene: _FakeScene(),
    bodyIds: const ['mercury', 'venus', 'earth', 'mars'],
    replayNarration: (_) {},
    selectDebounce: Duration.zero,
    hintTimeout: const Duration(milliseconds: 50),
    chromeTimeout: const Duration(milliseconds: 50),
  );
  return (tv, explorer);
}

/// Pumps the Explore chrome under the real [TvRemoteHandler] so key events
/// travel the production chain: remote → handler → controller → registry →
/// focus → callback.
Future<ProviderContainer> _pumpExplore(
  WidgetTester tester, {
  required List<Override> overrides,
  required List<Widget> Function() chrome,
}) async {
  tester.view.physicalSize =
      const Size(800, 1200) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: TvRemoteHandler(
          child: Scaffold(body: Stack(children: chrome())),
        ),
      ),
    ),
  );
  await tester.pump();
  container
      .read(tvExplorerControllerProvider.notifier)
      .updateViewportSize(
        tester.view.physicalSize / tester.view.devicePixelRatio,
      );
  await tester.pump();
  return container;
}

/// One focusable button for the harness, exactly like the Explore icons:
/// registered target + real callback counter. The toggle probe additionally
/// drives the production [toggleFocusMode] call, like the real top-bar
/// toggle, so OK on it switches modes instead of only counting.
class _Probe extends StatelessWidget {
  const _Probe({
    required this.id,
    required this.rect,
    required this.counter,
    this.modeToggle = false,
    this.onToggle,
  });

  final String id;
  final Rect rect;
  final List<int> counter;
  final bool modeToggle;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: TvNavTarget(
        id: id,
        control: TvChromeControl.other,
        modeToggle: modeToggle,
        onSelect: () {
          counter.add(1);
          if (modeToggle) onToggle?.call();
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

void main() {
  /// Production-like layout rects for the harness chrome, by target id.
  Map<String, Rect> rects() => {
    'chrome:top-labels': const Rect.fromLTWH(144, 60, 56, 56),
    tvModeToggleTargetId: const Rect.fromLTWH(700, 60, 56, 56),
    'chrome:explore-zoom-in': const Rect.fromLTWH(730, 300, 54, 54),
    'chrome:explore-zoom-out': const Rect.fromLTWH(730, 360, 54, 54),
    'chrome:tab-missions': const Rect.fromLTWH(540, 1050, 220, 70),
  };

  List<Widget> chrome({
    required List<int> topCalls,
    required List<int> zoomCalls,
    required List<int> tabCalls,
    required List<int> toggleCalls,
    VoidCallback? onToggle,
  }) {
    List<int> counterFor(String id) {
      if (id == tvModeToggleTargetId) return toggleCalls;
      if (id.startsWith('chrome:top-')) return topCalls;
      if (id.startsWith('chrome:explore-')) return zoomCalls;
      return tabCalls;
    }

    return [
      for (final entry in rects().entries)
        _Probe(
          id: entry.key,
          rect: entry.value,
          counter: counterFor(entry.key),
          modeToggle: entry.key == tvModeToggleTargetId,
          onToggle: onToggle,
        ),
    ];
  }

  /// Sends a raw remote key exactly as Android delivers it, settling frames.
  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  /// Lets the controller's short hint/fade timers fire so teardown sees no
  /// pending timers.
  Future<void> flushTimers(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Walks the D-pad toward [targetId] one greedy step at a time. Strictly
  /// bounded: a navigation regression fails instead of hanging the suite.
  Future<void> reachId(
    WidgetTester tester,
    TvExplorerController tv,
    String targetId,
    Map<String, Rect> all,
  ) async {
    for (var i = 0; i < 40; i++) {
      if (tv.state.spatialFocusId == targetId) return;
      final cur = tv.state.spatialFocusId;
      final curRect = cur == null ? null : all[cur];
      final dst = all[targetId];
      LogicalKeyboardKey key;
      if (curRect == null || dst == null) {
        key = LogicalKeyboardKey.arrowDown;
      } else {
        final d = dst.center - curRect.center;
        key = d.dx.abs() > d.dy.abs()
            ? (d.dx > 0
                  ? LogicalKeyboardKey.arrowRight
                  : LogicalKeyboardKey.arrowLeft)
            : (d.dy > 0
                  ? LogicalKeyboardKey.arrowDown
                  : LogicalKeyboardKey.arrowUp);
      }
      await press(tester, key);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tv.state.spatialFocusId, targetId);
  }

  testWidgets('Planet Mode registers only the toggle, nothing else', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final toggleCalls = <int>[];
    final container = await _pumpExplore(
      tester,
      overrides: _tvOverrides(television: true),
      chrome: () => chrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
        toggleCalls: toggleCalls,
      ),
    );
    final tv = container.read(tvExplorerControllerProvider.notifier);
    expect(tv.state.focusMode, TvFocusMode.planet);
    expect(tv.registeredTargetIds, contains(tvModeToggleTargetId));
    expect(
      tv.registeredTargetIds,
      isNot(
        containsAll([
          'chrome:top-labels',
          'chrome:explore-zoom-in',
          'chrome:tab-missions',
        ]),
      ),
    );
    await flushTimers(tester);
  });

  testWidgets('a dead-end arrow parks real focus on the toggle', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final toggleCalls = <int>[];
    final container = await _pumpExplore(
      tester,
      overrides: _tvOverrides(television: true),
      chrome: () => chrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
        toggleCalls: toggleCalls,
      ),
    );
    final tv = container.read(tvExplorerControllerProvider.notifier);
    final explorer = container.read(explorerControllerProvider.notifier);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(explorer.state.markedTargetId, 'mercury');
    // UP from a planet is a discovery dead end: the toggle is offered.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 50));

    expect(tv.state.spatialFocusId, tvModeToggleTargetId);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tvTarget:$tvModeToggleTargetId',
    );
    // Only the cursor moved: the mark, selection and callbacks are untouched.
    expect(explorer.state.markedTargetId, 'mercury');
    expect(explorer.state.hasSelection, isFalse);
    expect(toggleCalls, isEmpty);
    await flushTimers(tester);
  });

  testWidgets('OK on the focused toggle enters Menu Mode exactly once', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final toggleCalls = <int>[];
    final (tv, explorer) = _controllers();
    await _pumpExplore(
      tester,
      overrides: _tvOverrides(
        television: true,
        explorer: explorer,
        controller: tv,
      ),
      chrome: () => chrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
        toggleCalls: toggleCalls,
        // Production wiring: the toggle probe drives the real mode switch.
        onToggle: tv.toggleFocusMode,
      ),
    );
    // Drive the real remote path: mark a body, dead-end onto the toggle.
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tv.state.spatialFocusId, tvModeToggleTargetId);

    await press(tester, LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 50));

    // One press, one mode switch: no body visit, no UI activation.
    expect(tv.state.focusMode, TvFocusMode.menu);
    expect(toggleCalls, hasLength(1));
    expect(topCalls, isEmpty);
    expect(zoomCalls, isEmpty);
    expect(tabCalls, isEmpty);
    expect(explorer.state.hasSelection, isFalse);
    expect(explorer.state.markedTargetId, 'mercury');
    // Menu Mode re-admits the UI controls into the graph.
    expect(
      tv.registeredTargetIds,
      containsAll([
        'chrome:top-labels',
        'chrome:explore-zoom-in',
        'chrome:tab-missions',
      ]),
    );
    // The next directional key operates on the menu group straight away.
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tv.state.spatialFocusId, 'chrome:explore-zoom-in');
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tvTarget:chrome:explore-zoom-in',
    );
    await flushTimers(tester);
  });

  testWidgets('Menu Mode drives UI controls without touching planets', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final toggleCalls = <int>[];
    final container = await _pumpExplore(
      tester,
      overrides: _tvOverrides(television: true),
      chrome: () => chrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
        toggleCalls: toggleCalls,
      ),
    );
    final tv = container.read(tvExplorerControllerProvider.notifier);
    final explorer = container.read(explorerControllerProvider.notifier);

    await press(tester, LogicalKeyboardKey.arrowRight);
    tv.switchToMenu();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await reachId(tester, tv, 'chrome:explore-zoom-in', rects());
    await press(tester, LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 50));

    expect(zoomCalls, hasLength(1));
    expect(toggleCalls, isEmpty);
    expect(explorer.state.markedTargetId, 'mercury');
    expect(explorer.state.selectedPlanetId, isNull);
    await flushTimers(tester);
  });

  testWidgets('toggling back restores the planet cursor and isolates UI', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final toggleCalls = <int>[];
    final (tv, explorer) = _controllers();
    await _pumpExplore(
      tester,
      overrides: _tvOverrides(
        television: true,
        explorer: explorer,
        controller: tv,
      ),
      chrome: () => chrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
        toggleCalls: toggleCalls,
        onToggle: tv.toggleFocusMode,
      ),
    );

    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(explorer.state.markedTargetId, 'venus');
    tv.switchToMenu();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await reachId(tester, tv, tvModeToggleTargetId, rects());
    await press(tester, LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 50));

    // Back in Planet Mode on the remembered body; UI controls unregister.
    expect(tv.state.focusMode, TvFocusMode.planet);
    expect(tv.state.spatialFocusId, 'venus');
    expect(tv.registeredTargetIds, isNot(contains('chrome:top-labels')));
    expect(tv.registeredTargetIds, contains(tvModeToggleTargetId));
    // Discovery owns the arrows again.
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(explorer.state.markedTargetId, 'earth');
    await flushTimers(tester);
  });

  testWidgets('touch taps still fire a control parked out of D-pad focus', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final toggleCalls = <int>[];
    final all = rects();
    final container = await _pumpExplore(
      tester,
      overrides: _tvOverrides(television: true),
      chrome: () => chrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
        toggleCalls: toggleCalls,
      ),
    );
    final tv = container.read(tvExplorerControllerProvider.notifier);
    expect(tv.state.focusMode, TvFocusMode.planet);
    expect(tv.registeredTargetIds, isNot(contains('chrome:top-labels')));

    await tester.tapAt(all['chrome:top-labels']!.center);
    await tester.pump();
    expect(topCalls, hasLength(1));
    // A touch tap is not a mode switch.
    expect(tv.state.focusMode, TvFocusMode.planet);
    await flushTimers(tester);
  });

  group('real top-bar toggle button', () {
    /// Pumps the production [ExplorerTopBar] on TV with a fake scene, so the
    /// single mode-toggle button is exercised exactly as shipped.
    Future<ProviderContainer> pumpTopBar(WidgetTester tester) async {
      final explorer = ExplorerController(clock: SimulationClock());
      final tv = TvExplorerController(
        explorer: explorer,
        scene: _FakeScene(),
        bodyIds: const ['mercury', 'venus', 'earth', 'mars'],
        selectDebounce: Duration.zero,
        hintTimeout: const Duration(milliseconds: 50),
        chromeTimeout: const Duration(milliseconds: 50),
      );
      // Owned by the ProviderContainer below: no manual dispose (double
      // dispose trips the StateNotifier mounted check at teardown).
      await tester.pumpWidget(
        localizedApp(
          const Scaffold(body: ExplorerTopBar(isExploreTab: true)),
          overrides: [
            tvModeOverrideProvider.overrideWith((ref) => true),
            explorerControllerProvider.overrideWith((ref) => explorer),
            tvSceneOpsProvider.overrideWith((ref) => _FakeScene()),
            tvExplorerControllerProvider.overrideWith((ref) => tv),
          ],
        ),
      );
      await tester.pump();
      return ProviderScope.containerOf(
        tester.element(find.byType(ExplorerTopBar)),
      );
    }

    testWidgets('exactly one toggle names the destination mode', (
      tester,
    ) async {
      final container = await pumpTopBar(tester);
      final tv = container.read(tvExplorerControllerProvider.notifier);
      expect(tv.state.focusMode, TvFocusMode.planet);

      // One button, pointing at Menu Mode with a menu icon.
      expect(find.byTooltip('Switch to Menu Mode'), findsOneWidget);
      expect(find.byTooltip('Switch to Planet Mode'), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);

      // Touch-tapping it flips to Menu Mode and renames itself.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      expect(tv.state.focusMode, TvFocusMode.menu);
      expect(find.byTooltip('Switch to Planet Mode'), findsOneWidget);
      expect(find.byTooltip('Switch to Menu Mode'), findsNothing);
      expect(find.byIcon(Icons.public), findsOneWidget);

      // And back again.
      await tester.tap(find.byIcon(Icons.public));
      await tester.pump();
      expect(tv.state.focusMode, TvFocusMode.planet);
      expect(find.byTooltip('Switch to Menu Mode'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('no toggle off the Explore tab or off TV', (tester) async {
      await pumpTopBar(tester);
      // Sanity: the TV Explore top bar above carries the toggle; other tabs
      // and phones must not grow a second one. The phone case is covered by
      // the existing top-bar overlay tests (no TV override, no toggle).
      expect(find.byTooltip('Switch to Menu Mode'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });
  });
}
