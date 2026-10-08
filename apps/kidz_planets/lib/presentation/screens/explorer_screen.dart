import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:avatar/audio.dart';
import 'package:core/l10n.dart';
import 'package:core/layout.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:kidz_planets/presentation/screens/avatar_screen.dart';
import 'package:kidz_planets/presentation/tv/tv_controller_hint.dart';
import 'package:kidz_planets/presentation/tv/tv_providers.dart';
import 'package:kidz_planets/presentation/tv/tv_remote_handler.dart';
import 'package:kidz_planets/presentation/widgets/overlays/bottom_nav.dart';
import 'package:kidz_planets/presentation/widgets/overlays/toast_overlay.dart';
import 'package:kidz_planets/presentation/widgets/overlays/top_bar.dart';
import 'package:kidz_planets/presentation/widgets/panels/mission_companion.dart';
import 'package:kidz_planets/presentation/widgets/panels/playground_panel.dart';
import 'package:mission/state.dart';
import 'package:mission/widgets.dart';
import 'package:planets/audio.dart';
import 'package:planets/scene.dart';
import 'package:planets/state.dart';
import 'package:planets/widgets.dart';

/// Decides whether a body's ambience and voice description may start now.
///
/// A completed mission plays its own success cue and then raises a
/// celebration dialog, so narration is held until that dialog is dismissed:
/// the voice runs at 0.92 and would otherwise talk over the 0.65 cue and read
/// the dialog out loud.
///
/// Note what this deliberately does *not* gate. A planet the child taps is
/// always described and always plays its own ambience, wrong pick or not: that
/// is the whole point of tapping a body, and it is how the app teaches the
/// planets. What a wrong pick suppresses is the *mission* feedback, which the
/// companion now owns: no mission replay, no mission dialog, and no failure
/// cue. Those live in the branch above, not behind this gate.
bool canStartPlanetAudio({required bool celebrationVisible}) {
  if (celebrationVisible) return false;
  return true;
}

class ExplorerScreen extends ConsumerWidget {
  const ExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(explorerControllerProvider);
    final shell = ref.watch(appShellProvider);
    final progress = ref.watch(missionProgressProvider);
    // Single TV branch for this screen: everything below keys off [isTv].
    // The TV controller itself is inert on touch devices, so watching it
    // unconditionally keeps the hook order stable across form factors.
    final isTv = ref.watch(isTelevisionProvider);
    final avatarPageVisible = ref.watch(
      appShellProvider.select((s) => s.avatarPageVisible),
    );

    // Mission progress and the explorer's own state used to be one object.
    // They are separate now, so both are observed here and the decisions that
    // span them are made in this listener rather than inside either feature.
    ref.listen<MissionProgressState>(missionProgressProvider, (prev, next) {
      final celebrationClosed =
          (prev?.celebrationVisible ?? false) && !next.celebrationVisible;
      if (!celebrationClosed) return;

      // Dismissing the celebration is the cue to describe the body that was
      // just found. The mission success sound plays alone while the modal is
      // up: narration runs at 0.92 and would otherwise talk over the 0.65 cue
      // and read the dialog out loud.
      final selectedId = ref.read(explorerControllerProvider).selectedPlanetId;
      if (selectedId == null) return;
      final planet = ref.read(planetByIdProvider(selectedId));
      ref.read(planetNarrationServiceProvider).speakPlanet(planet);
      ref.read(planetSoundServiceProvider).playBody(planet);
    });

    ref.listen<MissionProgressState>(missionProgressProvider, (prev, next) {
      if (prev?.activeMissionId == next.activeMissionId ||
          next.activeMissionId == null) {
        return;
      }
      final missionId = next.activeMissionId;
      // The controller raises the celebration in the same state assignment that
      // advances activeMissionId, but the dialog's own appearance is a later
      // build, so the same microtask deferral is needed to see it.
      scheduleMicrotask(() {
        if (!context.mounted) return;
        final progress = ref.read(missionProgressProvider);
        if (progress.activeMissionId != missionId) return;
        final matches = progress.missions.where((m) => m.id == missionId);
        if (matches.isEmpty) return;
        if (!canStartPlanetAudio(
          celebrationVisible: progress.celebrationVisible,
        )) {
          return;
        }
        final planet = ref.read(
          planetByIdProvider(matches.first.targetPlanetId),
        );
        ref.read(planetNarrationServiceProvider).replay(planet);
      });
    });

