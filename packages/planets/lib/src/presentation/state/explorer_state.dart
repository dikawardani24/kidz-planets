import 'package:equatable/equatable.dart';

import 'package:core/l10n.dart';
import 'package:planets/domain.dart';

/// What the solar-system explorer is showing and how fast.
///
/// This is the planets feature's own state and nothing else. Missions and the
/// companion avatar have their own state in their own packages, and the
/// application package wires them together by watching [selectedPlanetId] and
/// deciding what a tap means.
///
/// Keeping the pieces apart matters for one concrete reason. `avatarMood` used
/// to sit in here, which meant the 3D scene had to be rebuilt whenever a
/// mission changed the companion's expression, and the mission dialog had to
/// know the catalogue existed in order to name a planet.
class ExplorerState extends Equatable {
  const ExplorerState({
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
    this.playgroundAlertIcon = '\u{1F525}',
    this.playgroundAlertTitle = const AppMessage(
      AppMessageId.alertSandboxTitle,
    ),
    this.playgroundAlertDescription = const AppMessage(
      AppMessageId.alertSandboxDescription,
    ),
    this.toasts = const [],
  });

  /// Whether the planets are orbiting. Paused means the simulation clock is
  /// paused too; the two are never allowed to disagree.
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

  /// The one-off "drag to spin" nudge shown after a body is picked up.
  final bool spinHintVisible;
  final bool playModeBannerVisible;

  /// The playground's current callout: which icon, and the copy under it.
  final String playgroundAlertIcon;
  final AppMessage playgroundAlertTitle;
  final AppMessage playgroundAlertDescription;

  /// Transient notifications queued for the toast overlay.
  ///
  /// A queue rather than a single value so that one toast cannot dismiss
  /// another that is still on screen.
  final List<ToastMessage> toasts;

  bool get hasSelection => selectedPlanetId != null;

  ExplorerState copyWith({
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
    List<ToastMessage>? toasts,
  }) {
    return ExplorerState(
      running: running ?? this.running,
      speed: speed ?? this.speed,
      showOrbits: showOrbits ?? this.showOrbits,
      showLabels: showLabels ?? this.showLabels,
      selectedPlanetId: identical(selectedPlanetId, _sentinel)
          ? this.selectedPlanetId
          : selectedPlanetId as String?,
      focusedPlanetId: identical(focusedPlanetId, _sentinel)
          ? this.focusedPlanetId
          : focusedPlanetId as String?,
      detailZoom: detailZoom ?? this.detailZoom,
      detailTheta: detailTheta ?? this.detailTheta,
      detailPhi: detailPhi ?? this.detailPhi,
      detailHotspot: identical(detailHotspot, _sentinel)
          ? this.detailHotspot
          : detailHotspot as HotspotRef?,
      detailCardVisible: detailCardVisible ?? this.detailCardVisible,
      spinHintVisible: spinHintVisible ?? this.spinHintVisible,
      playModeBannerVisible:
          playModeBannerVisible ?? this.playModeBannerVisible,
      playgroundAlertIcon: playgroundAlertIcon ?? this.playgroundAlertIcon,
      playgroundAlertTitle: playgroundAlertTitle ?? this.playgroundAlertTitle,
      playgroundAlertDescription:
          playgroundAlertDescription ?? this.playgroundAlertDescription,
      toasts: toasts ?? this.toasts,
    );
  }

  @override
  List<Object?> get props => [
    running,
    speed,
    showOrbits,
    showLabels,
    selectedPlanetId,
    focusedPlanetId,
    detailZoom,
    detailTheta,
    detailPhi,
    detailHotspot,
    detailCardVisible,
    spinHintVisible,
    playModeBannerVisible,
    playgroundAlertIcon,
    playgroundAlertTitle,
    playgroundAlertDescription,
    toasts,
  ];
}

const _sentinel = Object();

/// A transient on-screen notification.
///
/// Either controller-authored copy resolved through [AppMessageId], or a
/// catalogue hotspot resolved against the active locale by the view. The
/// hotspot case exists because a hotspot name is data rather than a UI string,
/// so it has to come from the same translation table the detail card uses.
class ToastMessage extends Equatable {
  const ToastMessage({required this.key, this.message, this.hotspot})
    : assert(
        (message == null) != (hotspot == null),
        'a toast carries either an AppMessage or a Hotspot, not both',
      );

  final int key;
  final AppMessage? message;
  final HotspotRef? hotspot;

  @override
  List<Object?> get props => [key, message, hotspot];
}
