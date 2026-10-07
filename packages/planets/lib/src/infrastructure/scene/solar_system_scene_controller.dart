import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:planets/state.dart';
import 'package:core/time.dart';
import 'package:planets/domain.dart';

import 'orbit_camera_rig.dart';
import 'scene_factories.dart';
import 'scene_models.dart';
import 'solar_system_animator.dart';
import 'solar_system_scene_builder.dart';
import 'texture_provider.dart';

/// Facade over the whole 3D stack (ISP: one narrow interface for widgets).
abstract class SolarSystemSceneController {
  Scene get scene;
  CameraRigState get rigState;
  bool get isReady;

  /// Builds the Sun, the planets and the orbits. Safe to call repeatedly.
  ///
  /// Startup calls this before the Explorer exists, so the first frame the
  /// child sees is a finished solar system instead of a spinner over a scene
  /// that is still decoding.
  Future<void> ensureBuilt({
    required List<Planet> planets,
    required void Function(double fraction, String label) onProgress,
  });

  /// Adds the moons, which is deliberately not part of [ensureBuilt].
  ///
  /// Safe to call repeatedly and from a lazy warm: the second call is a no-op
  /// rather than a second copy of every moon.
  Future<void> ensureMoonsBuilt({
    required List<Planet> moons,
    required void Function(double fraction, String label) onProgress,
  });

  /// Whether the moons are in the scene yet.
  ///
  /// Exposed so the startup code can tell a lazy warm apart from a second full
  /// build, and so a test can assert the moons really did arrive later.
  bool get areMoonsBuilt;

  /// How many textures are already decoded and resident.
  ///
  /// Reported on the loading screen's diagnostics and asserted in tests: it is
  /// the one number that proves a warm start did not decode the sky twice.
  int get cachedTextureCount;

  PerspectiveCamera buildCamera(ExplorerState ui);
  void tick(double deltaSeconds, ExplorerState ui);
  List<PlanetLabelFrame> projectLabels(PerspectiveCamera camera, Size viewSize);
  void setOrbitsVisible(bool visible);
  bool labelsVisibleAtZoom(ExplorerState ui);
  void setPlanetOrbitRadius(String planetId, double radius);
  void addSpinBoost(double amount);
  String? pickPlanet(
    Offset screenPosition,
    Size viewSize,
    PerspectiveCamera camera,
  );

  /// Body under [screenPosition] only when the camera is already close enough
  /// for automatic detail selection (world-radius hysteresis: enter = 7x).
  String? pickPlanetForAutoFocus(
    Offset screenPosition,
    Size viewSize,
    PerspectiveCamera camera,
  );

  /// Detail zoom reproducing the current camera distance to [planetId], so
  /// auto-selection preserves the exact pinch distance instead of snapping to
  /// the default focus distance.
  double detailZoomForPlanetAtCameraDistance(
    String planetId,
    PerspectiveCamera camera,
  );

  /// True when a focused body has been zoomed far enough away (world-radius
  /// hysteresis: exit = 12x) that detail mode should hand back to free explore.
  bool shouldAutoReleaseFocus(String planetId, PerspectiveCamera camera);

  /// World-space centre of [planetId], or null when unknown.
  vm.Vector3? bodyWorldPosition(String planetId);

  /// World-space rendered radius of [planetId] (logical radius × node scale).
  double? bodyWorldRadius(String planetId);

  /// Free pinch that zooms toward whatever is under the focal screen point
  /// instead of always dollying toward the origin/Sun.
  void pinchWithFocalPoint(
    double scale, {
    Offset? focalScreenPoint,
    Size? viewSize,
    PerspectiveCamera? camera,
  });

  /// Free pinch that zooms toward a known body (the marked target) without
  /// needing a raycast hit under the fingers.
  ///
  /// Unknown ids fall back to a plain dolly, so a stale mark can never throw.
  void pinchTowardBody(double scale, String planetId);

