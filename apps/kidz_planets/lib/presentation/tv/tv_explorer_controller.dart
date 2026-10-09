// The analyzer's `prefer_initializing_formals` fix is a named parameter
// starting with an underscore, which Dart forbids: the constructor would become
// uncallable. The fields stay private and the public parameter names stay
// readable, so the lint is switched off for this file.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/platform.dart';
import 'package:planets/state.dart';

import 'tv_discovery_graph.dart';

/// What BACK needs from the shell, which the explorer must not know about.
///
/// The controller decides the order (celebration > detail > mark > missions);
/// the shell performs its own steps through these callbacks.
class TvBackContext {
  const TvBackContext({
    required this.celebrationVisible,
    required this.missionsOpen,
    required this.closeCelebration,
    required this.exitMissions,
  });

  final bool celebrationVisible;
  final bool missionsOpen;
  final void Function() closeCelebration;
  final void Function() exitMissions;
}

/// How one BACK press was resolved.
enum TvBackOutcome {
  dismissedCelebration,
  closedDetail,
  clearedMark,
  exitedMissions,
  exitedChrome,
  unhandled,
}

/// The camera-free half of [SolarSystemSceneController] the TV controller may
/// use.
///
/// The production adapter delegates to the real scene controller (same camera,
/// same focus behavior — no second camera system); tests substitute a fake.
abstract class TvSceneOps {
  void rotateView(double dxPx, double dyPx);
  void rotateObject(String planetId, double dxPx, double dyPx);
  void pinchTowardBody(double scaleFactor, String planetId);
  PerspectiveCamera buildCamera(ExplorerState ui);
  bool shouldAutoEnterDetail(String planetId, PerspectiveCamera camera);
  double prepareSeamlessSelection(String planetId, PerspectiveCamera camera);
  double markZoomProgress(String planetId, PerspectiveCamera camera);
  void cancelZoomFlight();
  void resetOverview();

  /// Starts the smooth zoom-to-detail flight toward [planetId] from [camera]'s
  /// eye. Unknown ids are ignored. The scene view finishes the flight by
  /// opening detail at the reached distance — the same flight the touch
  /// double-tap starts, so TV and mobile share one camera path.
  void startZoomToDetail(String planetId, PerspectiveCamera camera);

  /// Whether a zoom-to-detail flight is currently running.
  bool get zoomFlightActive;
  Offset? projectBodyCenter(
    String planetId,
    PerspectiveCamera camera,
    Size viewSize,
  );
}

/// Visible TV chrome state: the D-pad's current job, the hint bar, the home.
class TvExplorerUiState extends Equatable {
  const TvExplorerUiState({
    this.mode = TvControlMode.browse,
    this.hintVisible = true,
    this.homeVisible = false,
    this.quickSelectVisible = false,
    this.chromeFocused = false,
    this.chromeVisible = true,
    this.spatialFocusId,
  });

  final TvControlMode mode;
  final bool hintVisible;
  final bool homeVisible;
  final bool quickSelectVisible;

  /// Whether the D-pad currently drives the secondary UI layer instead of
  /// the solar system. Discovery navigation never enters this on its own:
  /// only an explicit [TvExplorerController.enterChrome] (or the BACK
  /// shuttle offering the cluster) arms it, and BACK leaves it.
  final bool chromeFocused;

  /// Whether the quiet secondary controls (pause, help) are shown. Fades
  /// after [TvExplorerController.chromeTimeout] of no control input so the
  /// scene stays unobstructed; any navigation press brings them briefly back.
  /// The discovery highlight itself never fades with this.
  final bool chromeVisible;

  /// Id of the currently selected interactive target (3D body or chrome id).
  /// Null means nothing selected yet. Always visible via mark/focus visuals.
  final String? spatialFocusId;

  TvExplorerUiState copyWith({
    TvControlMode? mode,
    bool? hintVisible,
    bool? homeVisible,
    bool? quickSelectVisible,
    bool? chromeFocused,
    bool? chromeVisible,
    Object? spatialFocusId = _sentinel,
  }) => TvExplorerUiState(
    mode: mode ?? this.mode,
    hintVisible: hintVisible ?? this.hintVisible,
    homeVisible: homeVisible ?? this.homeVisible,
    quickSelectVisible: quickSelectVisible ?? this.quickSelectVisible,
    chromeFocused: chromeFocused ?? this.chromeFocused,
    chromeVisible: chromeVisible ?? this.chromeVisible,
    spatialFocusId: identical(spatialFocusId, _sentinel)
        ? this.spatialFocusId
        : spatialFocusId as String?,
  );