    ref.listen<ExplorerState>(explorerControllerProvider, (prev, next) {
      // Expression SFX duck under narration instead of competing with it.
      // Speech starts in the branches below; stopping (deselect, celebration
      // shown) restores full volume. The flag lives on the shared sound so it
      // survives companion rebuilds.
      final narrationActive = next.selectedPlanetId != null;
      if ((prev?.selectedPlanetId != null) != narrationActive) {
        try {
          ref.read(avatarExpressionSoundProvider).voiceActive = narrationActive;
        } catch (_) {}
      }

      void speakSelected(String? id) {
        if (id == null) return;
        final planet = ref.read(planetByIdProvider(id));
        ref.read(planetNarrationServiceProvider).speakPlanet(planet);
        ref.read(planetSoundServiceProvider).playBody(planet);
      }

      // A wrong pick deliberately has no *mission* branch here. This used to
      // replay the active mission out loud and reopen the mission dialog 550ms
      // later; the companion handles a miss on its own now, so neither happens.
      //
      // The planet that was tapped is still described and still plays its own
      // ambience further down, because tapping a body is how the child explores
      // and the mission being wrong does not make the body uninteresting.

      if (prev?.selectedPlanetId != next.selectedPlanetId) {
        final selectedId = next.selectedPlanetId;
        if (selectedId == null) {
          ref.read(planetNarrationServiceProvider).stop();
          ref.read(planetSoundServiceProvider).stop();
        } else {
          // Grading the tap against the active mission happens in the same
          // synchronous turn as the selection, so a celebration raised by this
          // tap is not set yet on this pass. Re-reading the state on a microtask
          // lets it be seen; when one is up the celebration-dismissed listener
          // above does the narration instead.
          //
          // The body that was tapped is described and sounds either way,
          // including when it was the wrong mission target: the companion owns
          // the *mission* reaction, not the body's own voice.
          scheduleMicrotask(() {
            if (!context.mounted) return;
            final current = ref.read(explorerControllerProvider);
            if (current.selectedPlanetId != selectedId) return;
            if (!canStartPlanetAudio(
              celebrationVisible: ref
                  .read(missionProgressProvider)
                  .celebrationVisible,
            )) {
              return;
            }
            speakSelected(selectedId);
          });
        }
      }

      if (prev?.showOrbits != next.showOrbits) {
        try {
          ref
              .read(solarSystemSceneControllerProvider)
              .setOrbitsVisible(next.showOrbits);
        } catch (_) {}
      }
    });

    // Approach narration: the marked body "introduces itself" once the zoom
    // passes 90% toward it. Independent from the marker icon (purely visual)
    // and from detail entry (which keeps its own narration): this only speaks
    // while approaching, once per zoom session, and never for a detail that
    // was opened directly without approaching.
    ref.listen<ExplorerState>(explorerControllerProvider, (prev, next) {
      final explorer = ref.read(explorerControllerProvider.notifier);
      if (!explorer.isMarkNarrationDue) return;
      if (!canStartPlanetAudio(
        celebrationVisible: ref
            .read(missionProgressProvider)
            .celebrationVisible,
      )) {
        return;
      }
      final markedId = ref.read(explorerControllerProvider).markedTargetId;
      if (markedId == null) return;
      final planet = ref.read(planetByIdProvider(markedId));
      ref.read(planetNarrationServiceProvider).speakPlanet(planet);
      explorer.acknowledgeMarkNarration();
    });