  /// True when the camera is close enough to [planetId] to enter detail
  /// (world-radius hysteresis: enter = 7x, the mirror of
  /// [shouldAutoReleaseFocus]).
  bool shouldAutoEnterDetail(String planetId, PerspectiveCamera camera);

  /// Zoom progress toward [planetId] for the marked-target narration, or 0
  /// when the body is unknown. See [OrbitCameraRig.approachProgress].
  double markZoomProgress(String planetId, PerspectiveCamera camera);

  /// Screen position of [planetId]'s world centre, or null when unknown,
  /// behind the camera, or outside [viewSize].
  Offset? projectBodyCenter(
    String planetId,
    PerspectiveCamera camera,
    Size viewSize,
  );

  /// Snap the rig onto [planetId] keeping the given camera eye fixed.
  /// Returns the detail zoom reproducing that distance.
  double prepareSeamlessSelection(String planetId, PerspectiveCamera camera);

  /// Whether a "zoom to Detail" flight is currently running.
  bool get zoomFlightActive;

  /// Starts the smooth zoom-to-detail flight toward [planetId] from [camera]'s
  /// eye ("second tap on the marked object"). Unknown ids are ignored.
  /// Marking itself never zooms; only this call (or a pinch) moves the eye.
  void startZoomToDetail(String planetId, PerspectiveCamera camera);

  /// Stops a running flight (manual pinch, retap, or mark switch).
  void cancelZoomFlight();

  /// Advances the flight and returns its state plus approach progress.
  /// Unknown bodies end the flight as done with zero progress.
  ({bool done, double progress}) stepZoomFlight(
    double deltaSeconds,
    String planetId,
  );

  /// Freeze [camera]'s eye into the orbit state so the following deselection
  /// keeps the exact camera position for free exploration, and restore the
  /// stable solar-system anchor so later gestures orbit the system rather
  /// than the just-deselected body. Call synchronously before clearing the
  /// selection: the per-frame tick must never do this itself, because it can
  /// run with a stale frame's UI and would then overwrite the preserved
  /// distance with a default.
  void preserveReleaseEye(PerspectiveCamera camera);
  void spinPlanet(String planetId, double delta);
  void rotatePlanet(String planetId, double dx, double dy);
  void rotateSolarSystem(double dx, double dy);
  void setRotationVelocity({
    String? planetId,
    required double angularX,
    required double angularY,
  });
  void orbitBy(double dx, double dy);
  void pinch(double scale);

  /// Eases a raw per-frame pinch factor; see [OrbitCameraRig.smoothPinchFactor].
  double smoothPinchFactor(double rawIncrementalScale);

  /// Restarts pinch smoothing for a new gesture.
  void resetPinchSmoothing();

  /// Restores the comfortable overview framing (system centered, default
  /// distance/orientation) for the jump-to-Sun recovery button. Any running
  /// zoom flight is cancelled first.
  void resetOverview();

  /// Budgets texture decoding for constrained devices (see
  /// [AssetTextureProvider.maxDecodeWidth]).
  ///
  /// Call before [ensureBuilt]; the cache is keyed by asset path, so changing
  /// the budget mid-build would mix resolutions. Startup resolves the device
  /// capability tier and sets this once, before the solar-system task runs.
  void setMaxTextureDecodeWidth(int? maxWidth);

  /// Pre-compiles the render pipelines and uploads the scene's GPU resources
  /// behind the loading screen, so the Explorer's first visible frame does
  /// not stall on shader compilation.
  ///
  /// Call once, after [ensureBuilt], with the current explorer state: the
  /// warm-up frame uses the same overview camera the scene view will show, so
  /// the compiled pipeline variants match the real first frame. Never throws:
  /// a warm-up failure only means the first frame pays the compile cost the
  /// old way (still hidden behind the intro by the startup gate). Safe to
  /// repeat; later moon attachments reuse the same material pipelines.
  Future<void> warmUpPipelines(ExplorerState ui);
  void dispose();
}

