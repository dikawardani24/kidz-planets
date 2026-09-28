import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/controllers/avatar_controller.dart';
import '../../../application/state/avatar_state.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../infrastructure/scene/avatar_scene_controller.dart';
import 'avatar_speech.dart';

const double kCompanionBoxWidth = 132;
const double kCompanionBoxHeight = 148;
const double kCompanionEdge = 8;
const double kMoveHandleSize = 40;
const Offset kMoveHandleOffset = Offset(118, 108);

/// The persistent 3D mission companion.
/// Flies non-stop all over the screen in overview mode, but gracefully
/// settles at the bottom of the screen when the user focuses on a planet.
class MissionCompanion extends ConsumerStatefulWidget {
  const MissionCompanion({super.key, this.controllerFactory});

  final AvatarSceneController Function()? controllerFactory;

  @override
  ConsumerState<MissionCompanion> createState() => _MissionCompanionState();
}

class _MissionCompanionState extends ConsumerState<MissionCompanion>
    with SingleTickerProviderStateMixin {
  late final AvatarSceneController _controller;
  late final AnimationController _flightTicker;
  bool _ready = false;
  bool _placed = false;

  Size _lastViewport = const Size(400, 800);
  Offset _lastMaxPosition = const Offset(350, 700);

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controllerFactory?.call() ?? AvatarSceneControllerImpl();

    _flightTicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _flightTicker.addListener(() {
      if (!mounted) return;
      final ui = ref.read(explorerControllerProvider);
      final pose = ref.read(avatarControllerProvider);
      // Only fly around when NOT focused on a planet
      if (!ui.hasSelection && pose.idleAction == AvatarIdleAction.flying) {
        ref.read(avatarControllerProvider.notifier).updateFlight(
              0.016,
              _lastViewport,
              _lastMaxPosition,
            );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.ensureBuilt();
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _flightTicker.dispose();
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

        _lastViewport = viewport;
        final maxPosition = Offset(
          (viewport.width - kCompanionBoxWidth - kCompanionEdge)
              .clamp(kCompanionEdge, double.infinity),
          (viewport.height - kCompanionBoxHeight - kCompanionEdge)
              .clamp(kCompanionEdge, double.infinity),
        );
        _lastMaxPosition = maxPosition;

        final hasFocus = ui.hasSelection;

        // When focused on a planet, dock neatly at the bottom center of the screen
        final bottomAnchor = Offset(
          (viewport.width / 2 - kCompanionBoxWidth / 2)
              .clamp(kCompanionEdge, viewport.width - kCompanionBoxWidth - kCompanionEdge),
          viewport.height - kCompanionBoxHeight - 85,
        );

        final home = Offset(maxPosition.dx, viewport.height * 0.42);

        if (!_placed && pose.screenPosition == null) {
          _placed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref
                .read(avatarControllerProvider.notifier)
                .placeAt(home, maxPosition: maxPosition);
          });
        }

        final rawPosition = hasFocus ? bottomAnchor : (pose.screenPosition ?? home);
        final position = Offset(
          rawPosition.dx.clamp(0.0, maxPosition.dx),
          rawPosition.dy.clamp(0.0, maxPosition.dy),
        );

        _controller.applyPose(pose);

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

        final isIceWorld = ui.selectedPlanetId == 'neptune' ||
            ui.selectedPlanetId == 'uranus' ||
            ui.selectedPlanetId == 'pluto';
        final isHotWorld = ui.selectedPlanetId == 'sun' ||
            ui.selectedPlanetId == 'mercury' ||
            ui.selectedPlanetId == 'venus';

        String companionText = 'Wheee! Flying all over space! 🚀';
        if (hasFocus) {
          if (isIceWorld) {
            companionText = 'Brrrr! So freezing cold here! 🥶';
          } else if (isHotWorld) {
            companionText = 'Phew! It is scorching hot! ☀️';
          } else {
            companionText = 'Inspecting NASA 3D details! ✨';
          }
        } else if (pose.idleAction == AvatarIdleAction.sendingHeart) {
          companionText = 'Sending space love! ❤️';
        } else if (pose.idleAction == AvatarIdleAction.dancing) {
          companionText = 'Boogie time! 🎶';
        } else if (pose.idleAction == AvatarIdleAction.thinking) {
          companionText = 'Hmm... exploring ideas!';
        }

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
                text: companionText,
                below: placement.below,
                accent: isIceWorld
                    ? const Color(0xFF38BDF8)
                    : isHotWorld
                        ? const Color(0xFFFBBF24)
                        : pose.isHeartVisible
                            ? const Color(0xFFEC4899)
                            : avatarAccent(ui.avatarMood),
              ),
            ),
            Positioned(
              left: position.dx,
              top: position.dy,
              width: kCompanionBoxWidth,
              height: kCompanionBoxHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (!hasFocus && pose.idleAction == AvatarIdleAction.flying)
                    AnimatedBuilder(
                      animation: _flightTicker,
                      builder: (context, _) =>
                          _RocketExhaustFlame(progress: _flightTicker.value),
                    ),
                  if (pose.isHeartVisible)
                    Positioned(
                      top: -30,
                      left: kCompanionBoxWidth / 2 - 18,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.6, end: 1.3),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: const Text('❤️',
                                style: TextStyle(fontSize: 32)),
                          );
                        },
                      ),
                    ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) => ref
                        .read(avatarControllerProvider.notifier)
                        .rotateBy(dx: details.delta.dx, dy: details.delta.dy),
                    onTap: () {
                      if (ui.avatarMood == AvatarMood.wrong) {
                        ref
                            .read(explorerControllerProvider.notifier)
                            .retryMission();
                      }
                    },
                    child: _CompanionScene(
                      ready: _ready,
                      controller: _controller,
                      mood: ui.avatarMood,
                      idleAction: hasFocus ? AvatarIdleAction.sitting : pose.idleAction,
                      selectedPlanetId: ui.selectedPlanetId,
                    ),
                  ),
                ],
              ),
            ),
            if (!hasFocus)
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

