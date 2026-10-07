import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:planets/domain.dart';

import 'scene_factories.dart';
import 'scene_models.dart';
import 'texture_provider.dart';

/// Device-profiling isolation switches. All false in production builds.
///
/// Set via `--dart-define` to attribute frame/loading cost on hardware, e.g.
/// `flutter run --profile --dart-define=KIDZ_NO_RINGS=true`. There is no
/// runtime UI and no performance effect when unset (constant-folded).
/// Recipe: baseline → `KIDZ_NO_TEXTURES` (decode/upload cost) →
/// `KIDZ_NO_RINGS` (84 Saturn nodes) → `KIDZ_NO_ORBITS` (8 rings) and compare
/// `scene.build` stats lines plus DevTools frame times. `KIDZ_NO_TEXTURES`
/// exercises the production flat-tint fallback materials, not a test stub.
const kSceneNoTextures = bool.fromEnvironment('KIDZ_NO_TEXTURES');
const kSceneNoRings = bool.fromEnvironment('KIDZ_NO_RINGS');
const kSceneNoOrbits = bool.fromEnvironment('KIDZ_NO_ORBITS');

/// Builds and owns the imperative flutter_scene graph (SRP: scene only).
///
/// Uses [Texture2D.fromAsset] via [TextureProvider] so no build hook /
/// `.fstex` pipeline is needed. Planets are textured PBR spheres lit by
/// the default studio environment; orbits are flat translucent rings;
/// the starfield is an inside-out textured dome.
class SolarSystemSceneBuilder {
  SolarSystemSceneBuilder({
    required this._textures,
    required this._geometries,
    required this._materials,
  });

  final TextureProvider _textures;
  final GeometryFactory _geometries;
  final PlanetMaterialFactory _materials;

  final Map<String, PlanetRenderState> states = {};

  /// Whether [buildMoons] has finished, so a second call is a no-op.
  bool _moonsBuilt = false;

  /// Whether the solar-system root has already been attached to the scene.
  ///
  /// Lets a failed [build] resume without calling [Scene.add] twice.
  bool _rootAttached = false;

  /// Whether [buildMoons] has finished successfully.
  bool get moonsBuilt => _moonsBuilt;

  final Map<String, Node> orbitNodes = {};
  Node? starNode;
  final Node solarSystemRoot = Node(name: 'solar-system-root');

  /// Renderable nodes created for Saturn's ring system (one combined ring mesh
  /// plus three physical edge profiles). Logged in the build stats line so
  /// device profiling can correlate node count with frame time.
  int ringNodeCount = 0;

  /// Builds the Sun, the starfield and the planets; awaits every texture upload.
  ///
  /// Moons are *not* built here. They are eighteen more textures and about
  /// 2.4MB of decoding for bodies a child cannot see until they zoom into a
  /// planet, and a child staring at a progress bar does not need them. They go
  /// through [buildMoons] instead, which runs after the app is already
  /// interactive. Nothing has to be rearranged for that: the animator recomputes
  /// every body's orbit position from the clock on each frame, so a moon built
  /// later lands where it would have landed anyway.
  ///
  /// [onProgress] receives a `0..1` fraction and a label, because a loading
  /// screen that only knows it is "loading" is the thing this whole exercise is
  /// trying to get rid of.
  Future<void> build({
    required Scene scene,
    required List<Planet> planets,
    required void Function(double fraction, String label) onProgress,
  }) async {
    // Match the prototype's space lighting: the Sun is the primary light
    // source, while only a small amount of ambient IBL keeps the shadow side
    // from becoming completely black.
    scene.environmentIntensity = 0.14;
    // All celestial bodies and their orbit paths live under one transform root.
    // Rotating this root is equivalent to physically turning the whole model.
    // Resume-safe: a failed build must not attach the root a second time.
    if (!_rootAttached) {
      scene.add(solarSystemRoot);
      _buildSunLight(scene);
      _rootAttached = true;
    }

    final primaryBodies = planets.where((p) => !p.isMoon).toList();

    // One step for the starfield plus one per body. Stepping through a
    // precomputed count rather than counting as we go is what keeps the
    // denominator honest: the bar's last notch is the last body, not a guess
    // made halfway through.
    final steps = primaryBodies.length + 1;
    var step = 0;

    onProgress(step / steps, 'Painting stars…');
    if (starNode == null) {
      final starsSw = Stopwatch()..start();
      developer.log('scene.build: stars started', name: 'startup');
      await _buildStars(scene);
      developer.log(
        'scene.build: stars completed in ${starsSw.elapsedMilliseconds}ms',
        name: 'startup',
      );
      // Let Flutter present the loading animation before the first expensive
      // planet/material batch starts.
      await _yieldToUi();
    }
    step++;

    for (final planet in primaryBodies) {
      onProgress(step / steps, 'Painting ${planet.name}…');
      if (!states.containsKey(planet.id)) {
        final bodySw = Stopwatch()..start();
        developer.log(
          'scene.build: ${planet.id} started',
          name: 'startup',
        );
        await _buildPlanet(planet);
        if (planet.hasRing && !kSceneNoRings) {
          await _buildSaturnRing(planet);
        }
        if (!planet.isSun &&
            !kSceneNoOrbits &&
            !orbitNodes.containsKey(planet.id)) {
          _buildOrbit(scene, planet);
        }
        developer.log(
          'scene.build: ${planet.id} completed '
          'in ${bodySw.elapsedMilliseconds}ms',
          name: 'startup',
        );
        // Build one body per event-loop turn so progress UI and the renderer
        // can run between texture/mesh/material batches.
        await _yieldToUi();
      }
      step++;
    }
    developer.log(
      'scene.build: primary bodies ready '
      '(bodies=${states.length} ringNodes=$ringNodeCount '
      'orbits=${orbitNodes.length} textures=${_textures.cachedCount} '
      'geometries=${_geometries.describeCache()})',
      name: 'startup',
    );
  }

