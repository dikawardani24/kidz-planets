import 'package:equatable/equatable.dart';

enum ExplorerTab { explore, playground, missions }

class ExplorerState extends Equatable {
  const ExplorerState({
    this.tab = ExplorerTab.explore,
    this.running = true,
    this.speed = 1.0,
    this.showOrbits = true,
    this.showLabels = true,
    this.selectedPlanetId,
    this.focusedPlanetId,
    this.detailZoom = 1.0,
    this.detailTheta = 0.65,
    this.detailPhi = 0.28,
    this.detailCardVisible = true,
    this.spinHintVisible = false,
    this.playModeBannerVisible = false,
    this.playgroundAlertIcon = '🔥',
    this.playgroundAlertTitle = 'Sandbox Ready!',
    this.playgroundAlertDescription = 'Run interactive NASA 3D experiments below.',
    this.missions = const [],
    this.toasts = const [],
    this.celebrationTitle,
    this.celebrationDescription,
  });

  final ExplorerTab tab;
  final bool running;
  final double speed;
  final bool showOrbits;
  final bool showLabels;
  final String? selectedPlanetId;
  final String? focusedPlanetId;
  final double detailZoom;
  final double detailTheta;
  final double detailPhi;
  final bool detailCardVisible;
  final bool spinHintVisible;
  final bool playModeBannerVisible;
  final String playgroundAlertIcon;
  final String playgroundAlertTitle;
  final String playgroundAlertDescription;
  final List<MissionState> missions;
  final List<ToastMessage> toasts;
  final String? celebrationTitle;
  final String? celebrationDescription;

  bool get hasSelection => selectedPlanetId != null;
  bool get celebrationVisible => celebrationTitle != null && celebrationDescription != null;

  ExplorerState copyWith({
    ExplorerTab? tab,
    bool? running,
    double? speed,
    bool? showOrbits,
    bool? showLabels,
    Object? selectedPlanetId = _sentinel,
    Object? focusedPlanetId = _sentinel,
    double? detailZoom,
    double? detailTheta,
    double? detailPhi,
    bool? detailCardVisible,
    bool? spinHintVisible,
    bool? playModeBannerVisible,
    String? playgroundAlertIcon,
    String? playgroundAlertTitle,
    String? playgroundAlertDescription,
    List<MissionState>? missions,
    List<ToastMessage>? toasts,
    Object? celebrationTitle = _sentinel,
    Object? celebrationDescription = _sentinel,
  }) {
    return ExplorerState(
      tab: tab ?? this.tab,
      running: running ?? this.running,
      speed: speed ?? this.speed,
      showOrbits: showOrbits ?? this.showOrbits,
      showLabels: showLabels ?? this.showLabels,
      selectedPlanetId: identical(selectedPlanetId, _sentinel) ? this.selectedPlanetId : selectedPlanetId as String?,
      focusedPlanetId: identical(focusedPlanetId, _sentinel) ? this.focusedPlanetId : focusedPlanetId as String?,
      detailZoom: detailZoom ?? this.detailZoom,
      detailTheta: detailTheta ?? this.detailTheta,
      detailPhi: detailPhi ?? this.detailPhi,
      detailCardVisible: detailCardVisible ?? this.detailCardVisible,
      spinHintVisible: spinHintVisible ?? this.spinHintVisible,
      playModeBannerVisible: playModeBannerVisible ?? this.playModeBannerVisible,
      playgroundAlertIcon: playgroundAlertIcon ?? this.playgroundAlertIcon,
      playgroundAlertTitle: playgroundAlertTitle ?? this.playgroundAlertTitle,
      playgroundAlertDescription: playgroundAlertDescription ?? this.playgroundAlertDescription,
      missions: missions ?? this.missions,
      toasts: toasts ?? this.toasts,
      celebrationTitle: identical(celebrationTitle, _sentinel) ? this.celebrationTitle : celebrationTitle as String?,
      celebrationDescription: identical(celebrationDescription, _sentinel) ? this.celebrationDescription : celebrationDescription as String?,
    );
  }

  @override
  List<Object?> get props => [
        tab, running, speed, showOrbits, showLabels, selectedPlanetId, focusedPlanetId,
        detailZoom, detailTheta, detailPhi, detailCardVisible, spinHintVisible,
        playModeBannerVisible, playgroundAlertIcon, playgroundAlertTitle, playgroundAlertDescription, missions, toasts, celebrationTitle, celebrationDescription,
      ];
}

const _sentinel = Object();

class MissionState extends Equatable {
  const MissionState({required this.id, required this.title, required this.description, required this.targetPlanetId, this.completed = false});
  final int id;
  final String title;
  final String description;
  final String targetPlanetId;
  final bool completed;
  MissionState copyWith({bool? completed}) => MissionState(id: id, title: title, description: description, targetPlanetId: targetPlanetId, completed: completed ?? this.completed);
  @override
  List<Object?> get props => [id, completed];
}

class ToastMessage extends Equatable {
  const ToastMessage({required this.key, required this.text});
  final int key;
  final String text;
  @override
  List<Object?> get props => [key, text];
}
