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
    this.detailTitleOverride,
    this.detailDescriptionOverride,
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
    this.activeMissionId = 1,
    this.missionGuideVisible = true,
    this.missionHintLevel = 0,
    this.wrongSelectionKey = 0,
    this.wrongFeedbackVisible = false,
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
  final String? detailTitleOverride;
  final String? detailDescriptionOverride;
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
  final int? activeMissionId;
  final bool missionGuideVisible;
  final int missionHintLevel;
  final int wrongSelectionKey;
  final bool wrongFeedbackVisible;

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
    Object? detailTitleOverride = _sentinel,
    Object? detailDescriptionOverride = _sentinel,
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
    Object? activeMissionId = _sentinel,
    bool? missionGuideVisible,
    int? missionHintLevel,
    int? wrongSelectionKey,
    bool? wrongFeedbackVisible,
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
      detailTitleOverride: identical(detailTitleOverride, _sentinel) ? this.detailTitleOverride : detailTitleOverride as String?,
      detailDescriptionOverride: identical(detailDescriptionOverride, _sentinel) ? this.detailDescriptionOverride : detailDescriptionOverride as String?,
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
      activeMissionId: identical(activeMissionId, _sentinel) ? this.activeMissionId : activeMissionId as int?,
      missionGuideVisible: missionGuideVisible ?? this.missionGuideVisible,
      missionHintLevel: missionHintLevel ?? this.missionHintLevel,
      wrongSelectionKey: wrongSelectionKey ?? this.wrongSelectionKey,
      wrongFeedbackVisible: wrongFeedbackVisible ?? this.wrongFeedbackVisible,
    );
  }

  @override
  List<Object?> get props => [
        tab, running, speed, showOrbits, showLabels, selectedPlanetId, focusedPlanetId,
        detailZoom, detailTheta, detailPhi, detailTitleOverride, detailDescriptionOverride, detailCardVisible, spinHintVisible,
        playModeBannerVisible, playgroundAlertIcon, playgroundAlertTitle, playgroundAlertDescription, missions, toasts, celebrationTitle, celebrationDescription, activeMissionId, missionGuideVisible, missionHintLevel, wrongSelectionKey, wrongFeedbackVisible,
      ];
}

const _sentinel = Object();

class MissionState extends Equatable {
  const MissionState({required this.id, required this.title, required this.description, required this.targetPlanetId, this.startPoint, this.direction, this.hint, this.completed = false});
  final int id;
  final String title;
  final String description;
  final String targetPlanetId;
  final String? startPoint;
  final String? direction;
  final String? hint;
  final bool completed;
  MissionState copyWith({bool? completed}) => MissionState(id: id, title: title, description: description, targetPlanetId: targetPlanetId, startPoint: startPoint, direction: direction, hint: hint, completed: completed ?? this.completed);
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