  @override
  List<Object?> get props => [
    mode,
    hintVisible,
    homeVisible,
    quickSelectVisible,
    chromeFocused,
    chromeVisible,
    spatialFocusId,
  ];
}

const _sentinel = Object();

/// Remote-first driver for the Explorer.
///
/// Reacts to semantic remote keys ([TvRemoteKey]) rather than raw Android key
/// codes, and operates only on the shared [ExplorerController] state plus
/// [TvSceneOps]: marking, selection, detail, zoom and pause are the same
/// objects the touch UI uses, so missions, narration, SFX and completion
/// behave identically on TV and on phones.
///
/// Motion is velocity-based, not per-press jumps: holding a direction
/// accelerates toward a capped speed and releases glide to a smooth stop, so
/// a held remote button reads as one continuous gesture.
class TvExplorerController extends StateNotifier<TvExplorerUiState> {
  TvExplorerController({
    required ExplorerController explorer,
    required TvSceneOps scene,
    required List<String> bodyIds,
    this.replayNarration,
    this.selectDebounce = const Duration(milliseconds: 350),
    this.hintTimeout = const Duration(seconds: 6),
    this.chromeTimeout = const Duration(seconds: 4),
    TvDiscoveryGraph? discovery,
  }) : _explorer = explorer,
       _scene = scene,
       _bodyIds = List.unmodifiable(bodyIds),
       _discovery = discovery ?? TvDiscoveryGraph.fromIds(bodyIds),
       super(const TvExplorerUiState()) {
    _showHintTemporarily();
    _pokeChrome();
  }

  /// Pixels/second the view rotates at full tilt. A full sweep takes ~2.5s:
  /// fast enough to travel, slow enough for a child to follow.
  static const double maxRotationSpeed = 520;

  /// How quickly rotation ramps up while held.
  static const double rotationAccel = 1700;

  final ExplorerController _explorer;
  final TvSceneOps _scene;
  final List<String> _bodyIds;

  /// Re-speaks the selected body on the second OK (detail step).
  final void Function(String planetId)? replayNarration;

  /// Suppresses accidental double activation of OK.
  final Duration selectDebounce;

  /// How long the controller hint stays up after appearing.
  final Duration hintTimeout;

  /// How long the quiet secondary controls stay up after a press.
  final Duration chromeTimeout;

  /// Relationship-first navigation model (primaries sideways, moons via
  /// their parent). Derived from the planet catalogue, never hardcoded.
  final TvDiscoveryGraph _discovery;

  final Set<TvRemoteKey> _held = {};
  double _velX = 0;
  double _velY = 0;
  DateTime? _lastSelectAt;
  Timer? _hintTimer;
  Timer? _chromeTimer;

  /// Registered Flutter chrome targets (zoom +/-, play/pause, help, ...),
  /// keyed by stable id. 3D bodies come from [_bodyIds] + scene projection;
  /// chrome comes from [TvNavTarget] widgets calling [registerTarget].
  final Map<String, TvRegisteredTarget> _chromeTargets = {};

  ExplorerController get explorer => _explorer;

  // -- discrete input -------------------------------------------------------

