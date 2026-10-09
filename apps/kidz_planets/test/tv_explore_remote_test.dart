import 'package:core/platform.dart';
import 'package:core/time.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission/state.dart';
import 'package:planets/state.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:kidz_planets/presentation/tv/tv_explorer_controller.dart';
import 'package:kidz_planets/presentation/tv/tv_nav_target.dart';
import 'package:kidz_planets/presentation/tv/tv_providers.dart';
import 'package:kidz_planets/presentation/tv/tv_remote_handler.dart';

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
/// input chain runs without a device, a remote or a 3D scene.
List<Override> tvOverrides({
  required bool television,
  TvExplorerController? controller,
}) {
  final explorer = ExplorerController(clock: SimulationClock());
  final tv =
      controller ??
      TvExplorerController(
        explorer: explorer,
        scene: _FakeScene(),
        bodyIds: const ['mercury', 'venus', 'earth', 'mars'],
        replayNarration: (_) {},
        // Short fades so widget-test teardown sees no pending timers; the
        // controller cancels these on dispose and never re-arms while UI
        // focus mode is active. Zero select debounce: pumps advance fake
        // async time but not the wall clock the debounce reads, so back to
        // back OK presses would otherwise collapse into one.
        selectDebounce: Duration.zero,
        hintTimeout: const Duration(milliseconds: 50),
        chromeTimeout: const Duration(milliseconds: 50),
      );
  return [
    tvModeOverrideProvider.overrideWith((ref) => television),
    explorerControllerProvider.overrideWith((ref) => explorer),
    tvSceneOpsProvider.overrideWith((ref) => _FakeScene()),
    tvExplorerControllerProvider.overrideWith((ref) => tv),
  ];
}

/// Pumps the Explore chrome under the real [TvRemoteHandler] so key events
/// travel the production chain: remote → handler → controller → registry →
/// focus → callback.
Future<ProviderContainer> pumpExplore(
  WidgetTester tester, {
  required List<Override> overrides,
  required List<Widget> Function() chrome,
}) async {
  tester.view.physicalSize = const Size(800, 1200) *
      tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: TvRemoteHandler(child: Scaffold(body: Stack(children: chrome()))),
      ),
    ),
  );
  await tester.pump();
  // What the production Explorer screen's LayoutBuilder feeds the controller:
  // logical viewport dimensions, so directional scoring runs in the same
  // coordinate space as the registered target centers. Without it, UI-mode
  // arrows early-return and the cursor never leaves its seed.
  container
      .read(tvExplorerControllerProvider.notifier)
      .updateViewportSize(
        tester.view.physicalSize / tester.view.devicePixelRatio,
      );
  // Mirrors the production wiring in tv_providers.dart that these overrides
  // bypass: on TV a detail hands the D-pad to UI focus mode, and leaving it
  // runs the detail cleanup.
  container.listen<ExplorerState>(explorerControllerProvider, (prev, next) {
    final was = prev?.hasSelection ?? false;
    if (was == next.hasSelection) return;
    final tv = container.read(tvExplorerControllerProvider.notifier);
    if (!next.hasSelection) {
      tv.exitDetailCleanup();
    } else if (container.read(isTelevisionProvider)) {
      tv.enterChrome(preferId: 'chrome:show-facts');
    }
  });
  await tester.pump();
  return container;
}

/// One focusable button for the harness, exactly like the Explore icons:
/// registered target + real callback counter.
class _Probe extends StatelessWidget {
  _Probe({
    required this.id,
    required this.rect,
    required this.counter,
  });