/// Default implementation wiring builder + animator + camera (DIP: depends
/// on [SimulationClock] abstraction, not on widgets).
class SolarSystemSceneControllerImpl implements SolarSystemSceneController {
  SolarSystemSceneControllerImpl({required this._clock})
    : _scene = Scene(),
      _textures = AssetTextureProvider(),
      _geometries = GeometryFactory(),
      _rigState = CameraRigState() {
    _materials = PlanetMaterialFactory();
    _builder = SolarSystemSceneBuilder(
      textures: _textures,
      geometries: _geometries,
      materials: _materials,
    );
    _rig = OrbitCameraRig(state: _rigState);
  }

  final SimulationClock _clock;
  final Scene _scene;
  final TextureProvider _textures;
  final GeometryFactory _geometries;
  late final PlanetMaterialFactory _materials;
  late final SolarSystemSceneBuilder _builder;
  late final OrbitCameraRig _rig;
  final CameraRigState _rigState;

  SolarSystemAnimator? _animator;
  LabelProjector? _projector;
  bool _built = false;
  Future<void>? _buildFuture;
  Future<void>? _moonsFuture;
  bool _pipelinesWarmed = false;
  double _rotationVelocityX = 0.0;
  double _rotationVelocityY = 0.0;
  String? _rotationVelocityPlanetId;
  String? _lastFocusedPlanetId;

  @override
  Scene get scene => _scene;

  @override
  CameraRigState get rigState => _rigState;

  @override
  bool get isReady => _built;

  @override
  Future<void> ensureBuilt({
    required List<Planet> planets,
    required void Function(double fraction, String label) onProgress,
  }) {
    if (_built) return Future<void>.value();
    final inFlight = _buildFuture;
    if (inFlight != null) return inFlight;

    // Memoize the in-flight future so concurrent callers join one build.
    // On failure, clear the memo so coordinator retry() can rebuild: a sticky
    // failed Future would make every retry re-await the same error forever.
    final run = () async {
      try {
        // The full catalogue, moons included, goes to the animator and the label
        // projector even though only the planets are built here: both read the
        // builder's state map per frame and pick the moons up the moment the lazy
        // build adds them.
        await _builder.build(
          scene: _scene,
          planets: planets,
          onProgress: onProgress,
        );
        _animator?.detach();
        _animator = SolarSystemAnimator(
          clock: _clock,
          builder: _builder,
          planets: planets,
        );
        _animator!.attach();
        _projector = LabelProjector(builder: _builder, planets: planets);
        if (!_built) {
          _rigState
            ..theta = 0.0
            ..phi = 0.32
            ..radius = OrbitCameraRig.kOverviewRadius
            ..fovRadians = 0.85;
        }
        _built = true;
      } catch (_) {
        _buildFuture = null;
        rethrow;
      }
    }();
    _buildFuture = run;
    return run;
  }

  @override
  Future<void> ensureMoonsBuilt({
    required List<Planet> moons,
    required void Function(double fraction, String label) onProgress,
  }) {
    if (_builder.moonsBuilt) return Future<void>.value();
    final inFlight = _moonsFuture;
    if (inFlight != null) return inFlight;

    final run = () async {
      try {
        await _builder.buildMoons(moons: moons, onProgress: onProgress);
      } catch (_) {
        _moonsFuture = null;
        rethrow;
      }
    }();
    _moonsFuture = run;
    return run;
  }

  @override
  bool get areMoonsBuilt => _builder.moonsBuilt;

  @override
  int get cachedTextureCount => _textures.cachedCount;

  @override
  PerspectiveCamera buildCamera(ExplorerState ui) => _rig.buildCamera(ui: ui);

  @override
  bool labelsVisibleAtZoom(ExplorerState ui) => _rig.labelsVisibleAtZoom(ui);