  /// Handles a remote button press. Returns true when consumed.
  ///
  /// Two separated layers: discovery arrows walk the celestial graph (never
  /// chrome), while the UI layer owns its own chrome-only steps once armed
  /// via [enterChrome]. OK visits the discovery target with one smooth
  /// camera flight. Rotate mode only spins the camera while held and is
  /// opt-in from chrome — never entered automatically on selection.
  bool handleKeyDown(
    TvRemoteKey key,
    TvInputLayer layer, {
    required TvBackContext back,
    bool isRepeat = false,
    void Function()? onInteractAvatar,
  }) {
    if (key == TvRemoteKey.back) {
      // A held BACK unwinds exactly one layer: repeats are consumed so a
      // single long press can never cascade through detail, mark and tabs.
      if (isRepeat) return true;
      return handleBack(back) != TvBackOutcome.unhandled;
    }
    if (key == TvRemoteKey.playPause) {
      if (isRepeat) return true;
      _explorer.toggleRunning();
      _pokeChrome();
      return true;
    }
    final action = _actionFor(key);
    if (!isActionForLayer(action, layer)) {
      // Avatar fallback: the companion owns OK through its own focus, but if
      // focus slipped off it the remote would die with the avatar layer
      // active — drive the tap equivalent instead of dropping the press.
      if (action == TvExplorerAction.select &&
          layer == TvInputLayer.avatar &&
          onInteractAvatar != null) {
        if (!isRepeat) onInteractAvatar();
        return true;
      }
      return false;
    }
    // Repeats only keep navigating/rotating; select fires once.
    if (isRepeat && action == TvExplorerAction.select) {
      return true;
    }
    switch (action) {
      case TvExplorerAction.navigate:
        _navigateSpatial(key);
        _pokeChrome();
        return true;
      case TvExplorerAction.select:
        _select();
        _pokeChrome();
        return true;
      case TvExplorerAction.rotateLeft:
      case TvExplorerAction.rotateRight:
      case TvExplorerAction.rotateUp:
      case TvExplorerAction.rotateDown:
        _held.add(key);
        return true;
      case TvExplorerAction.back:
      case TvExplorerAction.playPause:
        return true; // Handled above; unreachable.
    }
  }

  /// Releases a held rotate key. Held motion decays in [advance].
  void handleKeyUp(TvRemoteKey key) {
    _held.remove(key);
  }

  /// Translates a raw remote key into the semantic action for the current mode.
  ///
  /// Navigate mode: every arrow is spatial navigation (never zoom — zoom has
  /// its own explicit chrome targets). Rotate mode: arrows spin the camera.
  TvExplorerAction _actionFor(TvRemoteKey key) {
    if (state.mode == TvControlMode.rotate) {
      return switch (key) {
        TvRemoteKey.center => TvExplorerAction.select,
        TvRemoteKey.left => TvExplorerAction.rotateLeft,
        TvRemoteKey.right => TvExplorerAction.rotateRight,
        TvRemoteKey.up => TvExplorerAction.rotateUp,
        TvRemoteKey.down => TvExplorerAction.rotateDown,
        TvRemoteKey.back => TvExplorerAction.back,
        TvRemoteKey.playPause => TvExplorerAction.playPause,
      };
    }
    return switch (key) {
      TvRemoteKey.center => TvExplorerAction.select,
      TvRemoteKey.left ||
      TvRemoteKey.right ||
      TvRemoteKey.up ||
      TvRemoteKey.down => TvExplorerAction.navigate,
      TvRemoteKey.back => TvExplorerAction.back,
      TvRemoteKey.playPause => TvExplorerAction.playPause,
    };
  }

  // -- continuous motion -----------------------------------------------------

  /// Advances held rotation by [dtSeconds]. Navigate mode is discrete
  /// (one press = one target step); only opt-in rotate mode holds keys.
  void advance(double dtSeconds) {
    final dt = dtSeconds.clamp(0.0, 0.05);
    if (dt <= 0) return;
    _advanceRotation(dt);
  }

  void _advanceRotation(double dt) {
    final ui = _explorer.state;
    final left = _held.contains(TvRemoteKey.left);
    final right = _held.contains(TvRemoteKey.right);
    final up = _held.contains(TvRemoteKey.up);
    final down = _held.contains(TvRemoteKey.down);
    // Navigate mode never rotates: only opt-in rotate mode holds arrows.
    final rotating =
        state.mode == TvControlMode.rotate && (left || right || up || down);
    final targetX = rotating
        ? ((right ? 1 : 0) - (left ? 1 : 0)) * maxRotationSpeed
        : 0.0;
    final targetY = rotating
        ? ((down ? 1 : 0) - (up ? 1 : 0)) * maxRotationSpeed
        : 0.0;
    _velX = _approach(_velX, targetX, rotationAccel * dt);
    _velY = _approach(_velY, targetY, rotationAccel * dt);
    if (_velX.abs() < 0.5 && _velY.abs() < 0.5) {
      _velX = 0;
      _velY = 0;
      return;
    }
    final dx = _velX * dt;
    final dy = _velY * dt;
    final selectedId = ui.selectedPlanetId;
    if (selectedId != null) {
      _scene.rotateObject(selectedId, dx, dy);
    } else {
      _scene.rotateView(dx, dy);
    }
  }