  final String id;
  final Rect rect;
  final List<int> counter;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: TvNavTarget(
        id: id,
        control: TvChromeControl.other,
        onSelect: () => counter.add(1),
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
  /// Production layout rects for the harness chrome, by target id.
  Map<String, Rect> exploreRects() => {
    'chrome:top-language': const Rect.fromLTWH(16, 60, 56, 56),
    'chrome:top-avatar': const Rect.fromLTWH(80, 60, 56, 56),
    'chrome:top-labels': const Rect.fromLTWH(144, 60, 56, 56),
    'chrome:explore-zoom-in': const Rect.fromLTWH(730, 300, 54, 54),
    'chrome:explore-zoom-out': const Rect.fromLTWH(730, 360, 54, 54),
    'chrome:explore-reset': const Rect.fromLTWH(730, 427, 54, 54),
    'chrome:tab-explore': const Rect.fromLTWH(40, 1050, 220, 70),
    'chrome:tab-missions': const Rect.fromLTWH(540, 1050, 220, 70),
  };

  /// The Explore chrome laid out in production relative positions: top strip,
  /// right edge zoom cluster, bottom tab strip.
  List<Widget> exploreChrome({
    required List<int> topCalls,
    required List<int> zoomCalls,
    required List<int> tabCalls,
    List<int>? companionCalls,
  }) {
    List<int> counterFor(String id) {
      if (id.startsWith('chrome:top-')) return topCalls;
      if (id.startsWith('chrome:explore-')) return zoomCalls;
      return tabCalls;
    }
    return [
      for (final entry in exploreRects().entries)
        _Probe(id: entry.key, rect: entry.value, counter: counterFor(entry.key)),
    ];
  }

  /// Sends a raw remote key exactly as Android delivers it (the physical
  /// button → platform view → engine → Focus.onKeyEvent), settling frames.
  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  /// Lets the controller's short hint/fade timers fire so teardown sees no
  /// pending timers. UI focus mode holds no timer, so this is one hop.
  Future<void> flushTimers(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Walks the D-pad toward [targetId] one greedy step at a time, pressing
  /// along the axis with the larger remaining distance. Strictly bounded:
  /// a navigation regression fails the test instead of hanging the suite.
  ///
  /// When the cursor revisits a control (bouncing inside a cluster whose
  /// siblings outscore the far-off target), the step switches to the other
  /// axis toward the target — the same thing a child does when sideways
  /// stops making progress.
  Future<void> reachId(
    WidgetTester tester,
    TvExplorerController tv,
    String targetId,
    Map<String, Rect> rects,
  ) async {
    final recent = <String>[];
    for (var i = 0; i < 40; i++) {
      final cur = tv.state.spatialFocusId;
      if (cur == targetId) return;
      final curRect = cur == null ? null : rects[cur];
      final dst = rects[targetId];
      LogicalKeyboardKey key;
      if (curRect == null || dst == null) {
        key = LogicalKeyboardKey.arrowDown;
      } else {
        final d = dst.center - curRect.center;
        final primary = d.dx.abs() > d.dy.abs()
            ? (d.dx > 0
                  ? LogicalKeyboardKey.arrowRight
                  : LogicalKeyboardKey.arrowLeft)
            : (d.dy > 0
                  ? LogicalKeyboardKey.arrowDown
                  : LogicalKeyboardKey.arrowUp);
        if (cur != null && recent.contains(cur)) {
          key = primary == LogicalKeyboardKey.arrowLeft ||
                  primary == LogicalKeyboardKey.arrowRight
              ? (d.dy > 0
                    ? LogicalKeyboardKey.arrowDown
                    : LogicalKeyboardKey.arrowUp)
              : (d.dx > 0
                    ? LogicalKeyboardKey.arrowRight
                    : LogicalKeyboardKey.arrowLeft);
        } else {
          key = primary;
        }
      }
      if (cur != null) {
        recent.add(cur);
        if (recent.length > 6) recent.removeAt(0);
      }
      await press(tester, key);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tv.state.spatialFocusId, targetId);
  }

  testWidgets('every Explore control registers into the TV graph', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final container = await pumpExplore(
      tester,
      overrides: tvOverrides(television: true),
      chrome: () => exploreChrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
      ),
    );
    final tv = container.read(tvExplorerControllerProvider.notifier);
    expect(
      tv.registeredTargetIds,
      containsAll(const [
        'chrome:top-language',
        'chrome:top-avatar',
        'chrome:top-labels',
        'chrome:explore-zoom-in',
        'chrome:explore-zoom-out',
        'chrome:explore-reset',
        'chrome:tab-explore',
        'chrome:tab-missions',
      ]),
    );
    await flushTimers(tester);
  });

