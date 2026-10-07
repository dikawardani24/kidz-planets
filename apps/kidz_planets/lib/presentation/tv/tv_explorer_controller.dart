// The analyzer's `prefer_initializing_formals` fix is a named parameter
// starting with an underscore, which Dart forbids: the constructor would become
// uncallable. The fields stay private and the public parameter names stay
// readable, so the lint is switched off for this file.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/platform.dart';
import 'package:planets/state.dart';

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
}

/// Visible TV chrome state: the D-pad's current job, the hint bar, the home.
class TvExplorerUiState extends Equatable {
  const TvExplorerUiState({
    this.mode = TvControlMode.browse,
    this.hintVisible = true,
    this.homeVisible = true,
  });

  final TvControlMode mode;
  final bool hintVisible;
  final bool homeVisible;

  TvExplorerUiState copyWith({
    TvControlMode? mode,
    bool? hintVisible,
    bool? homeVisible,
  }) => TvExplorerUiState(
    mode: mode ?? this.mode,
    hintVisible: hintVisible ?? this.hintVisible,
    homeVisible: homeVisible ?? this.homeVisible,
  );

  @override
  List<Object?> get props => [mode, hintVisible, homeVisible];
}

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
  }) : _explorer = explorer,
       _scene = scene,
       _bodyIds = List.unmodifiable(bodyIds),
       super(const TvExplorerUiState()) {
    _showHintTemporarily();
  }

  /// Pixels/second the view rotates at full tilt. A full sweep takes ~2.5s:
  /// fast enough to travel, slow enough for a child to follow.
  static const double maxRotationSpeed = 520;

  /// How quickly rotation ramps up while held.
  static const double rotationAccel = 1700;

  /// Zoom rate while a zoom key is held (fraction/second).
  static const double zoomRate = 0.6;

  /// Detail-zoom units/second while a zoom key is held in detail.
  static const double detailZoomRate = 1.2;

  final ExplorerController _explorer;
  final TvSceneOps _scene;
  final List<String> _bodyIds;

  /// Re-speaks the selected body on the second OK (detail step).
  final void Function(String planetId)? replayNarration;

  /// Suppresses accidental double activation of OK.
  final Duration selectDebounce;

  /// How long the controller hint stays up after appearing.
  final Duration hintTimeout;

  final Set<TvRemoteKey> _held = {};
  double _velX = 0;
  double _velY = 0;
  DateTime? _lastSelectAt;
  Timer? _hintTimer;

  ExplorerController get explorer => _explorer;

  // -- discrete input -------------------------------------------------------

  /// Handles a remote button press. Returns true when consumed.
  ///
  /// Direction keys in [TvControlMode.rotate] start held rotation (finished
  /// by [handleKeyUp] + [advance]); everything else acts immediately.
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
    // Repeats only keep stepping/rotating/zooming; select fires once.
    if (isRepeat && action == TvExplorerAction.select) {
      return true;
    }
    switch (action) {
      case TvExplorerAction.focusNext:
        _moveCursor(1);
        return true;
      case TvExplorerAction.focusPrevious:
        _moveCursor(-1);
        return true;
      case TvExplorerAction.select:
        _select();
        return true;
      case TvExplorerAction.rotateLeft:
      case TvExplorerAction.rotateRight:
      case TvExplorerAction.rotateUp:
      case TvExplorerAction.rotateDown:
        _held.add(key);
        return true;
      case TvExplorerAction.zoomIn:
      case TvExplorerAction.zoomOut:
        _held.add(key);
        return true;
      case TvExplorerAction.back:
      case TvExplorerAction.playPause:
        return true; // Handled above; unreachable.
    }
  }

  /// Releases a held direction/zoom key. Held motion decays in [advance].
  void handleKeyUp(TvRemoteKey key) {
    _held.remove(key);
  }

  /// Translates a raw remote key into the semantic action for the current mode.
  TvExplorerAction _actionFor(TvRemoteKey key) {
    return switch (key) {
      TvRemoteKey.center => TvExplorerAction.select,
      TvRemoteKey.left =>
        state.mode == TvControlMode.browse
            ? TvExplorerAction.focusPrevious
            : TvExplorerAction.rotateLeft,
      TvRemoteKey.right =>
        state.mode == TvControlMode.browse
            ? TvExplorerAction.focusNext
            : TvExplorerAction.rotateRight,
      TvRemoteKey.up =>
        state.mode == TvControlMode.browse
            ? TvExplorerAction.zoomOut
            : TvExplorerAction.rotateUp,
      TvRemoteKey.down =>
        state.mode == TvControlMode.browse
            ? TvExplorerAction.zoomIn
            : TvExplorerAction.rotateDown,
      TvRemoteKey.back => TvExplorerAction.back,
      TvRemoteKey.playPause => TvExplorerAction.playPause,
    };
  }

  // -- continuous motion -----------------------------------------------------

  /// Advances held rotation/zoom by [dtSeconds]. Called once per frame while
  /// the TV explorer is active; clamps large gaps (backgrounding) so the
  /// camera never jumps.
  void advance(double dtSeconds) {
    final dt = dtSeconds.clamp(0.0, 0.05);
    if (dt <= 0) return;
    _advanceRotation(dt);
    _advanceZoom(dt);
  }

  void _advanceRotation(double dt) {
    final ui = _explorer.state;
    final left = _held.contains(TvRemoteKey.left);
    final right = _held.contains(TvRemoteKey.right);
    final up = _held.contains(TvRemoteKey.up);
    final down = _held.contains(TvRemoteKey.down);
    // Zoom keys never rotate: in browse mode UP/DOWN are zoom.
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

  void _advanceZoom(double dt) {
    final inHeld = _held.contains(TvRemoteKey.down);
    final outHeld = _held.contains(TvRemoteKey.up);
    // Zoom keys double as rotation in rotate mode; only browse zooms here.
    if (state.mode != TvControlMode.browse || inHeld == outHeld) return;
    final ui = _explorer.state;
    if (ui.hasSelection) {
      _explorer.adjustDetailZoom((outHeld ? 1 : -1) * detailZoomRate * dt);
      return;
    }
    final markedId =
        ui.markedTargetId ?? (_bodyIds.isEmpty ? null : _bodyIds.first);
    if (markedId == null) return;
    final scale = inHeld ? 1 + zoomRate * dt : 1 / (1 + zoomRate * dt);
    _scene.pinchTowardBody(scale, markedId);
    final camera = _scene.buildCamera(_explorer.state);
    _explorer.reportMarkProgress(
      _scene.markZoomProgress(markedId, camera),
      approaching: inHeld,
    );
    if (inHeld && _scene.shouldAutoEnterDetail(markedId, camera)) {
      final initialZoom = _scene.prepareSeamlessSelection(markedId, camera);
      if (!_explorer.state.hasSelection) {
        _explorer.selectPlanet(markedId, initialDetailZoom: initialZoom);
      }
    }
  }

  static double _approach(double value, double target, double step) {
    if (value == target) return target;
    if ((target - value).abs() <= step) return target;
    return value + step * (target > value ? 1 : -1);
  }

  // -- cursor / selection -----------------------------------------------------

  /// Parks the body cursor on the first body when nothing is marked or
  /// selected, so the next OK always does something real.
  void ensureCursor() {
    final ui = _explorer.state;
    if (ui.markedTargetId == null && !ui.hasSelection && _bodyIds.isNotEmpty) {
      _explorer.markTarget(_bodyIds.first);
    }
  }

  /// Moves the body cursor. In detail, LEFT/RIGHT switches the detailed body
  /// (mirroring tap-to-switch on touch); otherwise it moves the mark, which
  /// steers the camera target through the existing tick behavior.
  void _moveCursor(int delta) {
    if (_bodyIds.isEmpty) return;
    final ui = _explorer.state;
    if (ui.hasSelection) {
      final current = _bodyIds.indexOf(ui.selectedPlanetId!);
      final next = _bodyIds[(current + delta) % _bodyIds.length];
      _scene.cancelZoomFlight();
      _explorer.selectPlanet(next);
      return;
    }
    final anchor = ui.markedTargetId;
    if (anchor == null) {
      // No cursor yet: land on the near end rather than skipping it.
      _scene.cancelZoomFlight();
      _explorer.markTarget(delta > 0 ? _bodyIds.first : _bodyIds.last);
      return;
    }
    var index = _bodyIds.indexOf(anchor);
    if (index < 0) index = 0;
    final next = _bodyIds[(index + delta) % _bodyIds.length];
    if (next == ui.markedTargetId) return;
    _scene.cancelZoomFlight();
    _explorer.markTarget(next);
  }

  /// OK: focus the marked body (camera follows through the existing focus
  /// behavior), or re-speak the selected body on a repeat press.
  ///
  /// Opening facts stays with the "Show facts" pill, which takes autofocus on
  /// TV: a second OK lands on the pill and opens the existing facts dialog,
  /// so this controller never duplicates dialog plumbing.
  void _select() {
    final now = DateTime.now();
    if (_lastSelectAt != null &&
        now.difference(_lastSelectAt!) < selectDebounce) {
      return;
    }
    _lastSelectAt = now;
    final ui = _explorer.state;
    if (ui.hasSelection) {
      final selectedId = ui.selectedPlanetId;
      if (selectedId != null) replayNarration?.call(selectedId);
      return;
    }
    final markedId = ui.markedTargetId;
    if (markedId != null) {
      _explorer.selectPlanet(markedId);
      return;
    }
    if (_bodyIds.isNotEmpty) _explorer.markTarget(_bodyIds.first);
  }

  // -- back -------------------------------------------------------------------

  /// Predictable BACK: celebration > detail > mark > missions > system.
  TvBackOutcome handleBack(TvBackContext back) {
    if (back.celebrationVisible) {
      back.closeCelebration();
      return TvBackOutcome.dismissedCelebration;
    }
    if (_explorer.state.hasSelection) {
      _explorer.closeDetail();
      return TvBackOutcome.closedDetail;
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

  // -- chrome -------------------------------------------------------------------

  void setMode(TvControlMode mode) {
    if (state.mode == mode) return;
    _held.clear();
    _velX = 0;
    _velY = 0;
    state = state.copyWith(mode: mode);
    _showHintTemporarily();
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
    super.dispose();
  }
}