  /// Adds the moons to a scene that [build] has already started.
  ///
  /// Idempotent: calling it twice adds nothing twice, so a retry or a second
  /// lazy warm cannot end up with two of every moon stacked on the same orbit.
  Future<void> buildMoons({
    required List<Planet> moons,
    required void Function(double fraction, String label) onProgress,
  }) async {
    if (_moonsBuilt) return;
    final pending = moons.where((m) => !states.containsKey(m.id)).toList();
    if (pending.isEmpty) {
      _moonsBuilt = true;
      return;
    }

    final steps = pending.length;
    final moonsSw = Stopwatch()..start();
    for (var i = 0; i < pending.length; i++) {
      final moon = pending[i];
      onProgress(i / steps, 'Painting ${moon.name}…');
      await _buildPlanet(moon);
      // Keep lazy moon loading responsive as each additional texture/mesh
      // is added after the main scene is already interactive.
      await _yieldToUi();
    }
    _moonsBuilt = true;
    onProgress(1.0, 'Moons ready');
    developer.log(
      'scene.build: moons ready '
      '(moons=${pending.length} in ${moonsSw.elapsedMilliseconds}ms '
      'textures=${_textures.cachedCount})',
      name: 'startup',
    );
  }

  void _buildSunLight(Scene scene) {
    // The planets orbit around world origin, so a point light at the Sun gives
    // every planet a physically meaningful day/night side as it moves around
    // the system. Unlike a directional light, the illumination direction
    // changes naturally with each planet's position.
    final sunLight = Node(name: 'sun:light')
      ..addComponent(
        PointLightComponent(
          PointLight(
            color: vm.Vector3(1.0, 0.86, 0.62),
            intensity: 20.0,
            range: 80.0,
            falloffExponent: 1.0,
          ),
        ),
      );
    scene.add(sunLight);
  }

  Future<void> _buildStars(Scene scene) async {
    final texture = await _safeLoad('assets/textures/stars.jpg');
    final node = Node(
      mesh: Mesh(_geometries.starDome, _materials.starDome(texture: texture)),
    )..name = 'stars';
    node.raycastable = false;
    scene.add(node);
    starNode = node;
  }

  /// Adds one body under [solarSystemRoot].
  ///
  /// No [Scene] parameter: every celestial body hangs off the one transform
  /// root, which is what lets [buildMoons] add moons long after [build] has
  /// returned and the scene is already on screen.
  Future<void> _buildPlanet(Planet planet) async {
    final texture = await _safeLoad(planet.textureAsset);

    final spinNode = Node()..name = '${planet.id}:spin';
    spinNode.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      _degreesToRadians(planet.tiltDegrees) * 0.15,
    );

    final mesh = planet.isSun
        ? Mesh(
            _geometries.sphere(planet.radius),
            _materials.sun(texture: texture),
          )
        : Mesh(
            _geometries.sphere(planet.radius),
            _materials.planet(
              texture: texture,
              fallback: Color(planet.colorValue),
            ),
          );
    spinNode.add(Node(mesh: mesh)..name = '${planet.id}:mesh');

    final orbitNode = Node()..name = '${planet.id}:orbit';
    final angle = planet.startAngle;
    final parent = planet.parentPlanetId == null
        ? null
        : states[planet.parentPlanetId!];
    final parentPosition = parent?.node.position ?? vm.Vector3.zero();
    orbitNode.position = vm.Vector3(
      parentPosition.x + math.cos(angle) * planet.orbitRadius,
      parentPosition.y,
      parentPosition.z + math.sin(angle) * planet.orbitRadius,
    );
    orbitNode.add(spinNode);
    solarSystemRoot.add(orbitNode);

