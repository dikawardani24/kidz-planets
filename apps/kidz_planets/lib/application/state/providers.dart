import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/l10n.dart';
import 'package:mission/state.dart';
import 'package:planets/audio.dart';
import 'package:planets/data.dart';
import 'package:planets/state.dart';

import 'app_shell_controller.dart';

export 'app_shell_controller.dart';

/// App-level state: the current tab and the companion's mood.
///
/// This is where the two features meet. The explorer is used exactly as the
/// planets package ships it; the shell watches it for a new selection and asks
/// the mission feature whether that tap was the target. Nothing is overridden,
/// so there is only ever one explorer and one mission progress in the container
/// and either could be watched by a widget without knowing about this file.
final appShellProvider = StateNotifierProvider<AppShellController, AppShellState>((
  ref,
) {
  final shell = AppShellController(
    missions: ref.watch(missionProgressProvider.notifier),
    // Lazy lookups rather than values captured here, so the shell can be built
    // without dragging the scene and the audio player into a cycle.
    showToast: (message) =>
        ref.read(explorerControllerProvider.notifier).showToast(message),
    closeDetail: () =>
        ref.read(explorerControllerProvider.notifier).closeDetail(),
    // The feature's own provider, which `main` overrides with the app-wide
    // singleton. Reading it here rather than building another player is what
    // stops the celebration loop from running under the planet narration.
    startSuccessCue: ref.read(planetSoundServiceProvider).startMissionSuccess,
    stopSuccessCue: ref.read(planetSoundServiceProvider).stop,
  );

  // A tap that lands on the body already selected is not a new selection, so it
  // is not graded again. Reading the explorer here is safe: the explorer does
  // not read the shell, which is the only reason this direction can be a plain
  // watch instead of a hand-built bridge.
  ref.listen<ExplorerState>(explorerControllerProvider, (previous, next) {
    final planetId = next.selectedPlanetId;
    if (planetId == null || planetId == previous?.selectedPlanetId) return;
    shell.handlePlanetSelected(planetId);
  });

  return shell;
});

/// Resolves a body id to its name, for core's message templates.
///
/// Core owns the template that names a discovered body but not the catalogue it
/// names from, so the lookup is supplied here where both halves are visible.
final bodyNameResolverProvider = Provider<BodyNameResolver>((ref) {
  return localizedPlanetName;
});

/// The curriculum as the UI sees it.
final missionsProvider = Provider<List<MissionState>>((ref) {
  return ref.watch(missionProgressProvider.select((s) => s.missions));
});

/// The active mission, or null once every mission is complete.
final activeMissionProvider = Provider<MissionState?>((ref) {
  return ref.watch(missionProgressProvider.select((s) => s.activeMission));
});