  static double _approach(double value, double target, double step) {
    if (value == target) return target;
    if ((target - value).abs() <= step) return target;
    return value + step * (target > value ? 1 : -1);
  }

  // -- unified spatial cursor -----------------------------------------------

  /// Registers a Flutter chrome control as a spatial candidate.
  /// [TvNavTarget] widgets call this on layout; bodies project live below.
  void registerTarget(TvRegisteredTarget target) {
    _chromeTargets[target.id] = target;
  }

  void unregisterTarget(String id) {
    _chromeTargets.remove(id);
  }

  /// Ids currently in the navigation graph — for tests asserting that every
  /// visible, actionable control registers and that hidden or disposed
  /// controls leave it.
  @visibleForTesting
  Iterable<String> get registeredTargetIds =>
      List.unmodifiable(_chromeTargets.keys);

  /// Parks the body cursor on the first body when nothing is marked or
  /// selected, so the next OK always does something real.
  void ensureCursor() {
    final ui = _explorer.state;
    if (ui.markedTargetId == null && !ui.hasSelection && _bodyIds.isNotEmpty) {
      _explorer.markTarget(_bodyIds.first);
      state = state.copyWith(spatialFocusId: _bodyIds.first);
    } else {
      state = state.copyWith(
        spatialFocusId: ui.selectedPlanetId ?? ui.markedTargetId,
      );
    }
  }

  Size? viewportSize;

  void updateViewportSize(Size size) {
    if (viewportSize == size) return;
    viewportSize = size;
  }

  @visibleForTesting
  void updateSpatialFocusForTest(String? id) {
    state = state.copyWith(spatialFocusId: id);
  }

  /// One spatial D-pad step.
  ///
  /// Two separated layers share one remote but never one step:
  ///
  /// - Discovery (default): the D-pad walks the [TvDiscoveryGraph] —
  ///   primaries sideways, moons through their parent. Chrome controls are
  ///   never candidates here, so ordinary exploring cannot land on zoom,
  ///   settings, or any other UI.
  /// - UI ([chromeFocused]): the D-pad walks the registered chrome controls
  ///   only, entered explicitly via [enterChrome] and left with BACK.
  void _navigateSpatial(TvRemoteKey directionKey) {
    if (state.chromeFocused) {
      _navigateChrome(directionKey);
      return;
    }
    final ui = _explorer.state;
    final currentId =
        ui.selectedPlanetId ?? ui.markedTargetId ?? state.spatialFocusId;
    final nextId = _discovery.step(currentId, directionKey);
    // No meaningful related object: stay put. Never jump to unrelated UI
    // just to make every press do something.
    if (nextId == null) return;
    _focusDiscovery(nextId);
  }

  /// Chrome-layer step: nearest registered control in the arrow's direction.
  /// Bodies are never candidates here, mirroring the discovery isolation.
  void _navigateChrome(TvRemoteKey directionKey) {
    final size = viewportSize;
    if (size == null || size.isEmpty || _chromeTargets.isEmpty) return;
    final currentId = state.spatialFocusId;
    final origin = _originForChrome(size);
    final direction = tvDirectionForKey(directionKey.name);
    final candidates = <TvSpatialCandidate>[
      for (final target in _chromeTargets.values)
        if (target.enabled && target.id != currentId)
          (id: target.id, center: target.center),
    ];
    final nextId = nearestInDirection(
      origin: origin,
      direction: direction,
      candidates: candidates,
      excludeId: currentId,
    );
    if (nextId == null) return;
    _focusChrome(nextId);
  }

  Offset _originForChrome(Size size) {
    // The control that *looks* focused (real Flutter focus) wins over the
    // stored cursor: autofocus can move focus without the controller knowing
    // (the facts pill on detail open), and the ring is what the child reads.
    final currentId = _activeChromeId();
    final chrome = currentId == null ? null : _chromeTargets[currentId];
    return chrome?.center ?? Offset(size.width / 2, size.height / 2);
  }

  /// The chrome target OK must act on: the one holding real focus when it is
  /// registered and enabled, otherwise the stored spatial cursor.
  String? _activeChromeId() {
    final focused = _primaryFocusedChromeId();
    if (focused != null) return focused;
    final stored = state.spatialFocusId;
    if (stored == null) return null;
    final target = _chromeTargets[stored];
    return (target != null && target.enabled) ? stored : null;
  }

