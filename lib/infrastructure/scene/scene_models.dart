import 'package:flutter_scene/scene.dart';

/// Mutable per-planet render state shared between the scene graph and
/// the label overlay (SRP: plain data holder, no behaviour).
class PlanetRenderState {
  PlanetRenderState({
    required this.id,
    required this.node,
    required this.spinNode,
  });

  final String id;
  final Node node;
  final Node spinNode;
}

/// Read model for one floating label frame.
class PlanetLabelFrame {
  const PlanetLabelFrame({
    required this.id,
    required this.screenX,
    required this.screenY,
    required this.worldDepth,
    required this.visible,
  });

  final String id;
  final double screenX;
  final double screenY;
  final double worldDepth;
  final bool visible;
}

/// Camera rig state shared between widgets and the scene controller.
class CameraRigState {
  CameraRigState();

  double theta = 0.0;
  double phi = 0.32;
  double radius = 46.0;
  double targetX = 0.0;
  double targetY = 0.0;
  double targetZ = 0.0;
  double fovRadians = 0.85;
}
