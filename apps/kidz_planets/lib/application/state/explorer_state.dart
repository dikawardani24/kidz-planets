import 'package:equatable/equatable.dart';
import '../../domain/entities/planet.dart';
import 'app_message.dart';

enum ExplorerTab { explore, playground, missions }

/// What the mission companion avatar is doing and saying right now.
///
/// The companion is always on screen, so the mood is the only thing that
/// changes; the character identity and its home on screen do not. It is stored
/// in state rather than derived, because "retry" and "searching" look the same
/// but mean different things to the child: retry follows a miss and earns an
/// encouraging line, searching is just the calm default.
enum AvatarMood {
  /// A mission is being explained. Talking, excited pose.
  instruction,

  /// The child is looking around. Curious, quiet, does not interrupt.
  searching,

  /// The child picked the wrong object. Disappointed but never cross.
  wrong,

  /// Immediately after a miss, once the failure pose has been seen.
  retry,

  /// A mission was completed. Celebrating.
  success,
}

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
    this.detailHotspot,
    this.detailCardVisible = true,
    this.spinHintVisible = false,
    this.playModeBannerVisible = false,
    this.playgroundAlertIcon = '🔥',
    this.playgroundAlertTitle = const AppMessage(AppMessageId.alertSandboxTitle),
    this.playgroundAlertDescription = const AppMessage(AppMessageId.alertSandboxDescription),
    this.missions = const [],
    this.toasts = const [],
    this.celebrationTitle,
    this.celebrationDescription,
    this.activeMissionId = 1,
    this.missionHintLevel = 0,
    this.wrongSelectionKey = 0,
    this.avatarMood = AvatarMood.searching,
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
  /// The hotspot whose copy the detail card is showing instead of the body's.
  /// Null means the card is describing the planet itself.
  final HotspotRef? detailHotspot;
  final bool detailCardVisible;
  final bool spinHintVisible;
  final bool playModeBannerVisible;
  final String playgroundAlertIcon;
  final AppMessage playgroundAlertTitle;
  final AppMessage playgroundAlertDescription;
  final List<MissionState> missions;
  final List<ToastMessage> toasts;
  final AppMessage? celebrationTitle;
  final AppMessage? celebrationDescription;
  final int? activeMissionId;

  /// How many extra clues the child has asked for on [activeMissionId].
  /// Reset to zero whenever the active mission moves on.
  final int missionHintLevel;
  final int wrongSelectionKey;

  /// Drives the companion's pose and line. Defaults to [AvatarMood.searching]
  /// so the companion has something to say before the first mission runs.
  final AvatarMood avatarMood;

  bool get hasSelection => selectedPlanetId != null;
  bool get celebrationVisible => celebrationTitle != null && celebrationDescription != null;

  /// The active mission, or null once every mission is complete. The companion
  /// needs the target planet to render the object the child is hunting for, and
  /// that must come from the current mission rather than being hardcoded.
  MissionState? get activeMission {
    final id = activeMissionId;
    if (id == null) return null;
    for (final mission in missions) {
      if (mission.id == id && !mission.completed) return mission;
    }
    return null;
  }

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
    Object? detailHotspot = _sentinel,
    bool? detailCardVisible,
    bool? spinHintVisible,
    bool? playModeBannerVisible,
    String? playgroundAlertIcon,
    AppMessage? playgroundAlertTitle,
    AppMessage? playgroundAlertDescription,
    List<MissionState>? missions,
    List<ToastMessage>? toasts,
    Object? celebrationTitle = _sentinel,
    Object? celebrationDescription = _sentinel,
    Object? activeMissionId = _sentinel,
    int? missionHintLevel,
    int? wrongSelectionKey,
    AvatarMood? avatarMood,
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
      detailHotspot: identical(detailHotspot, _sentinel) ? this.detailHotspot : detailHotspot as HotspotRef?,
      detailCardVisible: detailCardVisible ?? this.detailCardVisible,
      spinHintVisible: spinHintVisible ?? this.spinHintVisible,
      playModeBannerVisible: playModeBannerVisible ?? this.playModeBannerVisible,
      playgroundAlertIcon: playgroundAlertIcon ?? this.playgroundAlertIcon,
      playgroundAlertTitle: playgroundAlertTitle ?? this.playgroundAlertTitle,
      playgroundAlertDescription: playgroundAlertDescription ?? this.playgroundAlertDescription,
      missions: missions ?? this.missions,
      toasts: toasts ?? this.toasts,
      celebrationTitle: identical(celebrationTitle, _sentinel) ? this.celebrationTitle : celebrationTitle as AppMessage?,
      celebrationDescription: identical(celebrationDescription, _sentinel) ? this.celebrationDescription : celebrationDescription as AppMessage?,
      activeMissionId: identical(activeMissionId, _sentinel) ? this.activeMissionId : activeMissionId as int?,
      missionHintLevel: missionHintLevel ?? this.missionHintLevel,
      wrongSelectionKey: wrongSelectionKey ?? this.wrongSelectionKey,
      avatarMood: avatarMood ?? this.avatarMood,
    );
  }

  @override
  List<Object?> get props => [
        tab, running, speed, showOrbits, showLabels, selectedPlanetId, focusedPlanetId,
        detailZoom, detailTheta, detailPhi, detailHotspot, detailCardVisible, spinHintVisible,
        playModeBannerVisible, playgroundAlertIcon, playgroundAlertTitle, playgroundAlertDescription, missions, toasts, celebrationTitle, celebrationDescription, activeMissionId, missionHintLevel, wrongSelectionKey, avatarMood,
      ];
}

const _sentinel = Object();

class MissionState extends Equatable {
  const MissionState({required this.id, required this.title, required this.description, required this.targetPlanetId, this.startPoint, this.direction, this.hints = const [], this.completed = false});
  final int id;
  final String title;
  final String description;
  final String targetPlanetId;
  final String? startPoint;
  final String? direction;

  /// Escalating clues, revealed one at a time. See [Mission.hints].
  final List<String> hints;
  final bool completed;
  MissionState copyWith({bool? completed}) => MissionState(id: id, title: title, description: description, targetPlanetId: targetPlanetId, startPoint: startPoint, direction: direction, hints: hints, completed: completed ?? this.completed);

  /// The clue at [level], clamped to the last one so asking for more clues
  /// past the end repeats the final one rather than throwing.
  String clueAt(int level) {
    if (hints.isEmpty) return description;
    return hints[level.clamp(0, hints.length - 1)];
  }

  @override
  List<Object?> get props => [id, completed];
}

class ToastMessage extends Equatable {
  const ToastMessage({required this.key, this.message, this.hotspot})
      : assert(
          (message == null) != (hotspot == null),
          'a toast carries either an AppMessage or a Hotspot, not both',
        );

  final int key;

  /// Controller-authored copy, resolved through [AppMessageId].
  final AppMessage? message;

  /// Catalogue copy, resolved against the active locale by the view. Used for
  /// hotspot names, which are data rather than UI strings.
  final HotspotRef? hotspot;

  @override
  List<Object?> get props => [key, message, hotspot];
}