  /// The registered chrome target that currently owns Flutter focus, if any.
  String? _primaryFocusedChromeId() {
    for (final target in _chromeTargets.values) {
      if (target.enabled && _chromeHasPrimaryFocus(target)) return target.id;
    }
    return null;
  }

  /// Candidates the chrome layer may currently navigate to.
  Iterable<TvRegisteredTarget> get _enabledChromeTargets =>
      _chromeTargets.values.where((target) => target.enabled);

  /// Best first stop when UI focus mode begins or the cursor went stale.
  ///
  /// An explicit preference (the facts pill a detail open is about to
  /// autofocus) wins even before it registers — its own autofocus provides the
  /// focus, and [_activeChromeId] reconciles cursor and focus from then on.
  /// Otherwise: whatever already holds focus, then the nearest control to the
  /// viewport centre, then simply the first registered one.
  String? _seedChromeId({String? preferId}) {
    if (preferId != null) return preferId;
    // A stored chrome id from an *earlier* UI-focus session is not a fresh
    // seed: entering UI mode must land on the best control for now, not
    // wherever the cursor was left last time. (Once inside chrome mode, the
    // cursor is the source of truth for arrows and OK — [_activeChromeId].)
    final focused = _primaryFocusedChromeId();
    if (focused != null) return focused;
    final size = viewportSize;
    if (size != null && !size.isEmpty) {
      final nearest = nearestToPoint(
        origin: size.center(Offset.zero),
        candidates: [
          for (final target in _enabledChromeTargets)
            (id: target.id, center: target.center),
        ],
      );
      if (nearest != null) return nearest;
    }
    final first = _enabledChromeTargets;
    return first.isEmpty ? null : first.first.id;
  }

  bool _chromeHasPrimaryFocus(TvRegisteredTarget chrome) {
    final node = chrome.focusNode;
    if (node == null) return false;
    try {
      return FocusManager.instance.primaryFocus == node;
    } catch (_) {
      return false;
    }
  }

  /// Applies a discovery focus change: the highlight moves to a celestial
  /// body through the shared explorer state — the same mark/select actions
  /// as a mobile tap. Chrome is never touched here.
  void _focusDiscovery(String id) {
    final ui = _explorer.state;
    // Re-focusing the same body must not toggle anything off: marking the
    // marked body unmarks it, and selecting the selected body closes detail.
    if (ui.selectedPlanetId == id || ui.markedTargetId == id) {
      if (state.spatialFocusId != id) {
        state = state.copyWith(spatialFocusId: id);
      }
      return;
    }
    state = state.copyWith(spatialFocusId: id, chromeFocused: false);
    _scene.cancelZoomFlight();
    if (ui.hasSelection) {
      _explorer.selectPlanet(id);
    } else {
      _explorer.markTarget(id);
    }
  }

  /// Applies a chrome focus change: requests Flutter focus so the visible
  /// ring follows the cursor. Explorer bodies are never touched here.
  void _focusChrome(String id) {
    state = state.copyWith(spatialFocusId: id, chromeFocused: true);
    final chrome = _chromeTargets[id];
    if (chrome == null) return;
    // Re-entrant focus requests during a traversal callback can throw;
    // the visible ring follows on the next frame regardless.
    Future.microtask(() {
      try {
        chrome.focusNode?.requestFocus();
      } catch (_) {}
    });
  }

  /// Moves the body cursor. In detail, LEFT/RIGHT switches the detailed body
  /// (mirroring tap-to-switch on touch); otherwise it moves the mark, which
  /// steers the camera target through the existing tick behavior.
  /// Test entry point: delegates to [_navigateSpatial].
  @visibleForTesting
  void moveCursorForTest(int delta, {TvRemoteKey? directionKey}) {
    _navigateSpatial(directionKey ?? TvRemoteKey.right);
  }