    final scaffold = Scaffold(
      backgroundColor: AppTheme.space950,
      resizeToAvoidBottomInset: false,
      body: OrientationBuilder(
        builder: (context, orientation) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // OrientationBuilder explicitly reacts to device rotation.
              // LayoutBuilder then supplies the new viewport dimensions.
              final isLandscape = orientation == Orientation.landscape;
              final horizontalInset = isLandscape ? 24.0 : 0.0;
              final viewportSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              if (isTv) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ref
                        .read(tvExplorerControllerProvider.notifier)
                        .updateViewportSize(viewportSize);
                  }
                });
              }

              // The scene is intentionally allowed to use the entire viewport.
              // The previous 390px width cap made landscape render as a narrow
              // portrait-sized canvas with unused space on both sides.
              return Stack(
                fit: StackFit.expand,
                children: [
                  const SolarSystemSceneView(),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ExplorerTopBar(
                      isExploreTab: shell.tab == AppTab.explore,
                    ),
                  ),
                  ExplorerInteractionOverlays(
                    isExploreTab: shell.tab == AppTab.explore,
                  ),
                  const ToastOverlay(),

                  if (shell.tab == AppTab.playground)
                    Positioned(
                      left: horizontalInset + 12,
                      right: horizontalInset + 12,
                      top: isLandscape ? 68 : 64,
                      bottom: isLandscape ? 72 : 66,
                      child: isTv
                          ? const _TvPanelFrame(child: PlaygroundPanel())
                          : const PlaygroundPanel(),
                    ),

                  if (shell.tab == AppTab.missions)
                    Positioned(
                      left: horizontalInset + 12,
                      right: horizontalInset + 12,
                      top: isLandscape ? 68 : 64,
                      bottom: isLandscape ? 72 : 66,
                      // On TV the Go pill jumps straight to its planet: same
                      // selection (camera, narration, grading) as tapping the
                      // body itself, so missions stay fully remote-driven.
                      child: isTv
                          ? _TvPanelFrame(
                              child: MissionsPanel(
                                onOpenMission: (planetId) =>
                                    _openMissionTarget(ref, planetId),
                              ),
                            )
                          : const MissionsPanel(),
                    ),

                  if (ui.hasSelection && shell.tab == AppTab.explore)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 76,
                      child: Center(
                        child: DetailDescriptionToggle(
                          planet: ref.watch(
                            planetByIdProvider(ui.selectedPlanetId!),
                          ),
                          onSpatialTarget: isTv
                              ? ref
                                    .read(tvExplorerControllerProvider.notifier)
                                    .registerTarget
                              : null,
                          onUnregisterSpatialTarget: isTv
                              ? ref
                                    .read(tvExplorerControllerProvider.notifier)
                                    .unregisterTarget
                              : null,
                        ),
                      ),
                    ),

                  if (ui.hasSelection && shell.tab == AppTab.explore)
                    Positioned.fill(
                      child: DetailSideRails(
                        onSpatialTarget: isTv
                            ? ref
                                  .read(tvExplorerControllerProvider.notifier)
                                  .registerTarget
                            : null,
                        onUnregisterSpatialTarget: isTv
                            ? ref
                                  .read(tvExplorerControllerProvider.notifier)
                                  .unregisterTarget
                            : null,
                      ),
                    ),

                  // Explore-mode zoom controls on the right edge, mirroring the
                  // detail rails' camera buttons. Touch only: TV navigates with
                  // its D-pad zoom chrome and would gain dead focus targets
                  // from an on-screen rail.
                  if (!ui.hasSelection && shell.tab == AppTab.explore && !isTv)
                    Positioned.fill(
                      child: ExploreZoomRail(viewSize: viewportSize),
                    ),

                  // TV controller chrome: quiet pause/help pills that fade
                  // while exploring. No category menus on TV: the solar
                  // system itself is the navigation.
                  if (isTv && shell.tab == AppTab.explore)
                    const TvControllerChrome(),

                  // Touch only: TV explores with the D-pad and has no tab bar.
                  if (!isTv) const ExplorerBottomNav(),

                  if (progress.celebrationVisible)
                    Positioned.fill(
                      child: _CelebrationModal(
                        title: progress.celebrationTitle!,
                        description: progress.celebrationDescription!,
                      ),
                    ),

                  // Last in the stack, so the companion is the topmost thing on
                  // screen: above the scene, the panels, the nav, and the
                  // celebration dialog. It is a permanent part of the mission UI,
                  // never hidden and never promoted into a dialog of its own.
                  const MissionCompanion(),

                  // The avatar page covers everything above when open,
                  // including the companion: it carries its own preview stage,
                  // so the Explorer's toy simply waits underneath.
                  if (avatarPageVisible)
                    const Positioned.fill(child: AvatarScreen()),
                ],
              );
            },
          );
        },
      ),
    );
    // The remote handler owns D-pad input on TV and keyboard/remote testing,
    // providing seamless D-pad navigation across all devices.
    return TvRemoteHandler(child: scaffold);
  }
}

