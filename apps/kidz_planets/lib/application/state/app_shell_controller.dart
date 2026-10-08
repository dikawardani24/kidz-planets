// The analyzer's `prefer_initializing_formals` fix is a named parameter
// starting with an underscore, which Dart forbids: the constructor would become
// uncallable. The fields stay private and the public parameter names stay
// readable, so the lint is switched off for this file.
// ignore_for_file: prefer_initializing_formals

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:avatar/state.dart';
import 'package:core/l10n.dart';
import 'package:mission/state.dart';

/// Which of the three spaces is showing.
enum AppTab { explore, playground, missions }

/// App-level state that belongs to no single feature: the current tab and the
/// companion's mood.
///
/// Everything else was pushed down into the feature that owns it. This is what
/// is left once the tab strip and the avatar's expression are separated from the
/// catalogue, the missions and the camera.
class AppShellState extends Equatable {
  const AppShellState({
    this.tab = AppTab.explore,
    this.avatarMood = AvatarMood.searching,
    this.avatarPageVisible = false,
  });

  final AppTab tab;

  /// The companion's expression. Owned here rather than by the avatar because
  /// it is chosen from what just happened elsewhere: a mission was explained, a
  /// tap missed, a mission completed. The avatar decides what a mood looks and
  /// sounds like; only the shell knows why.
  final AvatarMood avatarMood;

  /// Whether the avatar selection page covers the screen. An overlay flag
  /// rather than a fourth tab, so opening it never disturbs the current tab:
  /// closing it returns the child to exactly where they were.
  final bool avatarPageVisible;

  AppShellState copyWith({
    AppTab? tab,
    AvatarMood? avatarMood,
    bool? avatarPageVisible,
  }) => AppShellState(
    tab: tab ?? this.tab,
    avatarMood: avatarMood ?? this.avatarMood,
    avatarPageVisible: avatarPageVisible ?? this.avatarPageVisible,
  );

  @override
  List<Object?> get props => [tab, avatarMood, avatarPageVisible];
}

/// The composition root's controller.
///
/// It owns the wiring and nothing else. A tap on a body is turned into a
/// mission outcome here, that outcome is turned into an avatar mood here, and
/// the effects that need a platform (haptics, the mission cue) happen here too.
/// Each feature still only knows its own state, which is what lets them be read,
/// changed and tested apart.
class AppShellController extends StateNotifier<AppShellState> {
  AppShellController({
    required MissionProgressController missions,
    required void Function(AppMessage message) showToast,
    required void Function() closeDetail,
    required void Function() startSuccessCue,
    required void Function() stopSuccessCue,
    void Function(String planetId)? playPlanetSound,
    void Function()? lightHaptic,
    void Function()? mediumHaptic,
  }) : _missions = missions,
       _showToast = showToast,
       _closeDetail = closeDetail,
       _startSuccessCue = startSuccessCue,
       _stopSuccessCue = stopSuccessCue,
       _playPlanetSound = playPlanetSound ?? ((_) {}),
       _lightHaptic = lightHaptic ?? HapticFeedback.lightImpact,
       _mediumHaptic = mediumHaptic ?? HapticFeedback.mediumImpact,
       super(const AppShellState());

  final MissionProgressController _missions;
  final void Function() _closeDetail;
  final void Function(AppMessage message) _showToast;
  final void Function() _startSuccessCue;
  final void Function() _stopSuccessCue;
  final void Function(String planetId) _playPlanetSound;
  final void Function() _lightHaptic;
  final void Function() _mediumHaptic;

  void setTab(AppTab tab) {
    if (tab != AppTab.explore) _closeDetail();
    state = state.copyWith(tab: tab);
  }

  /// Opens the avatar selection page over the current tab.
  void openAvatarPage() {
    state = state.copyWith(avatarPageVisible: true);
  }

  /// Returns from the avatar selection page to the tab underneath, untouched.
  void closeAvatarPage() {
    state = state.copyWith(avatarPageVisible: false);
  }

  /// Grades a tap that the planets feature has already put into its own state.
  ///
  /// The planets feature reports only the id. Whether that id was the mission
  /// target is decided here, because only this layer is allowed to know about
  /// both features at once. Called from [appShellProvider], which watches the
  /// explorer's selection.
  void handlePlanetSelected(String planetId) {
    _playPlanetSound(planetId);

    final completedBefore = _missions.state.missions
        .where((m) => m.completed)
        .map((m) => m.id)
        .toSet();

    switch (_missions.evaluateSelection(planetId)) {
      case MissionOutcome.miss:
        _lightHaptic();
        setAvatarMood(AvatarMood.wrong);
      case MissionOutcome.complete:
        _startSuccessCue();
        _mediumHaptic();
        _showToast(
          AppMessage(AppMessageId.toastMissionComplete, {
            'title': _justCompleted(completedBefore)?.title ?? '',
          }),
        );
        // The companion celebrates in place rather than being replaced, and
        // drops back to calm when the dialog is dismissed.
        setAvatarMood(AvatarMood.success);
      case MissionOutcome.ignored:
        break;
    }
  }

  /// The sandbox path: finishes the first pending mission for [planetId].
  ///
  /// The child did not tap the thing the mission was asking for, so the
  /// curriculum does not advance; the mission package has already recorded that
  /// and raised the celebration dialog.
  void completeFirstPendingFor(String planetId) {
    if (!_missions.completeFirstPendingFor(planetId)) return;
    final mission = _missions.state.missions.firstWhere(
      (m) => m.targetPlanetId == planetId && m.completed,
    );
    _showToast(
      AppMessage(AppMessageId.toastMissionVerified, {'title': mission.title}),
    );
  }

  void revealNextHint() => _missions.revealNextHint();

  void closeCelebration() {
    // The success cue loops for the whole celebration, so this is the only
    // place it can be stopped: the dialog is dismissed through here and
    // nowhere else. The planet bed is a different service instance, so fading
    // this out does not disturb the narration that starts on the next state
    // change.
    _stopSuccessCue();
    _missions.closeCelebration();
    // Back to the quiet pose. When another mission is waiting the companion
    // explains it instead, so the child is not left staring at a stale win.
    //
    // Assigned rather than routed through setAvatarMood, because that guard
    // exists to protect a win in progress from being overwritten by an unrelated
    // mood change, and dismissing the dialog is how the win ends. Going through
    // it would leave the companion permanently frozen on success.
    state = state.copyWith(
      avatarMood: _missions.state.hasPendingMission
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

  /// Moves the companion from disappointed to encouraging.
  ///
  /// Called when the child taps the companion after a wrong pick. A later miss
  /// re-enters [AvatarMood.wrong] through [handlePlanetSelected], so this is
  /// only reached deliberately rather than by a timer racing the child.
  void retryMission() {
    final mood = state.avatarMood;
    if (mood == AvatarMood.wrong || mood == AvatarMood.retry) {
      state = state.copyWith(avatarMood: AvatarMood.retry);
    }
  }

  /// The mission that has just been completed, if it was not before.
  ///
  /// The id set is captured before grading so the toast announces the mission
  /// that was just finished rather than whichever completed one happens to come
  /// first in the list.
  MissionState? _justCompleted(Set<int> completedBefore) {
    for (final mission in _missions.state.missions) {
      if (mission.completed && !completedBefore.contains(mission.id)) {
        return mission;
      }
    }
    return null;
  }
}
