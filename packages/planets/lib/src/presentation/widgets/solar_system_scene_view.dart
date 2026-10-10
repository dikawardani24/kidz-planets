import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scene/scene.dart';

import 'package:planets/state.dart';
import 'package:planets/domain.dart';
import 'package:planets/scene.dart';
import 'package:core/layout.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';

/// True 3D solar system rendered with flutter_scene (no WebView).
class SolarSystemSceneView extends ConsumerStatefulWidget {
  const SolarSystemSceneView({super.key, this.autoTick = true});

  /// Whether the view drives per-frame rendering, forwarded to
  /// [SceneView.autoTick].
  ///
  /// Set false while a fully opaque overlay covers the scene (see
  /// [sceneViewTicksWhile]): the view's ticker stops, so no repaint is
  /// scheduled, no per-frame app logic runs, and the GPU rasterizes nothing
  /// — while the scene graph, camera rig and simulation clock resume
  /// untouched. Defaults to true.
  final bool autoTick;

  @override
  ConsumerState<SolarSystemSceneView> createState() =>
      _SolarSystemSceneViewState();
}

/// Whether the scene view should drive per-frame rendering right now.
///
/// A mounted [SceneView] repaints every frame even when fully occluded, so an
/// opaque cover means paying the whole scene raster for zero visible pixels.
/// Only fully occluding overlays qualify: translucent dialogs and partial
/// panels still show the live scene behind them and must keep it ticking.
bool sceneViewTicksWhile({required bool avatarPageVisible}) =>
    !avatarPageVisible;