  @override
  void tick(double deltaSeconds, ExplorerState ui) {
    _clock.tick(deltaSeconds);
    final focused = ui.focusedPlanetId;
    if (focused != _lastFocusedPlanetId) {
      _rotationVelocityX = 0.0;
      _rotationVelocityY = 0.0;
      _rotationVelocityPlanetId = focused;
      _lastFocusedPlanetId = focused;
    }
    _animator?.setFocusedPlanet(focused);

    if (_rotationVelocityX.abs() > 0.0001 ||
        _rotationVelocityY.abs() > 0.0001) {
      if (_rotationVelocityPlanetId != null) {
        _builder.rotatePlanetAngularVelocity(
          _rotationVelocityPlanetId!,
          _rotationVelocityX,
          _rotationVelocityY,
          deltaSeconds,
        );
      } else {
        _builder.rotateSolarSystemAngularVelocity(
          _rotationVelocityX,
          _rotationVelocityY,
          deltaSeconds,
        );
      }
      final damping = math.pow(0.055, deltaSeconds).toDouble();
      _rotationVelocityX *= damping;
      _rotationVelocityY *= damping;
    }

    _animator?.tick(deltaSeconds);
    if (focused != null) {
      // Land the focus flight on the user's current zoom, not on a default:
      // otherwise a fresh/restarted flight drags the camera back to 100%
      // framing while the user is pinching out toward deselection.
      _rig.focusOn(
        focused,
        _builder,
        deltaSeconds: deltaSeconds,
        detailZoom: ui.detailZoom,
      );
    } else {
      // A marked body steers the look direction (not the zoom): the eye
      // stays put while the target eases onto the body, so tapping Earth
      // turns the camera to face Earth instead of staring at the Sun. The
      // zoom-to-detail flight owns the target while it runs.
      final markedId = ui.markedTargetId;
      if (markedId != null && !_rig.zoomFlightActive) {
        final pos = bodyWorldPosition(markedId);
        if (pos != null) {
          _rig.easeLookAt(bodyPos: pos, deltaSeconds: deltaSeconds);
        }
      }
      _rig.releaseFocus();
    }
  }

  @override
  List<PlanetLabelFrame> projectLabels(
    PerspectiveCamera camera,
    Size viewSize,
  ) {
    final projector = _projector;
    if (projector == null || !_built) return const [];
    return projector.project(camera: camera, viewSize: viewSize);
  }

  @override
  void setOrbitsVisible(bool visible) => _builder.setOrbitsVisible(visible);

  @override
  void setPlanetOrbitRadius(String planetId, double radius) {
    _builder.setPlanetOrbitRadius(planetId, radius);
    _animator?.setOrbitRadius(planetId, radius);
  }

  @override
  void addSpinBoost(double amount) => _animator?.addSpinBoost(amount);

  @override
  String? pickPlanet(
    Offset screenPosition,
    Size viewSize,
    PerspectiveCamera camera,
  ) {
    if (!_built || viewSize.isEmpty) return null;
    final ray = camera.screenPointToRay(screenPosition, viewSize);
    final hit = _scene.raycast(
      ray,
      where: (node) => node.name.endsWith(':mesh'),
    );
    if (hit == null) return null;
    Node? node = hit.node;
    while (node != null && node.parent != _builder.solarSystemRoot) {
      node = node.parent;
    }
    if (node == null) return null;
    for (final entry in _builder.states.entries) {
      if (identical(entry.value.node, node)) return entry.key;
    }
    return null;
  }

