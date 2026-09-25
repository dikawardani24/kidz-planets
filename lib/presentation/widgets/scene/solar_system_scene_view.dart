import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scene/scene.dart';

import '../../../application/state/providers.dart';
import '../../../domain/entities/planet.dart';
import '../../../infrastructure/scene/scene_models.dart';
import '../../../infrastructure/scene/solar_system_scene_controller.dart';
import '../../../infrastructure/services/scene_providers.dart';
import '../../theme/app_theme.dart';

/// True 3D solar system rendered with flutter_scene (no WebView).
class SolarSystemSceneView extends ConsumerStatefulWidget {
  const SolarSystemSceneView({super.key});
  @override
  ConsumerState<SolarSystemSceneView> createState() => _SolarSystemSceneViewState();
}

class _SolarSystemSceneViewState extends ConsumerState<SolarSystemSceneView> {
  bool _buildStarted = false;
  bool _ready = false;
  String _loadingLabel = 'Warming up the rockets...';
  PerspectiveCamera? _lastCamera;
  List<PlanetLabelFrame> _labelFrames = const [];
  double _lastScale = 1.0;
  double _pinchStartZoom = 1.0;

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
        onProgress: (label) { if (mounted) setState(() => _loadingLabel = label); },
      );
      controller.setOrbitsVisible(ref.read(explorerControllerProvider).showOrbits);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _loadingLabel = 'Oops! Could not load space: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(solarSystemSceneControllerProvider);
    final ui = ref.watch(explorerControllerProvider);
    final planets = ref.watch(planetsProvider);
    if (!_ready) return _LoadingView(label: _loadingLabel);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanUpdate: _onPanUpdate,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
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
                showLabels: ui.showLabels,
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
    if (_framesEqual(frames, _labelFrames)) return;
    if (!mounted) return;
    setState(() => _labelFrames = frames);
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
    final ui = ref.read(explorerControllerProvider);
    _lastScale = 1.0;
    _pinchStartZoom = ui.detailZoom;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastScale = 1.0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final controller = ref.read(solarSystemSceneControllerProvider);
    final ui = ref.read(explorerControllerProvider);
    if (ui.hasSelection) {
      final selectedId = ui.selectedPlanetId;
      if (selectedId != null) {
        controller.spinPlanet(selectedId, details.delta.dx * 0.009);
      }
      ref.read(explorerControllerProvider.notifier).updateDetailCamera(
        theta: ui.detailTheta + details.delta.dx * 0.008,
        phi: (ui.detailPhi + details.delta.dy * 0.006).clamp(-0.45, 1.35),
      );
    } else {
      controller.orbitBy(details.delta.dx, details.delta.dy);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final controller = ref.read(solarSystemSceneControllerProvider);
    final ui = ref.read(explorerControllerProvider);
    if (details.scale != 1.0) {
      if (ui.hasSelection) {
        ref.read(explorerControllerProvider.notifier).updateDetailCamera(
          zoom: (_pinchStartZoom * details.scale).clamp(0.4, 2.6),
        );
      } else {
        final incrementalScale = details.scale / _lastScale;
        if (incrementalScale.isFinite && incrementalScale > 0) {
          controller.pinch(incrementalScale);
          _lastScale = details.scale;
        }
      }
      return;
    }
    if (details.pointerCount >= 2) {
      controller.orbitBy(-details.focalPointDelta.dx, -details.focalPointDelta.dy);
    }
  }

  void _onTapUp(TapUpDetails details, Size size) {
    final controller = ref.read(solarSystemSceneControllerProvider);
    final camera = _lastCamera;
    if (camera != null) {
      final pickedId = controller.pickPlanet(details.localPosition, size, camera);
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
  const _LoadingView({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.space950,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 44, height: 44,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.accentAmber)),
            const SizedBox(height: 16),
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
/// Floating tappable planet name chips projected from 3D.
class _PlanetLabelsOverlay extends StatelessWidget {
  const _PlanetLabelsOverlay({required this.frames, required this.planets, required this.showLabels, required this.selectedId});
  final List<PlanetLabelFrame> frames;
  final List<Planet> planets;
  final bool showLabels;
  final String? selectedId;
  @override
  Widget build(BuildContext context) {
    if (!showLabels) return const SizedBox.shrink();
    final byId = {for (final p in planets) p.id: p};
    return Stack(
      children: [
        for (final frame in frames)
          if (frame.visible && frame.id != selectedId && byId.containsKey(frame.id))
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
    );
  }
}

class _LabelChip extends ConsumerWidget {
  const _LabelChip({required this.name, required this.colorValue, required this.selected, required this.planetId});
  final String name;
  final int colorValue;
  final bool selected;
  final String planetId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(explorerControllerProvider.notifier).selectPlanet(planetId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.space700.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppTheme.accentAmber : Colors.white.withValues(alpha: 0.18), width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: Color(colorValue), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(child: Text(name, style: AppTheme.labelGlow, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
