import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:avatar/audio.dart';
import 'package:avatar/controllers.dart';
import 'package:avatar/scene.dart';
import 'package:avatar/state.dart';

/// A self-contained 3D avatar stage: the selected body, its idle motion and
/// its touch reactions, with nothing that moves it on its own.
///
/// Unlike the Explorer's companion this preview owns its pose outright (a
/// private [AvatarController], never the shared provider), so dragging here
/// can never spin the Explorer's toy: the two simply do not share state. It
/// also never runs flight, throws or mission moods — the Explore-specific
/// automatic movement lives in the companion widget, not in the avatar
/// system, which is what keeps it out of here by construction.
///
/// Zoom limits keep the camera outside the model at all times; rotation is a
/// plain yaw/pitch on the pose, exactly like the companion's two-finger turn.
class AvatarPreview extends ConsumerStatefulWidget {
  const AvatarPreview({
    super.key,
    required this.avatarType,
    this.controllerFactory,
    this.idleAction = AvatarIdleAction.flying,
  });

  /// Which body to show. Switching types swaps the model node in place: the
  /// scene, its shaders and the camera all survive, so previewing the other
  /// avatar never recompiles anything.
  final AvatarType avatarType;

  /// Test seam in the same style as `MissionCompanion.controllerFactory`: a
  /// stand-in reports `isRealScene == false` and the GPU view is skipped.
  final AvatarSceneController Function()? controllerFactory;

  /// The resting motion. Not watched: changing it rebuilds the preview.
  final AvatarIdleAction idleAction;

  @override
  ConsumerState<AvatarPreview> createState() => _AvatarPreviewState();
}

class _AvatarPreviewState extends ConsumerState<AvatarPreview> {
  /// The neutral stage camera: same framing as the Explorer companion.
  static const double _defaultDistance = 1.75;

  /// Closest the camera may come: near enough to inspect the face, far
  /// enough to never end up inside the model.
  static const double _minDistance = 1.1;

  /// Furthest the camera may go before the toy reads as lost in space.
  static const double _maxDistance = 3.0;

  late final AvatarSceneController _scene;
  late final AvatarController _pose;

  /// The latest pose, captured through the listener below: `StateNotifier.state`
  /// is protected outside subclasses, and only the yaw/pitch/reaction feed the
  /// scene (screen position and flight never run here).
  late AvatarState _poseSnapshot;

  /// Removes the pose listener. StateNotifier hands back a remover rather
  /// than using removeListener.
  late final void Function() _removePoseListener;

  bool _ready = false;
  double _cameraDistance = _defaultDistance;
  late PerspectiveCamera _camera;
  double _lastScale = 1.0;
  Timer? _longPressTimer;

  PerspectiveCamera _buildCamera() => PerspectiveCamera(
    fovRadiansY: 0.62,
    position: vm.Vector3(0, 0.02, -_cameraDistance),
    target: vm.Vector3(0, 0.02, 0),
  );

  @override
  void initState() {
    super.initState();
    _scene = widget.controllerFactory?.call() ?? AvatarSceneControllerImpl();
    _pose = AvatarController();
    _camera = _buildCamera();
    // The pose is local (never the shared provider), so nothing rebuilds for
    // it on its own: rotations and reactions have to request a build, which
    // is what pushes the new yaw/pitch/reaction into the scene. The per-frame
    // body motion needs no rebuild — the scene ticks itself.
    var primed = false;
    _removePoseListener = _pose.addListener((pose) {
      _poseSnapshot = pose;
      // The listener fires once immediately with the opening pose; that fire
      // happens inside initState, where there is nothing to rebuild yet.
      if (primed && mounted) setState(() {});
      primed = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // The opening body loads before the first frame is declared ready, so
      // the preview never shows an empty stage.
      await _scene.setAvatarType(widget.avatarType);
      if (!mounted) return;
      _scene.ensureBuilt();
      setState(() => _ready = true);
    });
  }

  @override
  void didUpdateWidget(AvatarPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarType != widget.avatarType) {
      // A swap is staged by the builder (new model first, old model out),
      // and the talking bob introduces the new arrival.
      unawaited(_scene.setAvatarType(widget.avatarType));
      _pose.react(
        AvatarReaction.talking,
        duration: const Duration(milliseconds: 1200),
      );
    }
    // No setState: the scene repaints itself every tick without a rebuild.
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _removePoseListener();
    _pose.dispose();
    _scene.dispose();
    super.dispose();
  }

  void _zoomBy(double step) {
    if (!step.isFinite || step <= 0) return;
    final next = (_cameraDistance / step).clamp(_minDistance, _maxDistance);
    // Pinch streams dozens of events a second; rebuilding the (tiny) widget
    // for a sub-pixel camera move would cost more than the move is worth.
    if ((next - _cameraDistance).abs() < 0.002) return;
    setState(() {
      _cameraDistance = next;
      _camera = _buildCamera();
    });
  }

  void _playCue(AvatarReaction reaction) {
    final cue = AvatarExpressionSoundCatalog.cueFor(reaction);
    if (cue == null) return;
    unawaited(ref.read(avatarExpressionSoundProvider).playCue(cue));
  }

  void _react(AvatarReaction reaction, {Duration? duration}) {
    if (duration == null) {
      _pose.react(reaction);
    } else {
      _pose.react(reaction, duration: duration);
    }
    _playCue(reaction);
  }

  @override
  Widget build(BuildContext context) {
    final pose = _poseSnapshot;
    _scene.applyPose(pose);
    _scene.applyReaction(pose.reaction);

    if (!_ready || !_scene.isRealScene) return const SizedBox.expand();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (_) => _lastScale = 1.0,
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) {
          final step = details.scale / _lastScale;
          _lastScale = details.scale;
          _zoomBy(step);
          return;
        }
        // One finger turns the toy rather than moving it: the preview stage
        // has no flight path, so there is nowhere to throw anything to.
        _pose.rotateBy(
          dx: details.focalPointDelta.dx,
          dy: details.focalPointDelta.dy,
        );
      },
      onTap: () => _react(AvatarReaction.happy),
      onDoubleTap: () => _react(
        AvatarReaction.laughing,
        duration: const Duration(milliseconds: 1300),
      ),
      onLongPressStart: (_) {
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _react(
            AvatarReaction.sleepy,
            duration: const Duration(milliseconds: 1800),
          );
        });
      },
      onLongPressEnd: (_) => _longPressTimer?.cancel(),
      child: SceneView(
        _scene.scene,
        camera: _camera,
        onTick: (elapsed, _) =>
            _scene.tick(elapsed, AvatarMood.searching, widget.idleAction, null),
      ),
    );
  }
}
