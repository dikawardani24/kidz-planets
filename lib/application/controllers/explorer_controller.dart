import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/mission.dart';
import '../state/explorer_state.dart';
import '../state/simulation_clock.dart';

class ExplorerController extends StateNotifier<ExplorerState> {
  ExplorerController({required SimulationClock clock, required List<Mission> initialMissions})
      : _clock = clock,
        super(ExplorerState(missions: initialMissions.map((m) => MissionState(id: m.id, title: m.title, description: m.description, targetPlanetId: m.targetPlanetId)).toList()));

  final SimulationClock _clock;
  Timer? _toastTimer;
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
    state = state.copyWith(
      selectedPlanetId: id, focusedPlanetId: id, detailZoom: 1.0,
      detailTheta: 0.65, detailPhi: 0.28, detailCardVisible: true,
      playModeBannerVisible: false, spinHintVisible: true,
    );
    _spinHintTimer?.cancel();
    _spinHintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && state.hasSelection) state = state.copyWith(spinHintVisible: false);
    });
    _checkMission(id);
  }

  void closeDetail() {
    _spinHintTimer?.cancel();
    _playModeTimer?.cancel();
    state = state.copyWith(
      selectedPlanetId: null, focusedPlanetId: null, detailCardVisible: true,
      spinHintVisible: false, playModeBannerVisible: false,
    );
  }

  void toggleDetailCard() {
    if (!state.hasSelection) return;
    final visible = !state.detailCardVisible;
    _playModeTimer?.cancel();
    state = state.copyWith(detailCardVisible: visible, playModeBannerVisible: !visible);
    if (!visible) {
      _playModeTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) state = state.copyWith(playModeBannerVisible: false);
      });
    }
  }

  void adjustDetailZoom(double delta) {
    if (!state.hasSelection) return;
    state = state.copyWith(detailZoom: (state.detailZoom + delta).clamp(0.4, 2.6));
  }

  void resetDetailView() {
    if (!state.hasSelection) return;
    state = state.copyWith(detailZoom: 1.0, detailTheta: 0.65, detailPhi: 0.28);
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
    final updated = List<MissionState>.from(state.missions);
    final mission = updated[idx];
    updated[idx] = mission.copyWith(completed: true);
    state = state.copyWith(missions: updated);
    showCelebration(mission.title, 'Fantastic! Mission successfully verified: '+mission.title+'!');
  }

  void showCelebration(String title, String description) {
    state = state.copyWith(celebrationTitle: title, celebrationDescription: description);
  }

  void closeCelebration() {
    state = state.copyWith(celebrationTitle: null, celebrationDescription: null);
  }

  void showToast(String text) {
    _toastTimer?.cancel();
    final key = ++_toastKey;
    state = state.copyWith(toasts: [...state.toasts, ToastMessage(key: key, text: text)]);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      state = state.copyWith(toasts: state.toasts.where((t) => t.key != key).toList());
    });
  }

  void _setExperimentAlert(String title, String description) {
    final icon = title.startsWith('☀️') ? '☀️' : title.startsWith('🪐') ? '🪐' : title.startsWith('🌪️') ? '🌪️' : '🔥';
    state = state.copyWith(playgroundAlertIcon: icon, playgroundAlertTitle: title, playgroundAlertDescription: description);
  }

  void _checkMission(String planetId) {
    final idx = state.missions.indexWhere((m) => m.targetPlanetId == planetId && !m.completed);
    if (idx < 0) return;
    completeFirstPendingFor(planetId);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _spinHintTimer?.cancel();
    _playModeTimer?.cancel();
    super.dispose();
  }
}
