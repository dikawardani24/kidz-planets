import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/controllers/avatar_controller.dart';
import '../../../application/state/avatar_reaction_policy.dart';
import '../../../application/state/avatar_state.dart';
import '../../../application/state/explorer_state.dart';
import '../../../application/state/providers.dart';
import '../../../infrastructure/scene/avatar_scene_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/localized_planet.dart';
import 'avatar_face.dart';
import 'avatar_speech.dart';

const double kCompanionBoxWidth = 132;
const double kCompanionBoxHeight = 148;
const double kCompanionEdge = 8;

/// How much a two-finger twist turns the toy, per radian of twist.
const double kCompanionTwistYaw = 18;

/// How much a two-finger drag turns the toy: sideways turns it (yaw), up and
/// down tips it (pitch). One finger is spoken for by moving the toy, so the
/// second finger is what makes the companion behave like a 3D object rather
/// than a sticker.
const double kCompanionDragYaw = 0.8;
const double kCompanionDragPitch = 0.5;

/// The persistent 3D Chubby Cartoon Rocket Ship mission companion.
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
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _flightTicker.addListener(() {
      if (!mounted) return;
      final ui = ref.read(explorerControllerProvider);
      final pose = ref.read(avatarControllerProvider);
      // Parked by a drag, or busy focussing a planet: the companion holds its
      // place instead of flying. The pause lives in the state, so the widget
      // never has to guess what the controller is up to.
      if (ui.hasSelection || pose.isFlightPaused ||
          pose.idleAction != AvatarIdleAction.flying) {
        return;
      }
      ref.read(avatarControllerProvider.notifier).updateFlight(
            0.016,
            _lastViewport,
            _lastMaxPosition,
          );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.ensureBuilt();
      setState(() => _ready = true);
    });
  }

  final Map<int, Offset> _activePointers = {};
  Offset? _firstDownPos;
  DateTime? _firstDownTime;
  int _tapCount = 0;
  Timer? _singleTapTimer;
  Timer? _longPressTimer;
  bool _isLongPress = false;
  bool _hasMovedFar = false;

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length == 1) {
      _firstDownPos = event.position;
      _firstDownTime = DateTime.now();
      _hasMovedFar = false;
      _isLongPress = false;

      _longPressTimer?.cancel();
      _longPressTimer = Timer(const Duration(milliseconds: 500), () {
        if (_activePointers.length == 1 && !_hasMovedFar && mounted) {
          _isLongPress = true;
          ref.read(avatarControllerProvider.notifier).react(
                AvatarReaction.sleepy,
                duration: const Duration(milliseconds: 1800),
              );
        }
      });
    } else if (_activePointers.length >= 2) {
      _longPressTimer?.cancel();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    _activePointers[event.pointer] = event.position;

    if (_activePointers.length == 1) {
      final start = _firstDownPos;
      if (start != null && (event.position - start).distanceSquared > 36) {
        _hasMovedFar = true;
        _longPressTimer?.cancel();
      }
      ref.read(avatarControllerProvider.notifier).moveBy(
            delta: event.delta,
            maxPosition: _lastMaxPosition,
          );
    } else if (_activePointers.length >= 2) {
      _longPressTimer?.cancel();
      _hasMovedFar = true;
      ref.read(avatarControllerProvider.notifier).rotateBy(
            dx: event.delta.dx * kCompanionDragYaw,
            dy: event.delta.dy * kCompanionDragPitch,
          );
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    _longPressTimer?.cancel();

    if (_activePointers.isEmpty) {
      final downTime = _firstDownTime;
      final now = DateTime.now();
      if (!_hasMovedFar &&
          !_isLongPress &&
          downTime != null &&
          now.difference(downTime).inMilliseconds < 350) {
        _tapCount++;
        if (_tapCount == 1) {
          _singleTapTimer?.cancel();
          _singleTapTimer = Timer(const Duration(milliseconds: 250), () {
            if (_tapCount == 1 && mounted) {
              final ui = ref.read(explorerControllerProvider);
              if (ui.avatarMood == AvatarMood.wrong) {
                ref.read(explorerControllerProvider.notifier).retryMission();
              } else {
                ref
                    .read(avatarControllerProvider.notifier)
                    .react(AvatarReaction.happy);
              }
            }
            _tapCount = 0;
          });
        } else if (_tapCount >= 2) {
          _singleTapTimer?.cancel();
          _tapCount = 0;
          ref.read(avatarControllerProvider.notifier).react(
                AvatarReaction.dizzy,
                duration: const Duration(milliseconds: 1300),
              );
        }
      } else {
        _tapCount = 0;
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    _longPressTimer?.cancel();
    _singleTapTimer?.cancel();
    _tapCount = 0;
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    _longPressTimer?.cancel();
    _flightTicker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pose = ref.watch(avatarControllerProvider);
    final ui = ref.watch(explorerControllerProvider);

    // Mission beats reach the body, not just the bubble: a wrong pick droops,
    // a finished mission laughs. The reaction itself lives in the avatar state,
    // so this only translates a mission mood into a reaction once per beat
    // instead of animating from inside the widget.
    ref.listen<AvatarMood>(
      explorerControllerProvider.select((s) => s.avatarMood),
      (previous, next) {
        if (previous == next) return;
        final beat = companionBeatFor(next);
        final avatar = ref.read(avatarControllerProvider.notifier);
        if (beat.reaction == AvatarReaction.none) {
          avatar.clearReaction();
        } else {
          avatar.react(beat.reaction, duration: beat.duration);
        }
      },
    );

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
        _controller.applyReaction(pose.reaction);

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

        final t = AppLocalizations.of(context);
        String companionText = t.companionFlying;
        if (hasFocus) {
          if (isIceWorld) {
            companionText = t.companionCold;
          } else if (isHotWorld) {
            companionText = t.companionHot;
          } else {
            companionText = t.companionInspecting;
          }
        } else if (pose.idleAction == AvatarIdleAction.sendingHeart) {
          companionText = t.companionSpaceLove;
        } else if (pose.idleAction == AvatarIdleAction.dancing) {
          companionText = t.companionBoogie;
        } else if (pose.idleAction == AvatarIdleAction.thinking) {
          companionText = t.companionThinking;
        }

        // A mission beat owns the line, even over the lines above: the
        // companion is what tells the child what to look for, that a pick was
        // wrong, and that it was found - and it says it by the planet's own
        // name, in the language the rest of the screen is in.
        if (mission != null && ui.avatarMood != AvatarMood.searching) {
          companionText = avatarLine(
            ui.avatarMood,
            localizedPlanetName(
              mission.targetPlanetId,
              Localizations.localeOf(context),
            ),
          );
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
                  if (!hasFocus && !pose.isFlightPaused &&
                      pose.idleAction == AvatarIdleAction.flying)
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
                  Semantics(
                    // The label the move handle used to carry: the toy itself
                    // is the handle now, so a screen reader hears it there.
                    label: t.companionMoveLabel,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      onPointerCancel: _onPointerCancel,
                      child: Stack(
                        children: [
                          _CompanionScene(
                            ready: _ready,
                            controller: _controller,
                            mood: ui.avatarMood,
                            idleAction: hasFocus ? AvatarIdleAction.sitting : pose.idleAction,
                            selectedPlanetId: ui.selectedPlanetId,
                          ),
                          // The face is Flutter paint over the 3D render, so it
                          // must not swallow drags meant for the toy.
                          if (_ready)
                            AnimatedBuilder(
                              animation: _flightTicker,
                              builder: (context, _) => IgnorePointer(
                                child: AvatarFace(
                                  box: const Size(kCompanionBoxWidth, kCompanionBoxHeight),
                                  pose: pose,
                                  motion: _controller.bodyMotion,
                                  phase: _flightTicker.value,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact, tightly-coupled rocket exhaust flame right at the rocket base.
class _RocketExhaustFlame extends StatelessWidget {
  const _RocketExhaustFlame({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(5, (i) {
        final factor = (progress + i * 0.2) % 1.0;
        final size = 48.0 * (1.0 - factor * 0.4);
        final opacity = (1.0 - factor).clamp(0.0, 1.0);
        return Positioned(
          left: kCompanionBoxWidth / 2 -
              size / 2 +
              (math.sin(i + progress * math.pi * 4) * 8),
          top: kCompanionBoxHeight - 68 + (factor * 40), // Starts right at the engine nozzle
          child: Opacity(
            opacity: opacity * 0.95,
            child: Container(
              width: size,
              height: size * 1.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.98),
                    const Color(0xFF38BDF8).withValues(alpha: 0.92),
                    const Color(0xFF0284C7).withValues(alpha: 0.50),
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
