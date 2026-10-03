// The analyzer's `prefer_initializing_formals` fix is a named parameter
// starting with an underscore, which Dart forbids: the constructor would become
// uncallable. The fields stay private and the public parameter names stay
// readable, so the lint is switched off for this file.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/l10n.dart';
import 'package:core/time.dart';
import 'package:planets/domain.dart';
import 'package:planets/state.dart';

/// Drives the solar-system explorer: transport controls, selection, the detail
/// camera and the playground callouts.
///
/// Selection only moves this feature's own state. Whether a tap was the mission
/// target is decided in the application package, which watches [selectedPlanetId]
/// and owns the answer. That direction of dependency is the whole point: a
/// feature reports what happened, and the shell decides what it means.
class ExplorerController extends StateNotifier<ExplorerState> {
  ExplorerController({required SimulationClock clock})
    : _clock = clock,
      super(const ExplorerState());

  final SimulationClock _clock;

  final Map<int, Timer> _toastTimers = {};
  Timer? _spinHintTimer;
  int _toastKey = 0;

  void toggleRunning() {
    if (state.running) {
      _clock.pause();
    } else {
      _clock.resume();
    }
    state = state.copyWith(running: !state.running);
  }

  void setSpeed(double speed) {
    _clock.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  void toggleOrbits() => state = state.copyWith(showOrbits: !state.showOrbits);

  void toggleLabels() => state = state.copyWith(showLabels: !state.showLabels);

  /// Marks [id] as the body the child wants to approach.
  ///
  /// Marking stays in exploration mode: no selection, no focus change, no
  /// detail UI, and therefore no mission grading or planet sound (the app
  /// shell only reacts to [ExplorerState.selectedPlanetId]). Tapping the
  /// already-marked body unmarks it. Detail opens later, once a zoom brings
  /// the camera close enough (see `shouldAutoEnterDetail`).
  /// Strictly-above threshold for the approach narration: the body
  /// "introduces itself" only after the zoom passes the 90% point, never
  /// exactly on it.
  static const double markNarrationThreshold = 0.90;

  void markTarget(String id) {
    if (state.markedTargetId == id) {
      state = state.copyWith(markedTargetId: null);
      return;
    }
    // A fresh mark starts a fresh zoom session: no progress yet, narration
    // not played. Closing detail later preserves these (see [closeDetail])
    // so the child continues from the previous zoom position.
    state = state.copyWith(
      markedTargetId: id,
      markZoomProgress: 0.0,
      markNarrationPlayed: false,
      markZoomApproaching: false,
    );
  }

  void clearMarkedTarget() {
    if (state.markedTargetId == null) return;
    state = state.copyWith(
      markedTargetId: null,
      markZoomProgress: 0.0,
      markNarrationPlayed: false,
      markZoomApproaching: false,
    );
  }

  /// Records the latest zoom progress toward the marked body.
  ///
  /// Called on every marked-zoom update with the pinch direction. Receding
  /// back to or below the threshold opens a new session ([markNarrationPlayed]
  /// resets), so the next approach may narrate again. Without a mark this is
  /// a no-op, which is what keeps direct detail opens narration-free.
  void reportMarkProgress(double progress, {required bool approaching}) {
    if (state.markedTargetId == null) return;
    final finite = progress.isFinite ? progress : 0.0;
    state = state.copyWith(
      markZoomProgress: finite,
      markZoomApproaching: approaching,
      markNarrationPlayed: (!approaching && finite <= markNarrationThreshold)
          ? false
          : state.markNarrationPlayed,
    );
  }

  /// Whether the approach narration should play now: marked, approaching,
  /// past the threshold, and not yet played this session.
  bool get isMarkNarrationDue =>
      state.markedTargetId != null &&
      state.markZoomApproaching &&
      !state.markNarrationPlayed &&
      state.markZoomProgress > markNarrationThreshold;

  void acknowledgeMarkNarration() {
    if (state.markedTargetId == null || state.markNarrationPlayed) return;
    state = state.copyWith(markNarrationPlayed: true);
  }

  void selectPlanet(String id, {double initialDetailZoom = 1.0}) {
    // Tapping the already-focused body exits detail mode. Facts are never
    // required to leave the focused view.
    if (state.selectedPlanetId == id) {
      closeDetail();
      return;
    }

    state = state.copyWith(
      selectedPlanetId: id,
      focusedPlanetId: id,
      detailZoom: math.max(0.001, initialDetailZoom),
      detailTheta: 0.65,
      detailPhi: 0.28,
      detailHotspot: null,
      // Facts are opened explicitly from the Show facts dialog trigger.
      detailCardVisible: false,
      playModeBannerVisible: false,
      spinHintVisible: true,
    );

    _spinHintTimer?.cancel();
    _spinHintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && state.hasSelection) {
        state = state.copyWith(spinHintVisible: false);
      }
    });
  }

  void closeDetail() {
    _spinHintTimer?.cancel();
    // The mark and its zoom/narration session survive closing: the child
    // continues from the previous zoom position, and the marker is still
    // there for the next approach.
    state = state.copyWith(
      selectedPlanetId: null,
      focusedPlanetId: null,
      detailHotspot: null,
      detailCardVisible: false,
      spinHintVisible: false,
      playModeBannerVisible: false,
    );
  }

  void toggleDetailCard() {
    if (!state.hasSelection) return;
    // Facts are presented as a dialog now; this legacy state toggle is kept
    // for callers that still reference it, but selection never opens facts.
    state = state.copyWith(detailCardVisible: !state.detailCardVisible);
  }

  void adjustDetailZoom(double delta) {
    if (!state.hasSelection) return;
    state = state.copyWith(
      detailZoom: math.max(0.001, state.detailZoom + delta),
    );
  }

  void resetDetailView() {
    if (!state.hasSelection) return;
    state = state.copyWith(detailZoom: 1.0, detailTheta: 0.65, detailPhi: 0.28);
  }

  void showHotspot(Hotspot hotspot, {required String planetId}) {
    final ref = HotspotRef(planetId: planetId, hotspot: hotspot);
    state = state.copyWith(detailHotspot: ref);

    // Matched on the slug, not the title. The title is display copy and
    // changes with the language, so keying camera framing off words in it
    // would silently stop working the moment a translation lands.
    final slug = hotspot.slug;
    const polar = {'polar_ice_caps', 'white_cirrus_clouds', 'cratered_face'};
    const rings = {'icy_rings'};
    const storm = {'great_red_spot', 'runaway_heat', 'solar_wind'};
    updateDetailCamera(
      phi: polar.contains(slug)
          ? .95
          : rings.contains(slug)
          ? .65
          : state.detailPhi,
      zoom: rings.contains(slug) ? .85 : state.detailZoom,
    );
    if (storm.contains(slug)) showHotspotToast(ref);
  }

  void updateDetailCamera({double? zoom, double? theta, double? phi}) {
    state = state.copyWith(
      detailZoom: zoom ?? state.detailZoom,
      detailTheta: theta ?? state.detailTheta,
      detailPhi: phi ?? state.detailPhi,
    );
  }

  void runExperiment(String experiment) {
    switch (experiment) {
      case 'earth':
        _setExperimentAlert(
          icon: '\u{1F525}',
          title: const AppMessage(AppMessageId.alertEarthTitle),
          description: const AppMessage(AppMessageId.alertEarthDescription),
        );
        break;
      case 'saturn':
        _setExperimentAlert(
          icon: '\u{1FA90}',
          title: const AppMessage(AppMessageId.alertSaturnTitle),
          description: const AppMessage(AppMessageId.alertSaturnDescription),
        );
        selectPlanet('saturn');
        break;
      case 'jupiter':
        _setExperimentAlert(
          icon: '\u{1F32A}\u{FE0F}',
          title: const AppMessage(AppMessageId.alertJupiterTitle),
          description: const AppMessage(AppMessageId.alertJupiterDescription),
        );
        selectPlanet('jupiter');
        break;
      case 'sun':
        _setExperimentAlert(
          icon: '\u{2600}\u{FE0F}',
          title: const AppMessage(AppMessageId.alertSunTitle),
          description: const AppMessage(AppMessageId.alertSunDescription),
        );
        selectPlanet('sun');
        break;
    }
  }

  void resetPlayground() {
    _clock.setSpeed(1.0);
    state = state.copyWith(
      speed: 1.0,
      showOrbits: true,
      showLabels: true,
      playgroundAlertIcon: '\u{1F525}',
      playgroundAlertTitle: const AppMessage(AppMessageId.alertSandboxTitle),
      playgroundAlertDescription: const AppMessage(
        AppMessageId.alertSandboxDescription,
      ),
    );
    showToast(const AppMessage(AppMessageId.toastSandboxReady));
  }

  /// Echoes a hotspot's name as a toast, for the dramatic ones that announce
  /// themselves. The name comes from the catalogue, so the toast carries the
  /// hotspot rather than a string and the view resolves the right language.
  void showHotspotToast(HotspotRef hotspot) {
    _pushToast(ToastMessage(key: ++_toastKey, hotspot: hotspot));
  }

  void showToast(AppMessage message) {
    _pushToast(ToastMessage(key: ++_toastKey, message: message));
  }

  void _pushToast(ToastMessage toast) {
    state = state.copyWith(toasts: [...state.toasts, toast]);
    _startToastTimer(toast.key);
  }

  /// One timer per toast: a single shared timer was cancelled by the next
  /// toast, which left every earlier toast on screen with nothing left to
  /// dismiss it.
  void _startToastTimer(int key) {
    final timer = Timer(const Duration(seconds: 3), () {
      _toastTimers.remove(key);
      if (!mounted) return;
      state = state.copyWith(
        toasts: state.toasts.where((t) => t.key != key).toList(),
      );
    });
    _toastTimers[key] = timer;
  }

  void _setExperimentAlert({
    required String icon,
    required AppMessage title,
    required AppMessage description,
  }) {
    // The icon used to be parsed back out of the title's leading emoji, which
    // only worked because the title was an English literal starting with it.
    state = state.copyWith(
      playgroundAlertIcon: icon,
      playgroundAlertTitle: title,
      playgroundAlertDescription: description,
    );
  }

  @override
  void dispose() {
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    _toastTimers.clear();
    _spinHintTimer?.cancel();
    super.dispose();
  }
}
