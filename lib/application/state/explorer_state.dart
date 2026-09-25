import 'package:equatable/equatable.dart';

/// Which bottom tab is active.
enum ExplorerTab { explore, planets, missions }

/// Immutable UI state for the whole explorer screen (single source of truth).
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
    this.isDetailCardVisible = true,
    this.missions = const [],
    this.toasts = const [],
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
  /// Prototype parity: facts dialog vs minimized "play mode" pill.
  /// `toggleDetailCard()` in prototype/index.html flips this.
  final bool isDetailCardVisible;
  final List<MissionState> missions;
  final List<ToastMessage> toasts;

  bool get hasSelection => selectedPlanetId != null;

  ExplorerState copyWith({
    ExplorerTab? tab,
    bool? running,
    double? speed,
    bool? showOrbits,
    bool? showLabels,
    String? selectedPlanetId,
    Object? focusedPlanetId = _sentinel,
    double? detailZoom,
    double? detailTheta,
    double? detailPhi,
    bool? isDetailCardVisible,
    List<MissionState>? missions,
    List<ToastMessage>? toasts,
  }) {
    return ExplorerState(
      tab: tab ?? this.tab,
      running: running ?? this.running,
      speed: speed ?? this.speed,
      showOrbits: showOrbits ?? this.showOrbits,
      showLabels: showLabels ?? this.showLabels,
      selectedPlanetId: selectedPlanetId ?? this.selectedPlanetId,
      focusedPlanetId: identical(focusedPlanetId, _sentinel)
          ? this.focusedPlanetId
          : focusedPlanetId as String?,
      detailZoom: detailZoom ?? this.detailZoom,
      detailTheta: detailTheta ?? this.detailTheta,
      detailPhi: detailPhi ?? this.detailPhi,
      isDetailCardVisible: isDetailCardVisible ?? this.isDetailCardVisible,
      missions: missions ?? this.missions,
      toasts: toasts ?? this.toasts,
    );
  }

  ExplorerState clearSelection() => copyWith(
        selectedPlanetId: '__none__',
        focusedPlanetId: null,
      )._fixClearedSelection();

  ExplorerState _fixClearedSelection() => ExplorerState(
        tab: tab,
        running: running,
        speed: speed,
        showOrbits: showOrbits,
        showLabels: showLabels,
        selectedPlanetId: null,
        focusedPlanetId: null,
        detailZoom: detailZoom,
        detailTheta: detailTheta,
        detailPhi: detailPhi,
        isDetailCardVisible: true,
        missions: missions,
        toasts: toasts,
      );

  @override
  List<Object?> get props => [
        tab,
        running,
        speed,
        showOrbits,
        showLabels,
        selectedPlanetId,
        focusedPlanetId,
        detailZoom,
        detailTheta,
        detailPhi,
        isDetailCardVisible,
        missions,
        toasts,
      ];
}

const _sentinel = Object();

/// Riverpod-friendly mission row state.
class MissionState extends Equatable {
  const MissionState({
    required this.id,
    required this.title,
    required this.description,
    required this.targetPlanetId,
    this.completed = false,
  });

  final int id;
  final String title;
  final String description;
  final String targetPlanetId;
  final bool completed;

  MissionState copyWith({bool? completed}) => MissionState(
        id: id,
        title: title,
        description: description,
        targetPlanetId: targetPlanetId,
        completed: completed ?? this.completed,
      );

  @override
  List<Object?> get props => [id, completed];
}

/// Transient toast banner.
class ToastMessage extends Equatable {
  const ToastMessage({required this.key, required this.text});

  final int key;
  final String text;

  @override
  List<Object?> get props => [key, text];
}
