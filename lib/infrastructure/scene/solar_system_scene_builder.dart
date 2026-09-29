import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../../domain/entities/planet.dart';
import 'scene_factories.dart';
import 'scene_models.dart';
import 'texture_provider.dart';

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
  final Map<String, Node> orbitNodes = {};
  Node? starNode;
  final Node solarSystemRoot = Node(name: 'solar-system-root');

  /// Builds the full graph under [scene]; awaits all texture uploads.
  Future<void> build({
    required Scene scene,
    required List<Planet> planets,
    required void Function(String label) onProgress,
  }) async {
    // Match the prototype's space lighting: the Sun is the primary light
    // source, while only a small amount of ambient IBL keeps the shadow side
    // from becoming completely black.
    scene.environmentIntensity = 0.14;
    // All celestial bodies and their orbit paths live under one transform root.
    // Rotating this root is equivalent to physically turning the whole model.
    scene.add(solarSystemRoot);
    _buildSunLight(scene);

    onProgress('Painting stars…');
    await _buildStars(scene);
    final primaryBodies = planets.where((p) => !p.isMoon).toList();
    final moons = planets.where((p) => p.isMoon).toList();

    for (final planet in primaryBodies) {
      onProgress('Painting ${planet.name}…');
      await _buildPlanet(scene, planet);
      if (planet.hasRing) {
        await _buildSaturnRing(planet);
      }
      if (!planet.isSun) {
        _buildOrbit(scene, planet);
      }
    }

    for (final moon in moons) {
      onProgress('Painting ${moon.name}…');
      await _buildPlanet(scene, moon);
    }
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
      mesh: Mesh(
        _geometries.starDome,
        _materials.starDome(texture: texture),
      ),
    )..name = 'stars';
    node.raycastable = false;
    scene.add(node);
    starNode = node;
  }

  Future<void> _buildPlanet(Scene scene, Planet planet) async {
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
    final parent =
        planet.parentPlanetId == null ? null : states[planet.parentPlanetId!];
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

    // NASA's Cassini images show Saturn's rings as thousands of fine
    // ringlets, not six thick colored hoops. Build a low-cost approximation:
    // broad translucent ring regions underneath many very thin strands.
    final broad = <({String id, double inner, double outer, double opacity})>[
      (id: 'c', inner: 1.22, outer: 1.53, opacity: 0.16),
      (id: 'b', inner: 1.54, outer: 1.96, opacity: 0.28),
      (id: 'a', inner: 2.03, outer: 2.28, opacity: 0.20),
    ];

    void addRingLayer({
      required String name,
      required double inner,
      required double outer,
      required double opacity,
      required vm.Quaternion rotation,
    }) {
      final ring = Node(
        mesh: Mesh(
          _geometries.saturnBand(inner, outer),
          _materials.saturnRing(opacity: opacity),
        ),
      )
        ..name = name
        ..rotation = rotation;
      ring.raycastable = false;
      state.spinNode.add(ring);
    }

    for (final band in broad) {
      final inner = planet.radius * band.inner;
      final outer = planet.radius * band.outer;

      addRingLayer(
        name: '${planet.id}:ring:base:${band.id}',
        inner: inner,
        outer: outer,
        opacity: band.opacity,
        rotation: tilt,
      );

      // RingGeometry is an infinitely thin plane. At an almost edge-on
      // viewing angle its projected area can collapse to zero pixels and
      // the ring appears to vanish. Two very subtle support layers keep a
      // readable edge without changing the visible ring thickness at normal
      // viewing angles.
      const edgeAngle = 0.022;
      addRingLayer(
        name: '${planet.id}:ring:edge:+:${band.id}',
        inner: inner,
        outer: outer,
        opacity: band.opacity * 0.18,
        rotation: tilt *
            vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), edgeAngle),
      );
      addRingLayer(
        name: '${planet.id}:ring:edge:-:${band.id}',
        inner: inner,
        outer: outer,
        opacity: band.opacity * 0.18,
        rotation: tilt *
            vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -edgeAngle),
      );
    }

    // Fine structure: irregular spacing and opacity makes the ring read as
    // particle-rich ice instead of a handful of perfect flat hoops.
    const strands = <({double radius, double width, double opacity})>[
      (radius: 1.255, width: 0.010, opacity: 0.18),
      (radius: 1.285, width: 0.006, opacity: 0.32),
      (radius: 1.335, width: 0.012, opacity: 0.20),
      (radius: 1.375, width: 0.006, opacity: 0.34),
      (radius: 1.415, width: 0.009, opacity: 0.22),
      (radius: 1.465, width: 0.014, opacity: 0.30),
      (radius: 1.515, width: 0.008, opacity: 0.26),
      (radius: 1.575, width: 0.012, opacity: 0.42),
      (radius: 1.625, width: 0.007, opacity: 0.26),
      (radius: 1.685, width: 0.015, opacity: 0.48),
      (radius: 1.755, width: 0.009, opacity: 0.30),
      (radius: 1.825, width: 0.018, opacity: 0.54),
      (radius: 1.885, width: 0.010, opacity: 0.34),
      // Cassini Division: deliberately no geometry from ~1.96 to ~2.03.
      (radius: 2.045, width: 0.008, opacity: 0.28),
      (radius: 2.085, width: 0.012, opacity: 0.42),
      (radius: 2.135, width: 0.007, opacity: 0.30),
      (radius: 2.185, width: 0.015, opacity: 0.46),
      (radius: 2.235, width: 0.009, opacity: 0.30),
      (radius: 2.275, width: 0.006, opacity: 0.18),
      // F ring and faint outer material.
      (radius: 2.335, width: 0.012, opacity: 0.38),
      (radius: 2.352, width: 0.004, opacity: 0.52),
      (radius: 2.405, width: 0.004, opacity: 0.10),
      (radius: 2.445, width: 0.006, opacity: 0.07),
    ];

    for (var i = 0; i < strands.length; i++) {
      final strand = strands[i];
      final inner = planet.radius * (strand.radius - strand.width / 2);
      final outer = planet.radius * (strand.radius + strand.width / 2);

      addRingLayer(
        name: '${planet.id}:ring:strand:$i',
        inner: inner,
        outer: outer,
        opacity: strand.opacity,
        rotation: tilt,
      );

      // Keep the finest ringlets visible at extreme angles too. These are
      // intentionally much fainter than the real strand so they read as an
      // optical edge rather than as a second set of rings.
      const edgeAngle = 0.022;
      addRingLayer(
        name: '${planet.id}:ring:strand:edge:+:$i',
        inner: inner,
        outer: outer,
        opacity: strand.opacity * 0.18,
        rotation: tilt *
            vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), edgeAngle),
      );
      addRingLayer(
        name: '${planet.id}:ring:strand:edge:-:$i',
        inner: inner,
        outer: outer,
        opacity: strand.opacity * 0.18,
        rotation: tilt *
            vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -edgeAngle),
      );
    }

    // Flat bands have zero projected area at an exact edge-on angle.
    // Keep three very thin physical edge profiles so the ring system
    // remains visible instead of snapping completely out of sight.
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
    }

  }
  void _buildOrbit(Scene scene, Planet planet) {
    final node = Node(
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
    state.node.position = vm.Vector3(math.cos(angle) * radius, 0, math.sin(angle) * radius);
  }

  void rotateSolarSystem(double dx, double dy) {
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 0.001) return;
    final axis = vm.Vector3(dy, dx, 0)..normalize();
    final angle = length * 0.009;
    solarSystemRoot.rotation = solarSystemRoot.rotation *
        vm.Quaternion.axisAngle(axis, angle);
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
    state.spinNode.rotation = state.spinNode.rotation *
        vm.Quaternion.axisAngle(axis, angle);
  }

  void rotatePlanetAngularVelocity(String planetId, double angularX, double angularY, double deltaSeconds) {
    final state = states[planetId];
    if (state == null) return;
    final dx = angularX * deltaSeconds / 0.009;
    final dy = angularY * deltaSeconds / 0.009;
    rotatePlanet(planetId, dx, dy);
  }

  void rotateSolarSystemAngularVelocity(double angularX, double angularY, double deltaSeconds) {
    final dx = angularX * deltaSeconds / 0.009;
    final dy = angularY * deltaSeconds / 0.009;
    rotateSolarSystem(dx, dy);
  }

  void setOrbitsVisible(bool visible) {
    for (final node in orbitNodes.values) {
      node.visible = visible;
    }
  }

  Future<TextureSource?> _safeLoad(String asset) async {
    try {
      return await _textures.get(asset);
    } catch (_) {
      return null;
    }
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
}