    states[planet.id] = PlanetRenderState(
      id: planet.id,
      node: orbitNode,
      spinNode: spinNode,
      radius: planet.radius,
      isSun: planet.isSun,
    );
  }

  Future<void> _buildSaturnRing(Planet planet) async {
    final state = states[planet.id];
    if (state == null) return;

    final tilt = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      _degreesToRadians(planet.tiltDegrees),
    );

    // Keep Saturn visually rich without paying one scene node/draw/material
    // submission for every ringlet. The broad bands, fine strands and their
    // grazing-angle support planes are packed into one immutable mesh with
    // per-vertex opacity. Only the three genuinely 3D edge profiles remain
    // separate because they provide physical thickness at exact edge-on views.
    final combined = Node(
      mesh: Mesh(
        _geometries.saturnRingSystem(planet.radius),
        _materials.saturnCombinedRing(),
      ),
    )
      ..name = '${planet.id}:ring:combined'
      ..rotation = tilt;
    combined.raycastable = false;
    state.spinNode.add(combined);
    ringNodeCount++;

    const edgeProfiles = <({double radius, double tube, double opacity})>[
      (radius: 1.40, tube: 0.020, opacity: 0.34),
      (radius: 1.78, tube: 0.022, opacity: 0.42),
      (radius: 2.17, tube: 0.018, opacity: 0.34),
    ];

    for (var i = 0; i < edgeProfiles.length; i++) {
      final edge = edgeProfiles[i];
      final ring = Node(
        mesh: Mesh(
          _geometries.saturnEdgeRing(
            planet.radius * edge.radius,
            planet.radius * edge.tube,
          ),
          _materials.saturnRing(opacity: edge.opacity),
        ),
      )
        ..name = '${planet.id}:ring:edge:$i'
        ..rotation = tilt;
      ring.raycastable = false;
      state.spinNode.add(ring);
      ringNodeCount++;
    }

    await _yieldToUi();
  }
  void _buildOrbit(Scene scene, Planet planet) {
    final node =
        Node(
            mesh: Mesh(
              _geometries.orbitRing(planet.orbitRadius),
              _materials.orbitPath(const Color(0xFF8EA2FF)),
            ),
          )
          ..name = '${planet.id}:path'
          ..position = vm.Vector3(0, -0.02, 0);
    node.raycastable = false;
    solarSystemRoot.add(node);
    orbitNodes[planet.id] = node;
  }

  void setPlanetOrbitRadius(String planetId, double radius) {
    final state = states[planetId];
    if (state == null) return;
    final angle = state.node.position.z == 0 && state.node.position.x == 0
        ? 0.0
        : math.atan2(state.node.position.z, state.node.position.x);
    state.node.position = vm.Vector3(
      math.cos(angle) * radius,
      0,
      math.sin(angle) * radius,
    );
  }

  void rotateSolarSystem(double dx, double dy) {
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 0.001) return;
    final axis = vm.Vector3(dy, dx, 0)..normalize();
    final angle = length * 0.009;
    solarSystemRoot.rotation =
        solarSystemRoot.rotation * vm.Quaternion.axisAngle(axis, angle);
  }

  void rotatePlanet(String planetId, double dx, double dy) {
    final state = states[planetId];
    if (state == null) return;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 0.001) return;
    final axis = vm.Vector3(dy, dx, 0)..normalize();
    final angle = length * 0.009;
    // Post-multiplication applies the gesture in the planet's local frame.
    // Once the globe flips, its local Z/X axes have flipped with it, so
    // vertical dragging can continue past the poles indefinitely.
    state.spinNode.rotation =
        state.spinNode.rotation * vm.Quaternion.axisAngle(axis, angle);
  }

  void rotatePlanetAngularVelocity(
    String planetId,
    double angularX,
    double angularY,
    double deltaSeconds,
  ) {
    final state = states[planetId];
    if (state == null) return;
    final dx = angularX * deltaSeconds / 0.009;
    final dy = angularY * deltaSeconds / 0.009;
    rotatePlanet(planetId, dx, dy);
  }

  void rotateSolarSystemAngularVelocity(
    double angularX,
    double angularY,
    double deltaSeconds,
  ) {
    final dx = angularX * deltaSeconds / 0.009;
    final dy = angularY * deltaSeconds / 0.009;
    rotateSolarSystem(dx, dy);
  }

  void setOrbitsVisible(bool visible) {
    for (final node in orbitNodes.values) {
      node.visible = visible;
    }
  }

  Future<void> _yieldToUi() => Future<void>.delayed(Duration.zero);

  Future<TextureSource?> _safeLoad(String asset) async {
    // Profiling isolation: exercise the flat-tint fallback materials.
    if (kSceneNoTextures) return null;
    try {
      return await _textures.get(asset);
    } catch (_) {
      return null;
    }
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
}
