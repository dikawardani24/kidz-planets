import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/planet.dart';
import '../../infrastructure/services/planet_sound_service.dart';
import '../state/app_message.dart';
import '../state/explorer_state.dart';
import '../state/simulation_clock.dart';

class ExplorerController extends StateNotifier<ExplorerState> {
  ExplorerController({required this._clock, required List<Mission> initialMissions})
      : super(ExplorerState(missions: initialMissions.map((m) => MissionState(id: m.id, title: m.title, description: m.description, targetPlanetId: m.targetPlanetId, startPoint: m.startPoint, direction: m.direction, hints: m.hints)).toList()));

  final SimulationClock _clock;
  final PlanetSoundService _missionSound = PlanetSoundService();
  final Map<int, Timer> _toastTimers = {};
  Timer? _spinHintTimer;
  Timer? _playModeTimer;
  int _toastKey = 0;

  void setTab(ExplorerTab tab) {
    if (tab != ExplorerTab.explore) closeDetail();
    state = state.copyWith(tab: tab);
  }

  void toggleRunning() {
    if (state.running) { _clock.pause(); } else { _clock.resume(); }
    state = state.copyWith(running: !state.running);
  }

  void setSpeed(double speed) {
    _clock.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  void toggleOrbits() => state = state.copyWith(showOrbits: !state.showOrbits);
  void toggleLabels() => state = state.copyWith(showLabels: !state.showLabels);

  void selectPlanet(String id) {
    // Tapping the already-focused body exits detail mode. Facts are never
    // required to leave the focused view.
    if (state.selectedPlanetId == id) {
      closeDetail();
      return;
    }

    state = state.copyWith(
      selectedPlanetId: id, focusedPlanetId: id, detailZoom: 1.0,
      detailTheta: 0.65, detailPhi: 0.28, detailHotspot: null,
      // Facts are opened explicitly from the Show facts dialog trigger.
      detailCardVisible: false,
      playModeBannerVisible: false, spinHintVisible: true,
    );

    _spinHintTimer?.cancel();
    _spinHintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && state.hasSelection) {
        state = state.copyWith(spinHintVisible: false);
      }
    });
    _checkMission(id);
  }

  void closeDetail() {
    _spinHintTimer?.cancel();
    _playModeTimer?.cancel();
    state = state.copyWith(
      selectedPlanetId: null, focusedPlanetId: null, detailHotspot: null, detailCardVisible: false,
      spinHintVisible: false, playModeBannerVisible: false,
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
    state = state.copyWith(detailZoom: (state.detailZoom + delta).clamp(0.4, 2.6));
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
      phi: polar.contains(slug) ? .95 : rings.contains(slug) ? .65 : state.detailPhi,
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
          icon: '🔥',
          title: const AppMessage(AppMessageId.alertEarthTitle),
          description: const AppMessage(AppMessageId.alertEarthDescription),
        );
        break;
      case 'saturn':
        _setExperimentAlert(
          icon: '🪐',
          title: const AppMessage(AppMessageId.alertSaturnTitle),
          description: const AppMessage(AppMessageId.alertSaturnDescription),
        );
        selectPlanet('saturn');
        break;
      case 'jupiter':
        _setExperimentAlert(
          icon: '🌪️',
          title: const AppMessage(AppMessageId.alertJupiterTitle),
          description: const AppMessage(AppMessageId.alertJupiterDescription),
        );
        selectPlanet('jupiter');
        break;
      case 'sun':
        _setExperimentAlert(
          icon: '☀️',
          title: const AppMessage(AppMessageId.alertSunTitle),
          description: const AppMessage(AppMessageId.alertSunDescription),
        );
        selectPlanet('sun');
        break;
    }
    if (state.tab != ExplorerTab.explore) state = state.copyWith(tab: ExplorerTab.explore);
  }

  void resetPlayground() {
    _clock.setSpeed(1.0);
    state = state.copyWith(
      speed: 1.0,
      showOrbits: true,
      showLabels: true,
      playgroundAlertIcon: '🔥',
      playgroundAlertTitle: const AppMessage(AppMessageId.alertSandboxTitle),
      playgroundAlertDescription: const AppMessage(AppMessageId.alertSandboxDescription),
    );
    showToast(const AppMessage(AppMessageId.toastSandboxReady));
  }

  void completeFirstPendingFor(String planetId) {
    final idx = state.missions.indexWhere((m) => m.targetPlanetId == planetId && !m.completed);
    if (idx < 0) return;
    final mission = state.missions[idx];
    final updated = List<MissionState>.from(state.missions);
    updated[idx] = mission.copyWith(completed: true);
    state = state.copyWith(missions: updated);
    showCelebration(
      AppMessage(AppMessageId.celebrationMissionTitle, {'id': mission.id}),
      // The planet id, not its name: the name is catalogue copy and the
      // controller has no locale, so the view resolves it.
      AppMessage(AppMessageId.celebrationDiscovered, {'planetId': planetId}),
    );
    showToast(AppMessage(AppMessageId.toastMissionVerified, {'title': mission.title}));
  }

  /// Reveals the next, blunter clue for the active mission.
  ///
  /// Deliberately child-initiated. A wrong pick is answered by the companion
  /// reacting in place, so a child who is stuck has to ask for another clue
  /// rather than being handed one on every miss. Saturates at the last clue.
  void revealNextHint() {
    final mission = state.activeMission;
    if (mission == null) return;
    final last = mission.hints.length - 1;
    if (state.missionHintLevel >= last) return;
    state = state.copyWith(missionHintLevel: state.missionHintLevel + 1);
  }

  void showCelebration(AppMessage title, AppMessage description) {
    state = state.copyWith(celebrationTitle: title, celebrationDescription: description);
  }

  void closeCelebration() {
    // The success cue loops for the whole celebration, so this is the only
    // place it can be stopped: the dialog is dismissed through here and
    // nowhere else. The planet bed is a different service instance, so fading
    // this out does not disturb the narration that starts on the next state
    // change.
    _missionSound.stop();
    state = state.copyWith(
      celebrationTitle: null,
      celebrationDescription: null,
      // Back to the quiet pose. When another mission is waiting the companion
      // explains it instead, so the child is not left staring at a stale win.
      avatarMood: state.missions.any((m) => !m.completed)
          ? AvatarMood.instruction
          : AvatarMood.searching,
    );
  }

  /// Puts the companion into its talking pose, e.g. when the mission sheet is
  /// opened. Safe to call in any mood: it never interrupts a celebration.
  void setAvatarMood(AvatarMood mood) {
    if (state.avatarMood == AvatarMood.success) return;
    state = state.copyWith(avatarMood: mood);
  }

  /// Echoes a hotspot's name as a toast, for the dramatic ones that announce
  /// themselves. The name comes from the catalogue, so the toast carries the
  /// hotspot rather than a string and the view resolves the right language.
  void showHotspotToast(HotspotRef hotspot) {
    final key = ++_toastKey;
    state = state.copyWith(
      toasts: [...state.toasts, ToastMessage(key: key, hotspot: hotspot)],
    );
    _startToastTimer(key);
  }

  void showToast(AppMessage message) {
    final key = ++_toastKey;
    state = state.copyWith(toasts: [...state.toasts, ToastMessage(key: key, message: message)]);
    _startToastTimer(key);
  }

  /// One timer per toast: a single shared timer was cancelled by the next
  /// toast, which left every earlier toast on screen with nothing left to
  /// dismiss it.
  void _startToastTimer(int key) {
    final timer = Timer(const Duration(seconds: 3), () {
      _toastTimers.remove(key);
      if (!mounted) return;
      state = state.copyWith(toasts: state.toasts.where((t) => t.key != key).toList());
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

  void _checkMission(String planetId) {
    final activeId = state.activeMissionId;
    if (activeId == null) return;
    final idx = state.missions.indexWhere(
      (m) => m.id == activeId && !m.completed,
    );
    if (idx < 0) return;

    final mission = state.missions[idx];
    if (mission.targetPlanetId != planetId) {
      // A wrong pick is the companion's job alone. The user asked for no
      // dialog, no hint overlay, no toast, no failure sound, and no mission
      // narration here, because the avatar reacting in place already says it
      // and a child should not be interrupted by four things at once.
      //
      // The mission dialog does not open on a miss, and the hint level does
      // not advance, so there is no escalated clue to read out. The
      // companion's own bubble is the feedback, and it holds until the child
      // tries again.
      HapticFeedback.lightImpact();
      state = state.copyWith(
        wrongSelectionKey: state.wrongSelectionKey + 1,
        avatarMood: AvatarMood.wrong,
      );
      return;
    }

    final updated = List<MissionState>.from(state.missions);
    updated[idx] = mission.copyWith(completed: true);

    final nextIndex = updated.indexWhere((m) => !m.completed);
    final nextMissionId = nextIndex < 0 ? null : updated[nextIndex].id;
    state = state.copyWith(
      missions: updated,
      activeMissionId: nextMissionId,
      // Clues given away for the finished mission do not carry over: the next
      // mission starts from its own first clue.
      missionHintLevel: 0,
      // The companion celebrates in place rather than being replaced, and
      // drops back to calm when the celebration dialog is dismissed.
      avatarMood: AvatarMood.success,
    );
    _missionSound.startMissionSuccess();
    HapticFeedback.mediumImpact();
    showCelebration(
      AppMessage(AppMessageId.celebrationMissionTitle, {'id': mission.id}),
      AppMessage(AppMessageId.celebrationDiscovered, {'planetId': planetId}),
    );
    showToast(AppMessage(AppMessageId.toastMissionComplete, {'title': mission.title}));
  }

  /// Moves the companion from disappointed to encouraging.
  ///
  /// Called when the child taps the companion after a wrong pick. A later miss
  /// re-enters [AvatarMood.wrong] through _checkMission, so this line is only
  /// reached deliberately rather than by a timer racing the child.
  void retryMission() {
    if (state.avatarMood == AvatarMood.wrong ||
        state.avatarMood == AvatarMood.retry) {
      state = state.copyWith(avatarMood: AvatarMood.retry);
    }
  }

  @override
  void dispose() {
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    _toastTimers.clear();
    _spinHintTimer?.cancel();
    _playModeTimer?.cancel();
    _missionSound.dispose();
    super.dispose();
  }
}
