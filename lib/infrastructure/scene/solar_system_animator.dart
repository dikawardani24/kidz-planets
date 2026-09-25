import 'dart:async';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import '../../../application/state/simulation_clock.dart';
import '../../../domain/entities/planet.dart';
import 'solar_system_scene_builder.dart';

/// Per-frame simulation driver (SRP: animation math only, OCP: new motion
/// only touches this class).
///
/// Reads [SimulationClock.elapsedSeconds] each tick and writes node
/// transforms directly — no widget rebuilds involved.
class SolarSystemAnimator {
  SolarSystemAnimator({
    required SimulationClock clock,
    required SolarSystemSceneBuilder builder,
    required List<Planet> planets,
  })  : _clock = clock,
        _builder = builder,
        _planets = {for (final p in planets) p.id: p};

  final SimulationClock _clock;
  final SolarSystemSceneBuilder _builder;
  final Map<String, Planet> _planets;

  StreamSubscription<double>? _subscription;

  double _spinBoost = 0.0;

  /// Extra spin velocity from finger swipes in detail mode.
  void addSpinBoost(double amount) {
    _spinBoost = (_spinBoost + amount).clamp(-0.2, 0.2);
  }

  void attach() {
    _subscription ??= _clock.ticks.listen((_) {});
  }

  /// Advances positions for one rendered frame. Called from
  /// `SceneView.onTick` via the controller (keeps widgets dumb).
  void tick(double deltaSeconds) {
    if (_builder.states.isEmpty) return;
    final t = _clock.elapsedSeconds;
    _spinBoost *= 0.95;

    for (final entry in _builder.states.entries) {
      final planet = _planets[entry.key];
      if (planet == null) continue;
      final state = entry.value;
      if (!planet.isSun && planet.orbitRadius > 0) {
        final angle = planet.startAngle + t * planet.orbitSpeed;
        state.node.position = vm.Vector3(
          math.cos(angle) * planet.orbitRadius,
          0,
          math.sin(angle) * planet.orbitRadius,
        );
      }
      // Self-spin: slow ambient + finger momentum.
      final baseSpin = planet.isSun ? 0.02 : 0.12;
      final spin = (baseSpin + _spinBoost) * deltaSeconds;
      state.spinNode.rotation =
          state.spinNode.rotation * vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            spin,
          );
    }
  }

  void detach() {
    _subscription?.cancel();
    _subscription = null;
  }
}
