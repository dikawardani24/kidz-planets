import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/planet.dart';
import '../../infrastructure/services/planet_sound_service.dart';
import '../state/explorer_state.dart';
import '../state/simulation_clock.dart';

class ExplorerController extends StateNotifier<ExplorerState> {
  ExplorerController({required this._clock, required List<Mission> initialMissions})
      : super(ExplorerState(missions: initialMissions.map((m) => MissionState(id: m.id, title: m.title, description: m.description, targetPlanetId: m.targetPlanetId, startPoint: m.startPoint, direction: m.direction, hint: m.hint)).toList()));

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
      detailTheta: 0.65, detailPhi: 0.28, detailTitleOverride: null, detailDescriptionOverride: null,
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
      selectedPlanetId: null, focusedPlanetId: null, detailTitleOverride: null, detailDescriptionOverride: null, detailCardVisible: false,
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

  void showHotspot(Hotspot hotspot) {
    state = state.copyWith(detailTitleOverride: hotspot.title, detailDescriptionOverride: hotspot.description);
    final polar = hotspot.title.contains('Polar') || hotspot.title.contains('Ice');
    final rings = hotspot.title.contains('Ring') || hotspot.title.contains('Cassini') || hotspot.title.contains('Tilt');
    final storm = hotspot.title.contains('Storm') || hotspot.title.contains('Spot') || hotspot.title.contains('Flares');
    updateDetailCamera(phi: polar ? .95 : rings ? .65 : state.detailPhi, zoom: rings ? .85 : state.detailZoom);
    if (storm) showToast(hotspot.title);
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
        _setExperimentAlert('🔥 Earth Moved Closer!', 'Intense solar radiation evaporates oceans instantly!');
        break;
      case 'saturn':
        _setExperimentAlert('🪐 Saturn Rings Focused!', 'Rings consist of billions of icy space boulders with Cassini gap!');
        selectPlanet('saturn');
        break;
      case 'jupiter':
        _setExperimentAlert('🌪️ Jupiter Storm Focused!', 'The Great Red Spot is a monster storm wider than planet Earth!');
        selectPlanet('jupiter');
        break;
      case 'sun':
        _setExperimentAlert('☀️ Blazing Sun Focused!', 'Nuclear fusion heats the core to 15,000,000°C with dynamic solar flares!');
        selectPlanet('sun');
        break;
    }
    if (state.tab != ExplorerTab.explore) state = state.copyWith(tab: ExplorerTab.explore);
  }

  void resetPlayground() {
    _clock.setSpeed(1.0);
    state = state.copyWith(speed: 1.0, showOrbits: true, showLabels: true, playgroundAlertIcon: '🔥', playgroundAlertTitle: 'Sandbox Ready!', playgroundAlertDescription: 'Run interactive NASA 3D experiments below.');
    showToast('🔥 Sandbox Ready! Run interactive NASA 3D experiments below.');
  }

  void completeFirstPendingFor(String planetId) {
    final idx = state.missions.indexWhere((m) => m.targetPlanetId == planetId && !m.completed);
    if (idx < 0) return;
    final mission = state.missions[idx];
    final updated = List<MissionState>.from(state.missions);
    updated[idx] = mission.copyWith(completed: true);
    state = state.copyWith(missions: updated);
    showCelebration(mission.title, 'Fantastic! Mission successfully verified: ${mission.title}!');
    showToast('Mission complete: ${mission.title}');
  }

  void toggleMissionGuide() {
    state = state.copyWith(missionGuideVisible: !state.missionGuideVisible);
  }

  void showCelebration(String title, String description) {
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

  void showToast(String text) {
    final key = ++_toastKey;
    state = state.copyWith(toasts: [...state.toasts, ToastMessage(key: key, text: text)]);
    // One timer per toast: a single shared timer was cancelled by the next
    // toast, which left every earlier toast on screen with nothing left to
    // dismiss it.
    final timer = Timer(const Duration(seconds: 3), () {
      _toastTimers.remove(key);
      if (!mounted) return;
      state = state.copyWith(toasts: state.toasts.where((t) => t.key != key).toList());
    });
    _toastTimers[key] = timer;
  }

  void _setExperimentAlert(String title, String description) {
    final icon = title.startsWith('☀️') ? '☀️' : title.startsWith('🪐') ? '🪐' : title.startsWith('🌪️') ? '🌪️' : '🔥';
    state = state.copyWith(playgroundAlertIcon: icon, playgroundAlertTitle: title, playgroundAlertDescription: description);
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
      // `missionGuideVisible` is deliberately not set, so the mission dialog
      // does not open on a miss, and the hint level does not advance, so there
      // is no escalated clue to read out. The companion's own bubble is the
      // feedback, and it holds until the child tries again.
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
      // The companion celebrates in place rather than being replaced, and
      // drops back to calm when the celebration dialog is dismissed.
      avatarMood: AvatarMood.success,
    );
    final targetName = mission.title
        .replaceFirst('Find ', '')
        .replaceFirst('Visit ', '');
    _missionSound.startMissionSuccess();
    HapticFeedback.mediumImpact();
    showCelebration(
      'Mission ${mission.id} Complete!',
      'You discovered $targetName. Ready for the next mission?',
    );
    showToast('🚀 Mission complete: ${mission.title}');
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