  /// OK: in UI focus mode, activate the focused control; otherwise visit the
  /// discovery target.
  ///
  /// Chrome activation is a direct [TvRegisteredTarget.onActivate] call and
  /// deliberately *not* deferred to the focus system's `ActivateIntent`: the
  /// remote handler sits between the focused button and the app-root
  /// `Shortcuts` that map select → `ActivateIntent`, and it consumes the key
  /// first — which is why OK used to do nothing on the very control the ring
  /// was showing. One press, one activation: the debounce above plus the
  /// handler consuming the key (so no shortcut layer can also fire) guarantee
  /// it. Discovery presses never trigger chrome.
  ///
  /// When UI mode has nothing usable to act on — the focused control was
  /// unregistered when the detail closed — the press re-seats the cursor on
  /// the nearest live control instead of falling into discovery behind UI
  /// mode. Only an entirely empty registry ends UI mode.
  void _select() {
    final now = DateTime.now();
    if (_lastSelectAt != null &&
        now.difference(_lastSelectAt!) < selectDebounce) {
      return;
    }
    _lastSelectAt = now;
    if (state.chromeFocused) {
      final activeId = _activeChromeId();
      final chrome = activeId == null ? null : _chromeTargets[activeId];
      if (chrome != null && chrome.enabled && chrome.onActivate != null) {
        if (state.spatialFocusId != activeId) {
          state = state.copyWith(spatialFocusId: activeId);
        }
        chrome.onActivate!.call();
        return;
      }
      final reseat = _seedChromeId();
      if (reseat != null) {
        _focusChrome(reseat);
        return;
      }
      state = state.copyWith(chromeFocused: false);
    }
    final ui = _explorer.state;
    if (ui.hasSelection) {
      final selectedId = ui.selectedPlanetId;
      if (selectedId != null) replayNarration?.call(selectedId);
      return;
    }
    final focusedId = state.spatialFocusId;
    final targetId =
        ui.markedTargetId ??
        (focusedId != null && _discovery.knows(focusedId) ? focusedId : null) ??
        (_discovery.primaries.isEmpty ? null : _discovery.primaries.first);
    if (targetId == null) return;
    state = state.copyWith(spatialFocusId: targetId);
    if (!_scene.zoomFlightActive) {
      try {
        final camera = _scene.buildCamera(_explorer.state);
        _scene.startZoomToDetail(targetId, camera);
      } catch (_) {}
    }
    if (ui.markedTargetId == targetId) {
      _explorer.selectPlanet(targetId);
    } else {
      _explorer.markTarget(targetId);
    }
  }

  // -- back -------------------------------------------------------------------

  /// Predictable BACK, one layer per press: quick select > celebration >
  /// detail > UI focus mode > mark > missions > system.
  ///
  /// UI focus mode sits above the mark because that is how it is entered: a
  /// detail auto-enters it, so leaving detail must hand back to UI mode (its
  /// own layer) before the discovery mark underneath is unwound.
  TvBackOutcome handleBack(TvBackContext back) {
    if (state.quickSelectVisible) {
      dismissQuickSelect();
      return TvBackOutcome.closedDetail;
    }
    if (back.celebrationVisible) {
      back.closeCelebration();
      return TvBackOutcome.dismissedCelebration;
    }
    if (_explorer.state.hasSelection) {
      _explorer.closeDetail();
      return TvBackOutcome.closedDetail;
    }
    if (state.chromeFocused) {
      exitChrome();
      return TvBackOutcome.exitedChrome;
    }
    if (_explorer.state.markedTargetId != null) {
      _scene.cancelZoomFlight();
      _explorer.clearMarkedTarget();
      return TvBackOutcome.clearedMark;
    }
    if (back.missionsOpen) {
      back.exitMissions();
      return TvBackOutcome.exitedMissions;
    }
    return TvBackOutcome.unhandled;
  }

  // -- quick select ------------------------------------------------------------

  void toggleQuickSelect() {
    state = state.copyWith(quickSelectVisible: !state.quickSelectVisible);
  }

  void showQuickSelect() {
    if (!state.quickSelectVisible) {
      state = state.copyWith(quickSelectVisible: true);
    }
  }

  void dismissQuickSelect() {
    if (state.quickSelectVisible) {
      state = state.copyWith(quickSelectVisible: false);
    }
  }

  // -- chrome -------------------------------------------------------------------

  void setMode(TvControlMode mode) {
    if (state.mode == mode) return;
    _held.clear();
    _velX = 0;
    _velY = 0;
    state = state.copyWith(mode: mode);
    _showHintTemporarily();
  }