/// Jumps to a mission's target planet.
///
/// One shared selection path: the shell grades it, the explorer narrates it,
/// the camera focuses it — identical to tapping the body in the scene.
void _openMissionTarget(WidgetRef ref, String planetId) {
  ref.read(appShellProvider.notifier).setTab(AppTab.explore);
  ref.read(explorerControllerProvider.notifier).selectPlanet(planetId);
}

/// Frames a tab panel for TV: centered readable column with viewport-scaled
/// text.
///
/// The panels are shared with phones, so instead of forking their layouts the
/// TV constrains their width (from the TV reference) and scales text by the
/// shared viewport factor. Both panels scroll, which absorbs the vertical
/// growth; rows use flexible text columns, so nothing clips horizontally.
class _TvPanelFrame extends StatelessWidget {
  const _TvPanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tv = DesignScale.tvOf(context);
    final shared = DesignScale.sharedOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: tv.px(980)),
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(shared.factor)),
          child: child,
        ),
      ),
    );
  }
}

class _CelebrationModal extends ConsumerWidget {
  const _CelebrationModal({required this.title, required this.description});

  final AppMessage title;
  final AppMessage description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final bodyName = ref.watch(bodyNameResolverProvider);
    // TvFocusable keeps the touch tap identical while giving the TV remote a
    // focused Continue button the moment the celebration appears. Every size
    // derives from the viewport scale; the width is a viewport fraction so
    // the dialog fits phones and 4K alike.
    final isTv = ref.watch(isTelevisionProvider);
    final ds = DesignScale.sharedOf(context);
    final badgeExtent = ds.px(80);
    final maxWidth = (MediaQuery.sizeOf(context).width * 0.6).clamp(
      380.0,
      900.0,
    );
    return Container(
      color: AppTheme.space950.withValues(alpha: .85),
      child: Center(
        child: Padding(
          padding: ds.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: badgeExtent,
                  height: badgeExtent,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentAmber.withValues(alpha: .20),
                    border: Border.all(
                      color: AppTheme.accentAmber,
                      width: ds.px(2),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text('🎉', style: TextStyle(fontSize: ds.font(38))),
                ),
                SizedBox(height: ds.px(16)),
                Text(
                  title.resolve(t, locale, bodyName: bodyName),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ds.font(23),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: ds.px(4)),
                Text(
                  description.resolve(t, locale, bodyName: bodyName),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ds.font(12),
                    height: 1.4,
                    color: const Color(0xFFC7D2FE),
                  ),
                ),
                SizedBox(height: ds.px(22)),
                TvFocusable(
                  autofocus: isTv,
                  onSelect: () =>
                      ref.read(appShellProvider.notifier).closeCelebration(),
                  child: Container(
                    padding: ds.insets(horizontal: 26, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(ds.radius(999)),
                      ),
                      gradient: const LinearGradient(
                        colors: [AppTheme.accentIndigo, Color(0xFF7C3AED)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x664F46E5),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Text(
                      'Continue Exploring 🚀',
                      style: TextStyle(
                        fontSize: ds.font(12),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
