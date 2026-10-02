/// The planets feature: the solar-system catalogue, the 3D scene that renders
/// it, and the panels a child browses it through.
///
/// This package may import `core` and third-party packages. It must not import
/// `moon`, `avatar` or `mission`: features stay independent and the application
/// package composes them. Moons in particular are read straight off the bodies
/// in this catalogue rather than through a second, parallel model.
library;

export 'audio.dart';
export 'data.dart';
export 'domain.dart';
export 'scene.dart';
export 'state.dart';
export 'widgets.dart';
