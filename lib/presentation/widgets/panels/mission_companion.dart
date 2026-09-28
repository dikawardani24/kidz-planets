import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/controllers/avatar_controller.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../infrastructure/scene/avatar_scene_controller.dart';
import 'avatar_speech.dart';

/// On-screen size of the companion box, and the size and offset of its move
/// handle. Top-level so the speech bubble can reason about the same box
/// without reaching into the state class.
const double kCompanionBoxWidth = 132;
const double kCompanionBoxHeight = 148;
const double kCompanionEdge = 8;
const double kMoveHandleSize = 40;
const Offset kMoveHandleOffset = Offset(118, 108);

/// The persistent 3D mission companion: a real character the child can turn
/// and move, with a speech bubble that follows it around the screen.
///
/// It lives in the topmost layer of the explorer, above the scene, the panels,
/// the nav, and the celebration dialog, because the user asked for it to never
/// be hidden and never be promoted into a dialog of its own.
///
/// Two gestures, deliberately separated:
///
///  * dragging the character turns it (yaw and clamped pitch);
///  * dragging the move handle slides it around the screen.
///
/// They are separate so that turning never accidentally relocates the
/// character and moving never accidentally re-aims it. Position and rotation
/// both live in `AvatarState`, so both survive a mission change, a wrong
/// answer, and a celebration.
class MissionCompanion extends ConsumerStatefulWidget {
  const MissionCompanion({super.key, this.controllerFactory});

  /// Creates the 3D controller the companion renders with.
  ///
  /// A seam, not a feature. Building a real `Scene` needs a GPU with Impeller,
  /// which a widget test does not have, so a test injects a fake here and can
  /// still exercise everything around the 3D: placement, the two gestures, the
  /// bubble, and the mood wiring. When null, the companion builds the real
  /// character.
  final AvatarSceneController Function()? controllerFactory;

  @override
  ConsumerState<MissionCompanion> createState() => _MissionCompanionState();
}

class _MissionCompanionState extends ConsumerState<MissionCompanion> {
  late final AvatarSceneController _controller;
  bool _ready = false;

