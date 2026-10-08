/// Temporary TV input probe — removed from the production Explorer stack.
///
/// Kept as a stub so stale imports fail loudly at the symbol rather than
/// silently rebuilding a focus-stealing overlay. Do not reintroduce into
/// [ExplorerScreen]; use `adb logcat` + `TvRemoteHandler` debug prints for
/// hardware diagnosis instead.
library;

/// Always false: the probe must never mount in a shipping build.
bool get showTvProbe => false;