  testWidgets(
    'BACK enters UI focus, arrows reach the top row, OK fires it',
    (tester) async {
      final topCalls = <int>[];
      final zoomCalls = <int>[];
      final tabCalls = <int>[];
      final container = await pumpExplore(
        tester,
        overrides: tvOverrides(television: true),
        chrome: () => exploreChrome(
          topCalls: topCalls,
          zoomCalls: zoomCalls,
          tabCalls: tabCalls,
        ),
      );
      final tv = container.read(tvExplorerControllerProvider.notifier);
      // Discovery owns the D-pad first: arrows move celestial, never chrome.
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(tv.state.chromeFocused, isFalse);
      expect(tv.state.spatialFocusId, isNot(startsWith('chrome:')));

      // BACK with empty hands offers UI focus; arrows reach the top strip.
      // (The opening arrow may leave a discovery mark behind; the first BACK
      // then unwinds exactly one layer — the mark — and the second offers UI.)
      await press(tester, LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 50));
      if (!tv.state.chromeFocused) {
        await press(tester, LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tv.state.chromeFocused, isTrue);
      await reachId(
        tester,
        tv,
        'chrome:top-language',
        exploreRects(),
      );
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'tvTarget:chrome:top-language',
      );
      // OK activates the focused control through the real callback.
      await press(tester, LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 50));
      expect(topCalls, hasLength(1));
      await flushTimers(tester);
    },
  );

  testWidgets('arrows walk the whole top row and OK hits each button', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final container = await pumpExplore(
      tester,
      overrides: tvOverrides(television: true),
      chrome: () => exploreChrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
      ),
    );
    final tv = container.read(tvExplorerControllerProvider.notifier);
    final rects = exploreRects();
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));
    // Every top-row button is reachable by arrows and fires exactly once.
    for (final id in const [
      'chrome:top-language',
      'chrome:top-avatar',
      'chrome:top-labels',
    ]) {
      await reachId(tester, tv, id, rects);
      await press(tester, LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(topCalls, hasLength(3));
    await flushTimers(tester);
  });

  testWidgets('zoom in / zoom out / reset are reachable and fire', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final container = await pumpExplore(
      tester,
      overrides: tvOverrides(television: true),
      chrome: () => exploreChrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
      ),
    );
    final tv = container.read(tvExplorerControllerProvider.notifier);
    final rects = exploreRects();
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));
    // Every zoom-rail control is reachable by arrows and fires exactly once.
    for (final id in const [
      'chrome:explore-zoom-in',
      'chrome:explore-zoom-out',
      'chrome:explore-reset',
    ]) {
      await reachId(tester, tv, id, rects);
      expect(tv.state.spatialFocusId, id);
      await press(tester, LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(zoomCalls.length, 3);
    await flushTimers(tester);
  });

  testWidgets(
    'bottom navigation items are reachable and fire their tab callbacks',
    (tester) async {
      final topCalls = <int>[];
      final zoomCalls = <int>[];
      final tabCalls = <int>[];
      final container = await pumpExplore(
        tester,
        overrides: tvOverrides(television: true),
        chrome: () => exploreChrome(
          topCalls: topCalls,
          zoomCalls: zoomCalls,
          tabCalls: tabCalls,
        ),
      );
      final tv = container.read(tvExplorerControllerProvider.notifier);
      final rects = exploreRects();
      await press(tester, LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 50));
      await reachId(tester, tv, 'chrome:tab-explore', rects);
      expect(tv.state.spatialFocusId, 'chrome:tab-explore');
      await press(tester, LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tabCalls.length, 1);
      await reachId(tester, tv, 'chrome:tab-missions', rects);
      expect(tv.state.spatialFocusId, 'chrome:tab-missions');
      await press(tester, LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tabCalls.length, 2);
      await flushTimers(tester);
    },
  );

  testWidgets('UI focus mode never changes celestial selection', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final container = await pumpExplore(
      tester,
      overrides: tvOverrides(television: true),
      chrome: () => exploreChrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
      ),
    );
    final explorer = container.read(explorerControllerProvider.notifier);
    final tv = container.read(tvExplorerControllerProvider.notifier);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));
    for (final key in const [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ]) {
      await press(tester, key);
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(tv.state.chromeFocused, isTrue);
    expect(tv.state.spatialFocusId, startsWith('chrome:'));
    expect(explorer.state.markedTargetId, isNull);
    expect(explorer.state.selectedPlanetId, isNull);
    await flushTimers(tester);
  });

  testWidgets('BACK leaves UI focus and returns arrows to discovery', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final container = await pumpExplore(
      tester,
      overrides: tvOverrides(television: true),
      chrome: () => exploreChrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
      ),
    );
    final tv = container.read(tvExplorerControllerProvider.notifier);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tv.state.chromeFocused, isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tv.state.chromeFocused, isFalse);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tv.state.spatialFocusId, isNot(startsWith('chrome:')));
    await flushTimers(tester);
  });

  testWidgets('a hidden control leaves the graph and returns with it', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    var showBanner = true;
    Future<ProviderContainer> pump({required bool banner}) async {
      showBanner = banner;
      return pumpExplore(
        tester,
        overrides: tvOverrides(television: true),
        chrome: () => [
          ...exploreChrome(
            topCalls: topCalls,
            zoomCalls: zoomCalls,
            tabCalls: tabCalls,
          ),
          if (showBanner)
            _Probe(
              id: 'chrome:mission-banner',
              rect: Rect.fromLTWH(200, 160, 400, 60),
              counter: topCalls,
            ),
        ],
      );
    }

    final container = await pump(banner: true);
    final tv = container.read(tvExplorerControllerProvider.notifier);
    expect(tv.registeredTargetIds, contains('chrome:mission-banner'));
    await pump(banner: false);
    await tester.pump();
    expect(tv.registeredTargetIds, isNot(contains('chrome:mission-banner')));
    await flushTimers(tester);
  });

  testWidgets('a selection auto-enters UI focus on the facts pill', (
    tester,
  ) async {
    final topCalls = <int>[];
    final zoomCalls = <int>[];
    final tabCalls = <int>[];
    final container = await pumpExplore(
      tester,
      overrides: tvOverrides(television: true),
      chrome: () => exploreChrome(
        topCalls: topCalls,
        zoomCalls: zoomCalls,
        tabCalls: tabCalls,
      ),
    );
    final tv = container.read(tvExplorerControllerProvider.notifier);
    final explorer = container.read(explorerControllerProvider.notifier);
    expect(tv.state.chromeFocused, isFalse);
    explorer.selectPlanet('earth');
    // Visiting Earth completes a mission: the celebration dialog owns the
    // remote as a modal until dismissed, like a child closing it.
    container.read(missionProgressProvider.notifier).closeCelebration();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tv.state.chromeFocused, isTrue);
    expect(tv.state.spatialFocusId, 'chrome:show-facts');
    // UI focus mode is its own BACK layer: leaving the detail does not take
    // it with it — the cursor stays until the next arrow re-seats it onto a
    // live control instead of the now-unregistered pill.
    explorer.closeDetail();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tv.state.chromeFocused, isTrue);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tv.state.spatialFocusId, isNot('chrome:show-facts'));
    expect(tv.state.spatialFocusId, startsWith('chrome:'));
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tv.state.chromeFocused, isFalse);
    // The selection drives narration/audio through real providers; settle
    // every straggler so teardown sees no pending timers.
    await tester.pump(const Duration(seconds: 5));
  });
}