  bool _placed = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controllerFactory?.call() ?? AvatarSceneControllerImpl();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.ensureBuilt();
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pose = ref.watch(avatarControllerProvider);
    final ui = ref.watch(explorerControllerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (viewport.isEmpty) return const SizedBox.shrink();

        final maxPosition = Offset(
          (viewport.width - kCompanionBoxWidth - kCompanionEdge)
              .clamp(kCompanionEdge, double.infinity),
          (viewport.height - kCompanionBoxHeight - kCompanionEdge)
              .clamp(kCompanionEdge, double.infinity),
        );

        // Resolve the starting spot from the real viewport, once, so the
        // companion appears in the same place on every screen size.
        final home = Offset(maxPosition.dx, viewport.height * 0.42);

        // Commit the starting spot to the controller the first time it is
        // known. Without this the avatar would only ever be *displayed* at
        // `home` while its stored position stayed null, and since a move is a
        // delta from the stored position, every move would be discarded and
        // the companion would appear to be stuck.
        if (!_placed && pose.screenPosition == null) {
          _placed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(avatarControllerProvider.notifier).placeAt(home);
          });
        }

        final position = pose.screenPosition ?? home;

        // Keep the model in step with the pose without rebuilding the overlay
        // tree. Runs on a pose change, not per frame.
        _controller.applyPose(pose);

        // The target stand-in follows the active mission and takes its colour
        // from the real planet in that mission, so it is never hardcoded. It
        // appears and disappears without touching the pose, so a mission
        // change cannot move or turn the companion.
        final mission = ui.activeMission;
        final targetColor = mission == null
            ? Theme.of(context).colorScheme.primary
            : Color(
                ref.read(planetByIdProvider(mission.targetPlanetId)).colorValue,
              );
        _controller.showTarget(visible: mission != null, color: targetColor);

        final placement = bubblePlacement(
          avatarTop: position.dy,
          avatarLeft: position.dx,
          avatarWidth: kCompanionBoxWidth,
          avatarHeight: kCompanionBoxHeight,
          viewport: viewport,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: bubbleLeft(
                side: placement.side,
                avatarLeft: position.dx,
                avatarWidth: kCompanionBoxWidth,
                viewport: viewport,
              ),
              top: placement.top,
              width: kBubbleWidth,
              child: _Bubble(
                text: avatarLine(
                  ui.avatarMood,
                  mission == null
                      ? null
                      : ref
                          .read(planetByIdProvider(mission.targetPlanetId))
                          .name,
                ),
                below: placement.below,
                accent: avatarAccent(ui.avatarMood),
              ),
            ),
            Positioned(
              left: position.dx,
              top: position.dy,
              width: kCompanionBoxWidth,
              height: kCompanionBoxHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => ref
                    .read(avatarControllerProvider.notifier)
                    .rotateBy(dx: details.delta.dx, dy: details.delta.dy),
                // Tapping the companion while it is disappointed is how the
                // child says "I heard you", and it moves the avatar to its
                // encouraging line. This replaces the "Try again" button the
                // dialog used to carry, so a wrong pick needs no dialog at all.
                onTap: () {
                  if (ui.avatarMood == AvatarMood.wrong) {
                    ref.read(explorerControllerProvider.notifier).retryMission();
                  }
                },
                child: _CompanionScene(
                  ready: _ready,
                  controller: _controller,
                  mood: ui.avatarMood,
                ),
              ),
            ),
            Positioned(
              left: (position.dx + kMoveHandleOffset.dx).clamp(
                kCompanionEdge,
                (viewport.width - kMoveHandleSize - kCompanionEdge)
                    .clamp(kCompanionEdge, double.infinity),
              ),
              top: (position.dy + kMoveHandleOffset.dy).clamp(
                kCompanionEdge,
                (viewport.height - kMoveHandleSize - kCompanionEdge)
                    .clamp(kCompanionEdge, double.infinity),
              ),
              width: kMoveHandleSize,
              height: kMoveHandleSize,
              child: _MoveHandle(
                onMove: (delta) => ref
                    .read(avatarControllerProvider.notifier)
                    .moveBy(delta: delta, maxPosition: maxPosition),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The real 3D character. Its rotate gesture is supplied by the parent so the
/// gesture lives with the other one, next to the move handle.
class _CompanionScene extends StatelessWidget {
  const _CompanionScene({
    required this.ready,
    required this.controller,
    required this.mood,
  });

  final bool ready;
  final AvatarSceneController controller;
  final AvatarMood mood;

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SizedBox.shrink();
    // A fake controller (see MissionCompanion.controllerFactory) has no real
    // scene to draw, so the body renders empty while the overlay around it,
    // which is what the tests exercise, behaves exactly as it does in the app.
    if (!controller.isRealScene) return const SizedBox.expand();
    return SceneView(
      controller.scene,
      camera: AvatarSceneControllerImpl.camera,
      // Per-frame motion is driven here rather than by a rebuild, so the
      // companion animates without rebuilding the overlay tree. The mood
      // arrives as a widget field, so it only changes when the mission state
      // actually changes.
      onTick: (elapsed, _) => controller.tick(elapsed, mood),
    );
  }
}

/// The explicit move handle.
///
/// A child-friendly companion has to be movable, but "drag anywhere to move"
/// would collide with "drag to turn". A clearly labelled handle keeps the two
/// gestures unambiguous and discoverable.
class _MoveHandle extends StatelessWidget {
  const _MoveHandle({required this.onMove});

  final void Function(Offset delta) onMove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Move the space buddy',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onMove(details.delta),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF17234D).withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFBBF24), width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.open_with_rounded,
              size: 20,
              color: Color(0xFFFBBF24),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.below,
    required this.accent,
  });

  final String text;
  final bool below;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!below) _bubbleBody(),
        // The tail points at the character, so the child can tell who is
        // speaking even when the bubble has slid to the other side of it.
        Icon(Icons.arrow_drop_down_rounded, size: 22, color: accent),
        if (below) _bubbleBody(),
      ],
    );
  }

  Widget _bubbleBody() {
    return Container(
      height: kBubbleHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0C132C).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent, width: 2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
