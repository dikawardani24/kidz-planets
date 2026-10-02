/// The mission feature: the curriculum a child works through and the UI that
/// guides them.
///
/// This package may import `core` and third-party packages. It must not import
/// `planets`, `moon` or `avatar`. A mission names its target by planet id, so
/// the guide can say "find Earth" without ever holding a planet, and the avatar
/// is driven through mood that the application package maps from mission
/// outcomes.
library;

export 'data.dart';
export 'domain.dart';
export 'state.dart';
export 'widgets.dart';
