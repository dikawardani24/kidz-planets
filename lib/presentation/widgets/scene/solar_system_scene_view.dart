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
  // Previous cumulative scale within the active scale gesture. Used to turn
  // the cumulative ScaleUpdateDetails.scale into an incremental delta.
  double _prevScale = 1.0;

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
        // Under a Center+ConstrainedBox parent the max constraints can be
        // unbounded; fall back to the real screen size so SceneView always
        // gets a non-zero draw region.
        var size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!size.isEmpty && size.width.isFinite && size.height.isFinite) {
          // ignore: no-op — size is already usable
        } else {
          size = MediaQuery.sizeOf(context);
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          onTapUp: (d) => _onTapUp(d, size),
          child: SizedBox.fromSize(
            size: size.isEmpty ? null : size,
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
    _prevScale = 1.0;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _prevScale = 1.0;
  }

  /// Unified drag + pinch handler.
  ///
  /// Flutter disallows combining a pan recognizer with a scale recognizer
  /// (scale is a superset of pan), so single-finger drags arrive here via
  /// [ScaleUpdateDetails.focalPointDelta] with `scale == 1.0`.
  void _onScaleUpdate(ScaleUpdateDetails details) {
    final controller = ref.read(solarSystemSceneControllerProvider);
    final ui = ref.read(explorerControllerProvider);
    final notifier = ref.read(explorerControllerProvider.notifier);

    // ScaleUpdateDetails.scale is cumulative from gesture start, so derive
    // the incremental factor since the last update.
    var incrementalScale = 1.0;
    if (_prevScale != 0.0) {
      incrementalScale = details.scale / _prevScale;
    }
    _prevScale = details.scale;

    final isPinching = (incrementalScale - 1.0).abs() > 0.002;
    if (isPinching) {
      if (ui.hasSelection) {
        notifier.updateDetailCamera(
          zoom: (ui.detailZoom * incrementalScale).clamp(0.6, 2.6),
        );
      } else {
        controller.pinch(incrementalScale);
      }
      return;
    }

    final delta = details.focalPointDelta;
    if (delta == Offset.zero) return;
    if (ui.hasSelection) {
      controller.addSpinBoost(delta.dx * 0.00012);
      notifier.updateDetailCamera(
        theta: ui.detailTheta + delta.dx * 0.008,
        phi: (ui.detailPhi + delta.dy * 0.005).clamp(-0.2, 1.3),
      );
    } else if (details.pointerCount >= 2) {
      // Preserve the previous two-finger drag direction.
      controller.orbitBy(-delta.dx, -delta.dy);
    } else {
      controller.orbitBy(delta.dx, delta.dy);
    }
  }

  void _onTapUp(TapUpDetails details, Size size) {
    PlanetLabelFrame? best;
    var bestDistSq = 48.0 * 48.0;
    for (final frame in _labelFrames) {
      if (!frame.visible) continue;
      final dx = frame.screenX - details.localPosition.dx;
      final dy = frame.screenY - details.localPosition.dy;
      final distSq = dx * dx + dy * dy;
      if (distSq < bestDistSq) { bestDistSq = distSq; best = frame; }
    }
    if (best == null) return;
    ref.read(explorerControllerProvider.notifier).selectPlanet(best.id);
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
          if (frame.visible && byId.containsKey(frame.id))
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