class _SolarSystemSceneViewState extends ConsumerState<SolarSystemSceneView> {
  bool _buildStarted = false;
  bool _ready = false;
  String _loadingLabel = 'Warming up the rockets...';
  double _buildFraction = 0.0;
  PerspectiveCamera? _lastCamera;
  List<PlanetLabelFrame> _labelFrames = const [];
  Offset? _markedCenter;
  double _markedDiameter = 64.0;
  bool _systemVisible = true;
  bool _pinchActive = false;
  double _zoomGlide = 0.0;
  Offset _lastFocalLocal = Offset.zero;
  Size _lastViewSize = Size.zero;
  double _lastScale = 1.0;
  double _angularVelocityX = 0.0;
  double _angularVelocityY = 0.0;
  bool _zoomLabelsVisible = true;
  bool _presentedReported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A fresh mount means a fresh first frame is still owed: tell the
      // startup handover to wait for this view's first presented tick rather
      // than revealing a compiling scene mid-crossfade. Done here, not in
      // initState, because this view can mount inside a layout callback
      // (the explorer's LayoutBuilder) where Riverpod forbids provider writes.
      ref.read(explorerScenePresentedProvider.notifier).state = false;
      _ensureBuilt();
    });
  }

  Future<void> _ensureBuilt() async {
    if (_buildStarted) return;
    _buildStarted = true;
    final controller = ref.read(solarSystemSceneControllerProvider);
    final planets = ref.read(planetsProvider);
    try {
      await controller.ensureBuilt(
        planets: planets,
        onProgress: (fraction, label) {
          if (mounted) {
            setState(() {
              _buildFraction = fraction;
              _loadingLabel = label;
            });
          }
        },
      );
      controller.setOrbitsVisible(
        ref.read(explorerControllerProvider).showOrbits,
      );
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLabel = 'Oops! Could not load space: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(solarSystemSceneControllerProvider);
    final ui = ref.watch(explorerControllerProvider);
    final planets = ref.watch(planetsProvider);
    // Every selection teardown (Close button, tap-toggle, tab switch, …)
    // must hand the camera back to the solar-system anchor without moving
    // it: while selected, the target is the body's world position, and the
    // body keeps orbiting after deselect, so a stale body target leaves the
    // camera staring at empty space. Freezing the last eye and re-anchoring
    // keeps the system visible from the exact view the user left.
    // (Auto-deselect already preserves synchronously in the gesture handler;
    // re-applying here is idempotent.)
    ref.listen<ExplorerState>(explorerControllerProvider, (previous, next) {
      if (previous?.selectedPlanetId != null && next.selectedPlanetId == null) {
        final camera = _lastCamera;
        if (camera != null) {
          ref
              .read(solarSystemSceneControllerProvider)
              .preserveReleaseEye(camera);
        }
      }
    });
    // Startup normally gets here with the scene already built, so this branch
    // is a fallback for a feature package used on its own. The fraction is only
    // drawn because it is free: the real progress reporting lives in the app's
    // startup pipeline, not in a widget that cannot know what else is loading.
    if (!_ready) {
      return _LoadingView(label: _loadingLabel, fraction: _buildFraction);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          // Scale handles both one-finger drag and two-finger pinch.
          // A separate Pan recognizer competes with Scale in Flutter's gesture arena.
          onScaleStart: _onScaleStart,
          onScaleUpdate: (details) => _onScaleUpdate(details, size),
          onScaleEnd: _onScaleEnd,
          onDoubleTapDown: (d) => _onDoubleTap(d, size),
          onTapUp: (d) => _onTapUp(d, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SceneView(
                controller.scene,
                // Paused under opaque overlays (see [sceneViewTicksWhile]):
                // the ticker stops and resumes through didUpdateWidget, and
                // the clamped delta below absorbs the resume gap.
                autoTick: widget.autoTick,
                cameraBuilder: (elapsed) {
                  final camera = controller.buildCamera(ui);
                  _lastCamera = camera;
                  return camera;
                },
                onTick: (elapsed, deltaSeconds) {
                  // Clamp the frame delta: a hitch (or a resume after the
                  // ticker paused under an overlay) must advance the clock by
                  // at most one frame instead of teleporting orbits, spins
                  // and flights forward by the whole gap. Ambient motion is
                  // rate-based, so dropping the excess is invisible.
                  final dt = deltaSeconds.clamp(0.0, 0.05);
                  controller.tick(dt, ui);
                  // The scene just presented a frame with built content: the
                  // startup handover may now reveal the Explorer.
                  if (_ready && !_presentedReported) {
                    _presentedReported = true;
                    ref.read(explorerScenePresentedProvider.notifier).state =
                        true;
                  }
                  _driveZoomFlight(controller, dt);
                  _applyZoomGlide(controller, dt);
                  _refreshLabels(controller, size);
                },
              ),
              _PlanetLabelsOverlay(
                frames: _labelFrames,
                planets: planets,
                showLabels: ui.showLabels && _zoomLabelsVisible,
                selectedId: ui.selectedPlanetId,
                markedId: ui.markedTargetId,
                onMarkedTap: () {
                  // Label taps mirror 3D taps: a marked chip starts the
                  // smooth zoom-to-detail flight, unless it is already
                  // running for this body.
                  final markedId = ref
                      .read(explorerControllerProvider)
                      .markedTargetId;
                  final cam = _lastCamera;
                  if (markedId == null || cam == null) return;
                  if (!controller.zoomFlightActive) {
                    controller.startZoomToDetail(markedId, cam);
                  }
                },
              ),
              if (_markedCenter != null &&
                  ui.markedTargetId != null &&
                  !ui.hasSelection)
                _TargetMarker(
                  center: _markedCenter!,
                  diameter: _markedDiameter,
                ),
              // Recovery shortcut: only ever visible when no body is on
              // screen at all (zoomed/panned out into empty space) and no
              // detail is open. Tapping it restores the overview framing.
              if (!_systemVisible && !ui.hasSelection)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 148,
                  child: Center(
                    child: _JumpToSunButton(
                      onPressed: () {
                        controller.resetOverview();
                        ref
                            .read(explorerControllerProvider.notifier)
                            .clearMarkedTarget();
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Advances a running "zoom to Detail" flight ("second tap on the marked
  /// object") and finishes it by opening detail at the reached distance.
  ///
  /// Progress is reported every frame so the >90% narration fires while
  /// passing it, exactly as with manual zoom. A manual pinch, a new tap, or
  /// a cleared/switched mark cancels the flight elsewhere; the guards here
  /// are the safety net for state that changed between frames.
  void _driveZoomFlight(
    SolarSystemSceneController controller,
    double deltaSeconds,
  ) {
    if (!controller.zoomFlightActive) return;
    final ui = ref.read(explorerControllerProvider);
    final flightId = ui.markedTargetId;
    if (flightId == null || ui.hasSelection) {
      controller.cancelZoomFlight();
      return;
    }
    final step = controller.stepZoomFlight(deltaSeconds, flightId);
    ref
        .read(explorerControllerProvider.notifier)
        .reportMarkProgress(step.progress, approaching: true);
    if (!step.done) return;
    final camera = controller.buildCamera(ref.read(explorerControllerProvider));
    _lastCamera = camera;
    final zoom = controller.prepareSeamlessSelection(flightId, camera);
    ref
        .read(explorerControllerProvider.notifier)
        .selectPlanet(flightId, initialDetailZoom: zoom);
  }

  void _refreshLabels(SolarSystemSceneController controller, Size size) {
    final camera = _lastCamera;
    if (camera == null || size.isEmpty) return;
    final frames = controller.projectLabels(camera, size);
    final ui = ref.read(explorerControllerProvider);
    final shouldShow = _shouldShowLabelsForZoom(ui);
    final marker = _markerFor(controller, ui, camera, size);
    // Empty space on screen: no projected body inside the viewport means the
    // solar system has drifted out of view and the recovery shortcut appears.
    final systemVisible = LabelProjector.anyFrameOnScreen(frames, size);
    if (_framesEqual(frames, _labelFrames) &&
        shouldShow == _zoomLabelsVisible &&
        systemVisible == _systemVisible &&
        _sameOffset(marker?.center, _markedCenter) &&
        (marker == null || (marker.diameter - _markedDiameter).abs() <= 2.0)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _labelFrames = frames;
      _zoomLabelsVisible = shouldShow;
      _systemVisible = systemVisible;
      _markedCenter = marker?.center;
      if (marker != null) _markedDiameter = marker.diameter;
    });
  }

  /// Screen anchor of the marked target: its world centre plus a reticle
  /// diameter derived from its apparent size (world radius, camera distance,
  /// and field of view), so the ring hugs the body near or far. Null when
  /// there is no mark, detail is open (detail UI takes over), or the body is
  /// off-screen. The marker is purely visual: [IgnorePointer] in
  /// [_TargetMarker].
  ({Offset center, double diameter})? _markerFor(
    SolarSystemSceneController controller,
    ExplorerState ui,
    PerspectiveCamera camera,
    Size size,
  ) {
    final markedId = ui.markedTargetId;
    if (markedId == null || ui.hasSelection || size.isEmpty) return null;
    final center = controller.projectBodyCenter(markedId, camera, size);
    if (center == null) return null;
    const margin = 80.0;
    if (center.dx < -margin ||
        center.dx > size.width + margin ||
        center.dy < -margin ||
        center.dy > size.height + margin) {
      return null;
    }
    final worldRadius = controller.bodyWorldRadius(markedId);
    final bodyPos = controller.bodyWorldPosition(markedId);
    var diameter = 64.0;
    if (worldRadius != null && bodyPos != null && worldRadius > 0) {
      final distance = camera.position.distanceTo(bodyPos).clamp(1e-6, 1e9);
      final apparentPx =
          worldRadius /
          distance /
          math.tan(camera.fovRadiansY / 2) *
          (size.height / 2);
      diameter = (apparentPx * 2 * 1.3).clamp(44.0, 200.0);
    }
    return (center: center, diameter: diameter);
  }

  bool _sameOffset(Offset? a, Offset? b) {
    if (a == null || b == null) return a == b;
    return (a.dx - b.dx).abs() <= 1.5 && (a.dy - b.dy).abs() <= 1.5;
  }

  bool _shouldShowLabelsForZoom(ExplorerState ui) {
    // The user-controlled toggle is the master switch. Automatic hiding only
    // reacts to zoom while labels are enabled.
    if (!ui.showLabels) return false;

    if (ui.hasSelection) {
      // In detail mode, detailZoom > 1 means zooming out.
      return ui.detailZoom <= 1.75;
    }

    // Overview camera radius grows as the user zooms out.
    // Keep a little hysteresis so labels do not flicker around the boundary.
    final radius = ref.read(solarSystemSceneControllerProvider).rigState.radius;
    if (_zoomLabelsVisible) {
      return radius < 60.0;
    }
    return radius < 56.0;
  }

  bool _framesEqual(List<PlanetLabelFrame> a, List<PlanetLabelFrame> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if ((a[i].screenX - b[i].screenX).abs() > 1.5) return false;
      if ((a[i].screenY - b[i].screenY).abs() > 1.5) return false;
    }
    return true;
  }

  /// Applies one smoothed zoom step around the selected body, including the
  /// distance-based auto-deselect. Shared by the pinch gesture and the
  /// release glide so both feel like one continuous motion.
  void _applyDetailZoom(
    SolarSystemSceneController controller,
    double incrementalScale,
  ) {
    final currentZoom = ref.read(explorerControllerProvider).detailZoom;
    final nextZoom = currentZoom / incrementalScale;
    // Pinch zoom is persistent: releasing the gesture must not
    // leave detail mode or reset the current zoom. Leaving detail is
    // handled explicitly, not as a side effect of ScaleEnd.
    // No clamp: detail zoom is unbounded (only a tiny physical floor).
    ref
        .read(explorerControllerProvider.notifier)
        .updateDetailCamera(zoom: math.max(0.001, nextZoom));

    // Deselect only on real world-space distance (hysteresis), keeping
    // the exact camera position for free exploration. The eye is
    // frozen synchronously here: the scene tick must not do it, since
    // it can run with a stale frame's UI and snap back to 100%.
    final updatedUi = ref.read(explorerControllerProvider);
    final camera = controller.buildCamera(updatedUi);
    _lastCamera = camera;
    final selectedId = updatedUi.selectedPlanetId;
    if (selectedId != null &&
        controller.shouldAutoReleaseFocus(selectedId, camera)) {
      controller.preserveReleaseEye(camera);
      final explorer = ref.read(explorerControllerProvider.notifier);
      explorer.closeDetail();
      // Zooming far out means "done with this body": drop the mark too,
      // or the look-track would swing the view straight back onto it.
      // (Manual Close keeps the mark so the child can continue there.)
      explorer.clearMarkedTarget();
    }
  }

  /// Applies one smoothed zoom step in exploration mode: toward the marked
  /// target when one exists, otherwise toward the focal body under the
  /// fingers. Shared by the pinch gesture and the release glide.
  void _applyExploreZoom(
    SolarSystemSceneController controller,
    double incrementalScale,
    Offset focalLocal,
    Size viewSize,
  ) {
    // A marked target owns the zoom: any pinch approaches it, and
    // detail opens once the camera is close enough. Otherwise fall
    // back to the focal body under the fingers.
    final markedId = ref.read(explorerControllerProvider).markedTargetId;
    if (markedId != null) {
      controller.pinchTowardBody(incrementalScale, markedId);
      final camera = controller.buildCamera(
        ref.read(explorerControllerProvider),
      );
      _lastCamera = camera;
      // Track the approach for the >90% voice narration. The app shell
      // plays it (once per zoom session) from this progress; the marker
      // and the detail transition read the same state independently.
      ref
          .read(explorerControllerProvider.notifier)
          .reportMarkProgress(
            controller.markZoomProgress(markedId, camera),
            approaching: incrementalScale > 1.0,
          );
      if (controller.shouldAutoEnterDetail(markedId, camera)) {
        // Preserve the exact pinch distance: no snap to a default.
        final initialZoom = controller.prepareSeamlessSelection(
          markedId,
          camera,
        );
        if (!ref.read(explorerControllerProvider).hasSelection) {
          ref
              .read(explorerControllerProvider.notifier)
              .selectPlanet(markedId, initialDetailZoom: initialZoom);
        }
      }
    } else {
      // Resolve the focal body with the pre-pinch camera so the zoom
      // moves toward what is under the fingers (Earth, Jupiter, ...),
      // not always toward the origin/Sun. Then check auto-select with a
      // freshly built camera (not a one-frame-stale _lastCamera).
      final beforeCamera = controller.buildCamera(
        ref.read(explorerControllerProvider),
      );
      controller.pinchWithFocalPoint(
        incrementalScale,
        focalScreenPoint: focalLocal,
        viewSize: viewSize,
        camera: _lastCamera ?? beforeCamera,
      );
      final camera = controller.buildCamera(
        ref.read(explorerControllerProvider),
      );
      _lastCamera = camera;
      final pickedId = controller.pickPlanetForAutoFocus(
        focalLocal,
        viewSize,
        camera,
      );
      if (pickedId != null) {
        // Preserve the exact pinch distance: no snap to a default.
        final initialZoom = controller.prepareSeamlessSelection(
          pickedId,
          camera,
        );
        void select() => ref
            .read(explorerControllerProvider.notifier)
            .selectPlanet(pickedId, initialDetailZoom: initialZoom);
        // prepareSeamlessSelection snaps the rig only when the explorer is
        // still unselected; guard against a race where selection landed
        // between the pick and now.
        if (!ref.read(explorerControllerProvider).hasSelection) {
          select();
        }
      }
    }
  }

  /// Coasts the zoom after the fingers leave, decaying the last smoothed
  /// pinch velocity to rest. Runs on the scene tick so it stays in sync with
  /// rendering; a new gesture, tap, or flight takes over immediately.
  void _applyZoomGlide(
    SolarSystemSceneController controller,
    double deltaSeconds,
  ) {
    if (_pinchActive || controller.zoomFlightActive) return;
    if (_zoomGlide.abs() < 0.0005) {
      _zoomGlide = 0.0;
      return;
    }
    final ui = ref.read(explorerControllerProvider);
    if (ui.hasSelection) {
      _applyDetailZoom(controller, 1.0 + _zoomGlide);
    } else {
      _applyExploreZoom(
        controller,
        1.0 + _zoomGlide,
        _lastFocalLocal,
        _lastViewSize,
      );
    }
    _zoomGlide *= math.pow(0.02, deltaSeconds).toDouble();
    if (_zoomGlide.abs() < 0.0005) _zoomGlide = 0.0;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
    _pinchActive = false;
    _zoomGlide = 0.0;
    _angularVelocityX = 0.0;
    _angularVelocityY = 0.0;
    final controller = ref.read(solarSystemSceneControllerProvider);
    controller.resetPinchSmoothing();
    controller.setRotationVelocity(angularX: 0, angularY: 0);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastScale = 1.0;
    _pinchActive = false;
    // The zoom glide continues from the last smoothed pinch velocity (see
    // onTick): the camera coasts to rest instead of halting mid-motion.
    // Rotation inertia is handled the same way by the scene controller,
    // which damps the angular velocity every rendered frame.
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size viewSize) {
    final controller = ref.read(solarSystemSceneControllerProvider);
    final ui = ref.read(explorerControllerProvider);

    // Two pointers = pinch zoom. One pointer = orbit/spin.
    final rawIncremental = details.scale / _lastScale;
    if (details.pointerCount >= 2) {
      _angularVelocityX = 0.0;
      _angularVelocityY = 0.0;
      controller.setRotationVelocity(angularX: 0, angularY: 0);
      if (rawIncremental.isFinite && rawIncremental > 0) {
        // Ease the raw finger delta so jittery fingers don't jitter the
        // camera; the release glide below continues from this same value.
        final incrementalScale = controller.smoothPinchFactor(rawIncremental);
        _lastFocalLocal = details.localFocalPoint;
        _lastViewSize = viewSize;
        if (ui.hasSelection) {
          _applyDetailZoom(controller, incrementalScale);
        } else {
          _applyExploreZoom(
            controller,
            incrementalScale,
            details.localFocalPoint,
            viewSize,
          );
        }
        _pinchActive = true;
        _zoomGlide = (incrementalScale - 1.0).clamp(-0.25, 0.25);
        _lastScale = details.scale;
      }
      return;
    }

    if (details.pointerCount == 1) {
      final dx = details.focalPointDelta.dx;
      final dy = details.focalPointDelta.dy;

      if (ui.hasSelection) {
        final selectedId = ui.selectedPlanetId;
        if (selectedId != null) {
          // Rotate the actual planet, not the camera. The scene controller
          // applies the delta in the planet's local frame.
          controller.rotatePlanet(selectedId, dx, dy);
          _angularVelocityX = dy * 0.009 * 60.0;
          _angularVelocityY = dx * 0.009 * 60.0;
          controller.setRotationVelocity(
            planetId: selectedId,
            angularX: _angularVelocityX,
            angularY: _angularVelocityY,
          );
        }
      } else {
        // Rotate the actual solar-system model, not the camera.
        controller.rotateSolarSystem(dx, dy);
        _angularVelocityX = dy * 0.009 * 60.0;
        _angularVelocityY = dx * 0.009 * 60.0;
        controller.setRotationVelocity(
          angularX: _angularVelocityX,
          angularY: _angularVelocityY,
        );
      }
    }
  }

  /// Double-tap is the one-finger zoom shortcut for small hands.
  ///
  /// On a body it marks (if needed) and flies there with the same smooth
  /// flight as a second tap; on empty space it kicks a gentle zoom-out
  /// glide. Detail double-tap keeps its existing reset-framing meaning.
  /// (The two tap-ups that compose the double-tap fire first and already
  /// marked the body, so this usually just starts the flight.)
  void _onDoubleTap(TapDownDetails details, Size size) {
    final controller = ref.read(solarSystemSceneControllerProvider);
    final explorer = ref.read(explorerControllerProvider.notifier);
    _zoomGlide = 0.0;
    final ui = ref.read(explorerControllerProvider);
    if (ui.hasSelection) {
      explorer.resetDetailView();
      return;
    }
    final camera = _lastCamera;
    final pickedId = camera == null
        ? null
        : controller.pickPlanet(details.localPosition, size, camera);
    if (pickedId == null) {
      _pinchActive = false;
      _zoomGlide = -0.18;
      return;
    }
    if (pickedId != ui.markedTargetId) {
      explorer.markTarget(pickedId);
    }
    if (camera != null && !controller.zoomFlightActive) {
      controller.startZoomToDetail(pickedId, camera);
    }
  }

  void _onTapUp(TapUpDetails details, Size size) {
    final controller = ref.read(solarSystemSceneControllerProvider);
    final explorer = ref.read(explorerControllerProvider.notifier);
    _zoomGlide = 0.0;
    String? pickedId;
    final camera = _lastCamera;
    if (camera != null) {
      pickedId = controller.pickPlanet(details.localPosition, size, camera);
    }
    if (pickedId == null) {
      // Keep labels as a forgiving secondary target, matching the prototype's
      // tappable planet labels without requiring an exact mesh hit.
      PlanetLabelFrame? best;
      var bestDistSq = 48.0 * 48.0;
      for (final frame in _labelFrames) {
        if (!frame.visible) continue;
        final dx = frame.screenX - details.localPosition.dx;
        final dy = frame.screenY - details.localPosition.dy;
        final distSq = dx * dx + dy * dy;
        if (distSq < bestDistSq) {
          bestDistSq = distSq;
          best = frame;
        }
      }
      pickedId = best?.id;
    }
    final ui = ref.read(explorerControllerProvider);
    if (pickedId == null) {
      // Tapping empty space clears the mark (zoom focus) and its session,
      // returning to free exploration without touching detail.
      controller.cancelZoomFlight();
      if (!ui.hasSelection) explorer.clearMarkedTarget();
      return;
    }
    if (ui.hasSelection) {
      // In detail mode a tap switches straight to the new body, as before.
      controller.cancelZoomFlight();
      explorer.selectPlanet(pickedId);
    } else if (pickedId == ui.markedTargetId) {
      // Second tap on the marked object: smoothly zoom to 100% detail.
      // Marking itself never zooms; only this shortcut and pinches move
      // the camera, so the first tap cannot jump the view. A flight that is
      // already running for this body is left alone — restarting it on every
      // tap would keep pushing arrival away with each tap.
      if (camera != null && !controller.zoomFlightActive) {
        controller.startZoomToDetail(pickedId, camera);
      }
    } else {
      // First tap: mark as the zoom focus, keep the current zoom level.
      // Switching bodies takes over from any running flight.
      controller.cancelZoomFlight();
      explorer.markTarget(pickedId);
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.label, required this.fraction});

  final String label;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.space950,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.accentAmber,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            // Sized to the parent rather than to a phone: the explorer already
            // supports landscape and tablets, and a fixed width here is the
            // kind of thing that only shows up on a device nobody tests on.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                backgroundColor: Colors.white12,
                color: AppTheme.accentAmber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating tappable planet name chips projected from 3D.
/// Non-interactive reticle drawn over the marked target's world centre.
///
/// Purely visual ([IgnorePointer]): marking adds no buttons or controls, it
/// only shows which body pinch zoom is currently approaching. Hidden once
/// detail opens, where the detail UI takes over.
class _TargetMarker extends ConsumerWidget {
  const _TargetMarker({required this.center, required this.diameter});
  final Offset center;
  final double diameter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(isTelevisionProvider);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: center.dx - diameter / 2,
            top: center.dy - diameter / 2,
            width: diameter,
            height: diameter,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accentAmber,
                  width: isTv ? 3.5 : 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentAmber.withValues(
                      alpha: isTv ? 0.65 : 0.35,
                    ),
                    blurRadius: isTv ? 22 : 12,
                    spreadRadius: isTv ? 3 : 1,
                  ),
                ],
              ),
              child: isTv
                  ? Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.5,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recovery shortcut back to the Sun/overview framing.
///
/// Rendered only when no projected body is inside the viewport at all (see
/// [LabelProjector.anyFrameOnScreen]) and no detail is open. Tapping it
/// restores the comfortable overview and drops the mark; it never appears
/// during normal exploration or inside detail mode.
class _JumpToSunButton extends StatelessWidget {
  const _JumpToSunButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.space700.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.accentAmber, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentAmber.withValues(alpha: 0.3),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('☀️', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'Back to the Sun',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanetLabelsOverlay extends StatelessWidget {
  const _PlanetLabelsOverlay({
    required this.frames,
    required this.planets,
    required this.showLabels,
    required this.selectedId,
    required this.markedId,
    required this.onMarkedTap,
  });
  final List<PlanetLabelFrame> frames;
  final List<Planet> planets;
  final bool showLabels;
  final String? selectedId;
  final String? markedId;
  final VoidCallback onMarkedTap;
  @override
  Widget build(BuildContext context) {
    final byId = {for (final p in planets) p.id: p};
    // Chip half-width from the same viewport scale the chip content uses,
    // so the anchor math and the drawn chip can never disagree.
    final halfW = DesignScale.sharedOf(context).px(60);
    return IgnorePointer(
      ignoring: !showLabels,
      child: AnimatedOpacity(
        opacity: showLabels ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        // Labels off means zero chips, not invisible ones: an opacity-0 chip
        // still lays out, composites and repaints every frame while the
        // camera moves, for pixels nobody can see.
        child: Stack(
          children: [
            if (showLabels)
              for (final frame in frames)
                if (frame.visible &&
                    frame.id != selectedId &&
                    byId.containsKey(frame.id))
                  Positioned(
                    left: frame.screenX - halfW,
                    top: frame.screenY - 18,
                    width: halfW * 2,
                    child: _LabelChip(
                      name: byId[frame.id]!.name,
                      colorValue: byId[frame.id]!.colorValue,
                      selected: frame.id == selectedId,
                      marked: frame.id == markedId,
                      planetId: frame.id,
                      onMarkedTap: onMarkedTap,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _LabelChip extends ConsumerWidget {
  const _LabelChip({
    required this.name,
    required this.colorValue,
    required this.selected,
    required this.marked,
    required this.planetId,
    required this.onMarkedTap,
  });
  final String name;
  final int colorValue;
  final bool selected;
  final bool marked;
  final String planetId;
  final VoidCallback onMarkedTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Chip content scales with the viewport, like every other overlay.
    final ds = DesignScale.sharedOf(context);
    return GestureDetector(
      onTap: () {
        final explorer = ref.read(explorerControllerProvider.notifier);
        // Labels follow the same model as 3D taps: mark in exploration mode
        // (a marked chip starts the zoom-to-detail flight), switch detail
        // directly while a detail is already open.
        if (ref.read(explorerControllerProvider).hasSelection) {
          explorer.selectPlanet(planetId);
        } else if (marked) {
          onMarkedTap();
        } else {
          explorer.markTarget(planetId);
        }
      },
      child: Container(
        padding: ds.insets(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.space700.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(ds.radius(999)),
          border: Border.all(
            color: selected || marked
                ? AppTheme.accentAmber
                : Colors.white.withValues(alpha: 0.18),
            width: ds.px(selected || marked ? 2 : 1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ds.px(8),
              height: ds.px(8),
              decoration: BoxDecoration(
                color: Color(colorValue),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: ds.px(6)),
            Flexible(
              child: Text(
                name,
                style: AppTheme.labelGlow.copyWith(fontSize: ds.font(10)),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