class _RocketExhaustFlame extends StatelessWidget {
  const _RocketExhaustFlame({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(6, (i) {
        final factor = (progress + i * 0.18) % 1.0;
        final size = 60.0 * (1.0 - factor * 0.35);
        final opacity = (1.0 - factor).clamp(0.0, 1.0);
        return Positioned(
          left: kCompanionBoxWidth / 2 -
              size / 2 +
              (math.sin(i + progress * math.pi * 4) * 20),
          top: kCompanionBoxHeight - 10 + (factor * 90),
          child: Opacity(
            opacity: opacity * 0.95,
            child: Container(
              width: size,
              height: size * 1.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.98),
                    const Color(0xFF38BDF8).withValues(alpha: 0.92),
                    const Color(0xFF0284C7).withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CompanionScene extends StatelessWidget {
  const _CompanionScene({
    required this.ready,
    required this.controller,
    required this.mood,
    required this.idleAction,
    required this.selectedPlanetId,
  });

  final bool ready;
  final AvatarSceneController controller;
  final AvatarMood mood;
  final AvatarIdleAction idleAction;
  final String? selectedPlanetId;

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SizedBox.shrink();
    if (!controller.isRealScene) return const SizedBox.expand();
    return SceneView(
      controller.scene,
      camera: AvatarSceneControllerImpl.camera,
      onTick: (elapsed, _) => controller.tick(elapsed, mood, idleAction, selectedPlanetId),
    );
  }
}

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
        if (!below) _bubbleButtonOrText(),
        Icon(Icons.arrow_drop_down_rounded, size: 22, color: accent),
        if (below) _bubbleButtonOrText(),
      ],
    );
  }

  Widget _bubbleButtonOrText() {
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
