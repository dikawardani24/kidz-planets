/// The avatar feature: the mission companion that reacts to what the child
/// does, in 3D and in sound.
///
/// This package may import `core` and third-party packages. It must not import
/// `planets`, `moon` or `mission`. What the avatar reacts to is expressed as an
/// [AvatarMood] that the application package decides, so the avatar never has
/// to know what a mission is.
library;

export 'audio.dart';
export 'controllers.dart';
export 'scene.dart';
export 'state.dart';
export 'widgets.dart';
