import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/mission.dart';
import '../state/explorer_state.dart';
import '../state/simulation_clock.dart';

class ExplorerController extends StateNotifier<ExplorerState> {
  ExplorerController({
    required SimulationClock clock,
    required List<Mission> initialMissions,
  })  : _clock = clock,
        super(ExplorerState(
          missions: initialMissions.map((m) => MissionState(
            id: m.id,
            title: m.title,
            description: m.description,
            targetPlanetId: m.targetPlanetId,
          )).toList(),
        ));

  final SimulationClock _clock;
  Timer? _toastTimer;
  int _toastKey = 0;

  void setTab(ExplorerTab tab) => state = state.copyWith(tab: tab);

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

  void selectPlanet(String id) {
    state = state.copyWith(
      selectedPlanetId: id,
      focusedPlanetId: id,
      detailZoom: 1.0,
      detailTheta: 0.65,
      detailPhi: 0.28,
    );
    _checkMissions(id);
  }

  void closeDetail() {
    state = ExplorerState(
      tab: state.tab,
      running: state.running,
      speed: state.speed,
      showOrbits: state.showOrbits,
      showLabels: state.showLabels,
      detailZoom: state.detailZoom,
      detailTheta: state.detailTheta,
      detailPhi: state.detailPhi,
      missions: state.missions,
      toasts: state.toasts,
    );
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
      case 'sun':
        selectPlanet('sun');
        showToast('☀️ Inspecting the blazing Sun');
      case 'earth':
        selectPlanet('earth');
        showToast('🌍 Earth moved closer for this experiment');
      case 'saturn':
        selectPlanet('saturn');
        showToast("🪐 Inspect Saturn's rings");
      case 'earth-explore':
        selectPlanet('earth');
        showToast('🌎 Explore Earth in 3D');
    }
  }

  void completeFirstPendingFor(String planetId) {
    final idx = state.missions.indexWhere((m) => m.targetPlanetId == planetId);
    if (idx < 0 || state.missions[idx].completed) return;
    final updated = List<MissionState>.from(state.missions);
    updated[idx] = updated[idx].copyWith(completed: true);
    state = state.copyWith(missions: updated);
    showToast('Mission Complete: Found ' + _planetName(planetId) + '!');
  }

  void showToast(String text) {
    _toastTimer?.cancel();
    final key = ++_toastKey;
    state = state.copyWith(toasts: [...state.toasts, ToastMessage(key: key, text: text)]);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      state = state.copyWith(toasts: state.toasts.where((t) => t.key != key).toList());
    });
  }

  void _checkMissions(String planetId) {
    final pending = state.missions.where((m) => !m.completed && m.targetPlanetId == planetId);
    if (pending.isNotEmpty) completeFirstPendingFor(planetId);
  }

  String _planetName(String id) {
    switch (id) {
      case 'sun': return 'the Sun';
      case 'mercury': return 'Mercury';
      case 'venus': return 'Venus';
      case 'earth': return 'Earth';
      case 'mars': return 'Mars';
      case 'jupiter': return 'Jupiter';
      case 'saturn': return 'Saturn';
      case 'uranus': return 'Uranus';
      case 'neptune': return 'Neptune';
      default: return id;
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }
}
