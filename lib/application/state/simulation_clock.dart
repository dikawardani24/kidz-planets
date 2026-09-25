import 'dart:async';

/// Frame-rate independent simulation clock (SRP: only tracks time).
///
/// The imperative 3D scene polls [elapsedSeconds] every frame; the UI
/// layer only calls [pause]/[resume]/[setSpeed].
class SimulationClock {
  SimulationClock();

  final _tickController = StreamController<double>.broadcast();
  Stream<double> get ticks => _tickController.stream;

  bool _running = true;
  bool get running => _running;

  double _speed = 1.0;
  double get speed => _speed;

  double _elapsedSeconds = 0.0;
  double get elapsedSeconds => _elapsedSeconds;


  /// Advances the clock; called from the SceneView `onTick` callback.
  void tick(double deltaSeconds) {
    if (!_running) return;
    final scaled = deltaSeconds * _speed;
    _elapsedSeconds += scaled;
    if (!_tickController.isClosed) _tickController.add(_elapsedSeconds);
  }

  void pause() => _running = false;
  void resume() {
    _running = true;
  }

  void setSpeed(double value) => _speed = value.clamp(0.0, 8.0);

  void dispose() => _tickController.close();
}
