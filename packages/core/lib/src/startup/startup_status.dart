/// Where the startup pipeline is in its lifecycle.
///
/// Deliberately four states and no more. A child is either being kept busy,
/// being let into the solar system, or being told that it could not be
/// prepared; anything finer is a progress value, not a status.
enum StartupStatus {
  /// Nothing has been started yet. The very first frame of the app.
  idle,

  /// At least one task is running.
  loading,

  /// Every required task finished. The app is safe to explore.
  ready,

  /// A required task failed and startup cannot continue without a retry.
  failed,
}

/// How badly a startup task is needed before the app is usable.
enum StartupCriticality {
  /// The app cannot be explored without this, so its failure stops startup.
  required,

  /// Nice to have already. Its failure is remembered and retried later
  /// instead of being shown to a child as a broken screen.
  lazy,
}
