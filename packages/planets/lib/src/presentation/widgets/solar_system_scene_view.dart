import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scene/scene.dart';

import 'package:planets/state.dart';
import 'package:planets/domain.dart';
import 'package:planets/scene.dart';
import 'package:core/theme.dart';

/// True 3D solar system rendered with flutter_scene (no WebView).
class SolarSystemSceneView extends ConsumerStatefulWidget {
  const SolarSystemSceneView({super.key});
  @override
  ConsumerState<SolarSystemSceneView> createState() =>
      _SolarSystemSceneViewState();
}

class _SolarSystemSceneViewState extends ConsumerState<SolarSystemSceneView> {
  bool _buildStarted = false;
  bool _ready = false;
  String _loadingLabel = 'Warming up the rockets...';
  double _buildFraction = 0.0;
  PerspectiveCamera? _lastCamera;
  List<PlanetLabelFrame> _labelFrames = const [];
  Offset? _markedCenter;
  double _markedDiameter = 64.0;
  double _lastScale = 1.0;
  double _angularVelocityX = 0.0;
  double _angularVelocityY = 0.0;
  bool _zoomLabelsVisible = true;
  bool _presentedReported = false;

  @override
  void initState() {
    super.initState();
    // A fresh mount means a fresh first frame is still owed: tell the
    // startup handover to wait for this view's first presented tick rather
    // than revealing a compiling scene mid-crossfade.
    ref.read(explorerScenePresentedProvider.notifier).state = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBuilt());
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
      if (previous?.selectedPlanetId != null &&
          next.selectedPlanetId == null) {
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
          onDoubleTap: () {
            ref.read(explorerControllerProvider.notifier).resetDetailView();
          },
          onTapUp: (d) => _onTapUp(d, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SceneView(
                controller.scene,
                cameraBuilder: (elapsed) {
                  final camera = controller.buildCamera(ui);
                  _lastCamera = camera;
                  return camera;
                },
                onTick: (elapsed, deltaSeconds) {
                  controller.tick(deltaSeconds, ui);
                  // The scene just presented a frame with built content: the
                  // startup handover may now reveal the Explorer.
                  if (_ready && !_presentedReported) {
                    _presentedReported = true;
                    ref.read(explorerScenePresentedProvider.notifier).state =
                        true;
                  }
                  _driveZoomFlight(controller, deltaSeconds);
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
                  // smooth zoom-to-detail flight.
                  final markedId =
                      ref.read(explorerControllerProvider).markedTargetId;
                  final cam = _lastCamera;
                  if (markedId == null || cam == null) return;
                  controller.cancelZoomFlight();
                  controller.startZoomToDetail(markedId, cam);
                },
              ),
              if (_markedCenter != null &&
                  ui.markedTargetId != null &&
                  !ui.hasSelection)
                _TargetMarker(
                  center: _markedCenter!,
                  diameter: _markedDiameter,
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
    final camera = controller.buildCamera(
      ref.read(explorerControllerProvider),
    );
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
    if (_framesEqual(frames, _labelFrames) &&
        shouldShow == _zoomLabelsVisible &&
        _sameOffset(marker?.center, _markedCenter) &&
        (marker == null ||
            (marker.diameter - _markedDiameter).abs() <= 2.0)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _labelFrames = frames;
      _zoomLabelsVisible = shouldShow;
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
      final distance = camera.position
          .distanceTo(bodyPos)
          .clamp(1e-6, 1e9);
      final apparentPx =
          worldRadius / distance / math.tan(camera.fovRadiansY / 2) *
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

  void _onScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
    _angularVelocityX = 0.0;
    _angularVelocityY = 0.0;
    ref
        .read(solarSystemSceneControllerProvider)
        .setRotationVelocity(angularX: 0, angularY: 0);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastScale = 1.0;
    // Keep the last gesture velocity. The scene controller damps it every
    // rendered frame, giving the globe/model a natural inertial finish.
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size viewSize) {
    final controller = ref.read(solarSystemSceneControllerProvider);
    final ui = ref.read(explorerControllerProvider);

    // Two pointers = pinch zoom. One pointer = orbit/spin.
    final incrementalScale = details.scale / _lastScale;
    if (details.pointerCount >= 2) {
      _angularVelocityX = 0.0;
      _angularVelocityY = 0.0;
      controller.setRotationVelocity(angularX: 0, angularY: 0);
      if (incrementalScale.isFinite && incrementalScale > 0) {
        if (ui.hasSelection) {
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
            ref.read(explorerControllerProvider.notifier).closeDetail();
          }
        } else {
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
              focalScreenPoint: details.localFocalPoint,
              viewSize: viewSize,
              camera: _lastCamera ?? beforeCamera,
            );
            final camera = controller.buildCamera(
              ref.read(explorerControllerProvider),
            );
            _lastCamera = camera;
            final pickedId = controller.pickPlanetForAutoFocus(
              details.localFocalPoint,
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

  void _onTapUp(TapUpDetails details, Size size) {
    final controller = ref.read(solarSystemSceneControllerProvider);
    final explorer = ref.read(explorerControllerProvider.notifier);
    // A new tap always takes over from a running zoom-to-detail flight.
    controller.cancelZoomFlight();
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
      if (!ui.hasSelection) explorer.clearMarkedTarget();
      return;
    }
    if (ui.hasSelection) {
      // In detail mode a tap switches straight to the new body, as before.
      explorer.selectPlanet(pickedId);
    } else if (pickedId == ui.markedTargetId) {
      // Second tap on the marked object: smoothly zoom to 100% detail.
      // Marking itself never zooms; only this shortcut and pinches move
      // the camera, so the first tap cannot jump the view.
      if (camera != null) controller.startZoomToDetail(pickedId, camera);
    } else {
      // First tap: mark as the zoom focus, keep the current zoom level.
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
class _TargetMarker extends StatelessWidget {
  const _TargetMarker({required this.center, required this.diameter});
  final Offset center;
  final double diameter;

  @override
  Widget build(BuildContext context) {
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
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentAmber.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return IgnorePointer(
      ignoring: !showLabels,
      child: AnimatedOpacity(
        opacity: showLabels ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: Stack(
          children: [
            for (final frame in frames)
              if (frame.visible &&
                  frame.id != selectedId &&
                  byId.containsKey(frame.id))
                Positioned(
                  left: frame.screenX - 60,
                  top: frame.screenY - 18,
                  width: 120,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.space700.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected || marked
                ? AppTheme.accentAmber
                : Colors.white.withValues(alpha: 0.18),
            width: selected || marked ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(colorValue),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                style: AppTheme.labelGlow,
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
