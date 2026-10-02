/// The startup contract: what has to be true before the solar system is worth
/// showing, and how progress is reported while it becomes true.
///
/// This lives in `core` because every feature contributes a task to it and the
/// app is the only thing that composes them. Putting the vocabulary here means a
/// feature package can be loaded and warmed without the app, and a test can run
/// the pipeline without a solar system.
library;

export 'src/startup/startup_coordinator.dart';
export 'src/startup/startup_message.dart';
export 'src/startup/startup_progress.dart';
export 'src/startup/startup_status.dart';
export 'src/startup/startup_task.dart';