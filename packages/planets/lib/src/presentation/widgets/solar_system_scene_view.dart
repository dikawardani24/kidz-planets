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
  double _lastScale = 1.0;
  double _angularVelocityX = 0.0;
  double _angularVelocityY = 0.0;
  bool _zoomLabelsVisible = true;

  @override
  void initState() {
    super.initState();
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
                  _refreshLabels(controller, size);
                },
              ),
              _PlanetLabelsOverlay(
                frames: _labelFrames,
                planets: planets,
                showLabels: ui.showLabels && _zoomLabelsVisible,
                selectedId: ui.selectedPlanetId,
              ),
            ],
          ),
        );
      },
    );
  }

  void _refreshLabels(SolarSystemSceneController controller, Size size) {
    final camera = _lastCamera;
    if (camera == null || size.isEmpty) return;
    final frames = controller.projectLabels(camera, size);
    final ui = ref.read(explorerControllerProvider);
    final shouldShow = _shouldShowLabelsForZoom(ui);
    if (_framesEqual(frames, _labelFrames) &&
        shouldShow == _zoomLabelsVisible) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _labelFrames = frames;
      _zoomLabelsVisible = shouldShow;
    });
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
          ref
              .read(explorerControllerProvider.notifier)
              .updateDetailCamera(zoom: nextZoom);

          // Zooming out far enough automatically exits detail mode. This is
          // based on real camera/body distance rather than a UI percentage.
          final updatedUi = ref.read(explorerControllerProvider);
          final camera = _lastCamera;
          final selectedId = updatedUi.selectedPlanetId;
          if (camera != null &&
              selectedId != null &&
              controller.shouldAutoReleaseFocus(selectedId, camera)) {
            ref.read(explorerControllerProvider.notifier).closeDetail();
          }
        } else {
          controller.pinch(incrementalScale);

          // Overview zoom is not just a radial slider. Once the body under the
          // pinch focal point is physically close enough, promote it to detail
          // mode so the child can keep zooming naturally into that object.
          final camera = _lastCamera;
          final pickedId = camera == null
              ? null
              : controller.pickPlanetForAutoFocus(
                  details.focalPoint,
                  viewSize,
                  camera,
                );
          if (pickedId != null && camera != null) {
            // Promote the body under the pinch without changing the current
            // physical camera distance. The selected camera will now orbit
            // that body, but it starts from the exact zoom level reached by
            // the user rather than snapping back to 1.0.
            final initialZoom = controller.detailZoomForPlanetAtCameraDistance(
              pickedId,
              camera,
            );
            ref
                .read(explorerControllerProvider.notifier)
                .selectPlanet(pickedId, initialDetailZoom: initialZoom);
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
    final camera = _lastCamera;
    if (camera != null) {
      final pickedId = controller.pickPlanet(
        details.localPosition,
        size,
        camera,
      );
      if (pickedId != null) {
        ref.read(explorerControllerProvider.notifier).selectPlanet(pickedId);
        return;
      }
    }

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
    if (best != null) {
      ref.read(explorerControllerProvider.notifier).selectPlanet(best.id);
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
class _PlanetLabelsOverlay extends StatelessWidget {
  const _PlanetLabelsOverlay({
    required this.frames,
    required this.planets,
    required this.showLabels,
    required this.selectedId,
  });
  final List<PlanetLabelFrame> frames;
  final List<Planet> planets;
  final bool showLabels;
  final String? selectedId;
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
                    planetId: frame.id,
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
    required this.planetId,
  });
  final String name;
  final int colorValue;
  final bool selected;
  final String planetId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () =>
          ref.read(explorerControllerProvider.notifier).selectPlanet(planetId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.space700.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppTheme.accentAmber
                : Colors.white.withValues(alpha: 0.18),
            width: selected ? 2 : 1,
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
