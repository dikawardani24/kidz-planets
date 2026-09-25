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
    required TextureProvider textures,
    required GeometryFactory geometries,
    required PlanetMaterialFactory materials,
  })  : _textures = textures,
        _geometries = geometries,
        _materials = materials;

  final TextureProvider _textures;
  final GeometryFactory _geometries;
  final PlanetMaterialFactory _materials;

  final Map<String, PlanetRenderState> states = {};
  final Map<String, Node> orbitNodes = {};
  Node? starNode;

  /// Builds the full graph under [scene]; awaits all texture uploads.
  Future<void> build({
    required Scene scene,
    required List<Planet> planets,
    required void Function(String label) onProgress,
  }) async {
    onProgress('Painting stars…');
    await _buildStars(scene);
    final total = planets.length;
    for (var i = 0; i < total; i++) {
      final planet = planets[i];
      onProgress('Painting ${planet.name}…');
      await _buildPlanet(scene, planet);
      if (planet.hasRing) {
        await _buildSaturnRing(planet);
      }
      if (!planet.isSun) {
        _buildOrbit(scene, planet);
      }
    }
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
    orbitNode.position = vm.Vector3(
      math.cos(angle) * planet.orbitRadius,
      0,
      math.sin(angle) * planet.orbitRadius,
    );
    orbitNode.add(spinNode);
    scene.add(orbitNode);

    states[planet.id] = PlanetRenderState(
      id: planet.id,
      node: orbitNode,
      spinNode: spinNode,
    );
  }

  Future<void> _buildSaturnRing(Planet planet) async {
    final state = states[planet.id];
    if (state == null) return;
    final texture = await _safeLoad(planet.ringTextureAsset!);
    final ring = Node(
      mesh: Mesh(
        _geometries.saturnBand(
          planet.radius * planet.ringInnerFactor,
          planet.radius * planet.ringOuterFactor,
        ),
        _materials.saturnRing(texture: texture),
      ),
    )
      ..name = '${planet.id}:ring'
      ..rotation = vm.Quaternion.axisAngle(
        vm.Vector3(1, 0, 0),
        _degreesToRadians(planet.tiltDegrees),
      );
    ring.raycastable = false;
    // Slight lift so the band never z-fights the globe.
    ring.position = vm.Vector3(0, 0.01, 0);
    state.spinNode.add(ring);
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
    scene.add(node);
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