  /// Explicit TV zoom step: the D-pad never zooms (arrows navigate), so zoom
  /// has its own chrome targets. Reuses the exact scene APIs the touch pinch
  /// handlers call — no second camera system, no gesture interference.
  void zoomInStep() => _zoomStep(1.18);

  void zoomOutStep() => _zoomStep(1 / 1.18);

  void _zoomStep(double scale) {
    final ui = _explorer.state;
    if (ui.hasSelection) {
      _explorer.adjustDetailZoom(scale > 1 ? -0.25 : 0.25);
      return;
    }
    final markedId =
        ui.markedTargetId ?? (_bodyIds.isEmpty ? null : _bodyIds.first);
    if (markedId == null) return;
    _scene.pinchTowardBody(scale, markedId);
    final camera = _scene.buildCamera(_explorer.state);
    _explorer.reportMarkProgress(
      _scene.markZoomProgress(markedId, camera),
      approaching: scale > 1,
    );
  }

  /// Called when detail closes (whoever closed it): an armed rotate mode
  /// returns to browse so arrows navigate again.
  void exitDetailCleanup() {
    if (state.mode == TvControlMode.rotate) {
      setMode(TvControlMode.browse);
    }
  }

  void toggleMode() => setMode(state.mode.toggled);

  void dismissHint() {
    _hintTimer?.cancel();
    if (state.hintVisible) state = state.copyWith(hintVisible: false);
  }

  /// Reopens the controller hint (the on-screen help button).
  void showHint() => _showHintTemporarily();

  void dismissHome() {
    if (state.homeVisible) state = state.copyWith(homeVisible: false);
  }

  void showHome() {
    if (!state.homeVisible) state = state.copyWith(homeVisible: true);
  }

  // -- secondary UI layer ------------------------------------------------------

  /// Hands the D-pad to the quiet secondary controls (pause, help).
  ///
  /// Discovery navigation never enters this on its own: the solar system
  /// owns the arrows until the child (or the BACK shuttle, or a detail open)
  /// explicitly asks for UI. The first stop is seeded immediately — [preferId]
  /// when the caller knows the control (a detail's facts pill), otherwise
  /// whatever already holds focus, otherwise the nearest registered control to
  /// the viewport centre — so the ring and OK both point at a real button the
  /// instant UI mode begins. The focus request itself is deferred a microtask:
  /// registration and focus live on the widgets, which settle after this
  /// synchronous state change.
  void enterChrome({String? preferId}) {
    _chromeTimer?.cancel();
    state = state.copyWith(chromeFocused: true, chromeVisible: true);
    final seed = _seedChromeId(preferId: preferId);
    if (seed == null) return;
    state = state.copyWith(spatialFocusId: seed);
    Future<void>.microtask(() {
      try {
        _focusChrome(seed);
      } catch (_) {
        // Unmounted target (tab switched under the seed): the next arrow or
        // OK re-seats from the registry, which is the source of truth.
      }
    });
  }

  /// Returns the D-pad to the solar system.
  ///
  /// Flutter focus returns with it: the handler listens for this transition
  /// and re-seats the scene scope, so no ring is left stranded on a chrome
  /// button while discovery owns the arrows.
  void exitChrome() {
    if (!state.chromeFocused) return;
    state = state.copyWith(chromeFocused: false);
    _pokeChrome();
  }

  /// Briefly (re)shows the quiet controls; they fade on [chromeTimeout].
  ///
  /// They never fade while UI focus mode owns the D-pad: a control that is
  /// navigable must be visible, and the registry drops hidden controls out of
  /// the graph anyway.
  void _pokeChrome() {
    _chromeTimer?.cancel();
    if (!state.chromeVisible) state = state.copyWith(chromeVisible: true);
    if (state.chromeFocused) return;
    _chromeTimer = Timer(chromeTimeout, () {
      if (state.chromeFocused) return;
      state = copyWithoutChrome();
    });
  }

  TvExplorerUiState copyWithoutChrome() => state.copyWith(chromeVisible: false);

  void _showHintTemporarily() {
    _hintTimer?.cancel();
    state = state.copyWith(hintVisible: true);
    _hintTimer = Timer(hintTimeout, () {
      state = copyWithoutHint();
    });
  }

  TvExplorerUiState copyWithoutHint() => state.copyWith(hintVisible: false);

  @override
  void dispose() {
    _hintTimer?.cancel();
    _chromeTimer?.cancel();
    super.dispose();
  }
}