  @override
  void spinPlanet(String planetId, double delta) {
    final render = _builder.states[planetId];
    if (render == null) return;
    render.spinNode.rotation =
        render.spinNode.rotation *
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), delta);
  }

  @override
  void rotatePlanet(String planetId, double dx, double dy) =>
      _builder.rotatePlanet(planetId, dx, dy);

  @override
  void rotateSolarSystem(double dx, double dy) =>
      _builder.rotateSolarSystem(dx, dy);

  @override
  void setRotationVelocity({
    String? planetId,
    required double angularX,
    required double angularY,
  }) {
    _rotationVelocityPlanetId = planetId;
    _rotationVelocityX = angularX;
    _rotationVelocityY = angularY;
  }

  @override
  void orbitBy(double dx, double dy) => _rig.orbitBy(dx, dy);

  @override
  void pinch(double scale) => _rig.pinch(scale);

  @override
  double smoothPinchFactor(double rawIncrementalScale) =>
      _rig.smoothPinchFactor(rawIncrementalScale);

  @override
  void resetPinchSmoothing() => _rig.resetPinchSmoothing();

  @override
  void resetOverview() {
    _rig.cancelZoomFlight();
    _rig.resetOverview();
  }

  @override
  void setMaxTextureDecodeWidth(int? maxWidth) {
    final textures = _textures;
    if (textures is AssetTextureProvider) {
      textures.maxDecodeWidth = maxWidth;
    }
  }

  @override
  Future<void> warmUpPipelines(ExplorerState ui) async {
    if (_pipelinesWarmed) return;
    try {
      await _scene.warmUp([RenderView(camera: buildCamera(ui))]);
      _pipelinesWarmed = true;
    } catch (error) {
      // Optimization only: the startup gate already hides an unwarmed first
      // frame behind the intro, so a warm-up failure must never fail startup.
      developer.log(
        'scene.warmUp skipped; first frame compiles on demand: $error',
        name: 'startup',
      );
    }
  }

  @override
  vm.Vector3? bodyWorldPosition(String planetId) {
    final render = _builder.states[planetId];
    if (render == null) return null;
    return OrbitCameraRig.worldPositionOf(render);
  }

  @override
  double? bodyWorldRadius(String planetId) {
    final render = _builder.states[planetId];
    if (render == null) return null;
    return OrbitCameraRig.worldRadiusOf(render);
  }

  double _enterThreshold(String planetId) {
    final worldR = bodyWorldRadius(planetId);
    if (worldR == null) return double.infinity;
    return worldR * 7.0;
  }

  double _exitThreshold(String planetId) {
    final worldR = bodyWorldRadius(planetId);
    if (worldR == null) return double.infinity;
    return worldR * 12.0;
  }

  double _distanceToBody(String planetId, PerspectiveCamera camera) {
    final pos = bodyWorldPosition(planetId);
    if (pos == null) return double.infinity;
    return camera.position.distanceTo(pos);
  }

  @override
  String? pickPlanetForAutoFocus(
    Offset screenPosition,
    Size viewSize,
    PerspectiveCamera camera,
  ) {
    final picked = pickPlanet(screenPosition, viewSize, camera);
    if (picked == null) return null;
    final distance = _distanceToBody(picked, camera);
    if (distance <= _enterThreshold(picked)) return picked;
    return null;
  }

  @override
  double detailZoomForPlanetAtCameraDistance(
    String planetId,
    PerspectiveCamera camera,
  ) {
    final render = _builder.states[planetId];
    final worldR = bodyWorldRadius(planetId) ?? render?.radius ?? 1.0;
    final isSun = render?.isSun ?? false;
    final distance = _distanceToBody(planetId, camera);
    if (!distance.isFinite) return 1.0;
    final base = OrbitCameraRig.baseDistanceFor(
      worldRadius: worldR,
      isSun: isSun,
    );
    if (base <= 0) return 1.0;
    return math.max(0.001, distance / base);
  }

  @override
  bool shouldAutoReleaseFocus(String planetId, PerspectiveCamera camera) {
    final distance = _distanceToBody(planetId, camera);
    return distance >= _exitThreshold(planetId);
  }

  @override
  void pinchWithFocalPoint(
    double scale, {
    Offset? focalScreenPoint,
    Size? viewSize,
    PerspectiveCamera? camera,
  }) {
    vm.Vector3? focalWorld;
    if (focalScreenPoint != null && viewSize != null && camera != null) {
      final picked = pickPlanet(focalScreenPoint, viewSize, camera);
      if (picked != null) focalWorld = bodyWorldPosition(picked);
    }
    _rig.pinchToward(scale, focalWorldPoint: focalWorld);
  }

  @override
  double markZoomProgress(String planetId, PerspectiveCamera camera) {
    final worldR = bodyWorldRadius(planetId);
    if (worldR == null) return 0.0;
    return OrbitCameraRig.approachProgress(
      distance: _distanceToBody(planetId, camera),
      worldRadius: worldR,
    );
  }

  @override
  void pinchTowardBody(double scale, String planetId) {
    _rig.pinchToward(scale, focalWorldPoint: bodyWorldPosition(planetId));
  }

  @override
  bool shouldAutoEnterDetail(String planetId, PerspectiveCamera camera) {
    final distance = _distanceToBody(planetId, camera);
    return distance <= _enterThreshold(planetId);
  }

  @override
  Offset? projectBodyCenter(
    String planetId,
    PerspectiveCamera camera,
    Size viewSize,
  ) {
    if (viewSize.isEmpty) return null;
    final pos = bodyWorldPosition(planetId);
    if (pos == null) return null;
    return camera.worldToScreen(pos, viewSize);
  }

  @override
  double prepareSeamlessSelection(
    String planetId,
    PerspectiveCamera camera,
  ) {
    final render = _builder.states[planetId];
    final pos = bodyWorldPosition(planetId);
    if (render == null || pos == null) return 1.0;
    final worldR = OrbitCameraRig.worldRadiusOf(render);
    return _rig.snapToBodyPreservingEye(
      planetId: planetId,
      bodyPos: pos,
      worldRadius: worldR,
      isSun: render.isSun,
      eye: camera.position.clone(),
    );
  }

  @override
  bool get zoomFlightActive => _rig.zoomFlightActive;

  @override
  void startZoomToDetail(String planetId, PerspectiveCamera camera) {
    final render = _builder.states[planetId];
    if (render == null) return;
    _rig.beginZoomToBody(
      worldRadius: OrbitCameraRig.worldRadiusOf(render),
      eye: camera.position.clone(),
    );
  }

  @override
  void cancelZoomFlight() => _rig.cancelZoomFlight();

  @override
  ({bool done, double progress}) stepZoomFlight(
    double deltaSeconds,
    String planetId,
  ) {
    final pos = bodyWorldPosition(planetId);
    if (pos == null) {
      _rig.cancelZoomFlight();
      return (done: true, progress: 0.0);
    }
    return _rig.stepZoomFlight(deltaSeconds: deltaSeconds, bodyPos: pos);
  }

  @override
  void preserveReleaseEye(PerspectiveCamera camera) {
    // Freeze the eye AND restore the stable system anchor, so the next
    // free gesture orbits the solar system rather than the ex-body.
    _rig.reanchorPreservingEye(camera.position.clone());
  }

  @override
  void dispose() {
    _rotationVelocityX = 0.0;
    _rotationVelocityY = 0.0;
    _animator?.detach();
    _textures.dispose();
    _geometries.dispose();
  }

  /// Test-only hook: registers a bare transform node so distance/threshold
  /// math can be exercised without a GPU or texture decode.
  @visibleForTesting
  void debugRegisterBody({
    required String id,
    required vm.Vector3 position,
    required double radius,
    required bool isSun,
  }) {
    final node = Node(name: id)..position = position.clone();
    final spin = Node(name: '$id:spin');
    node.add(spin);
    _builder.states[id] = PlanetRenderState(
      id: id,
      node: node,
      spinNode: spin,
      radius: radius,
      isSun: isSun,
    );
  }
}
