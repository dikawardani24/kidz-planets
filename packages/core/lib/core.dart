/// Shared infrastructure for the Planetaria workspace.
///
/// Core owns localization, theme, audio abstractions, the simulation clock and
/// the startup contract: the things more than one feature package genuinely
/// needs. It must never
/// depend on a feature package (`planets`, `moon`, `avatar`, `mission`) and it
/// must never hold feature business logic. If something here would only ever be
/// used by one feature, it belongs in that feature package.
///
/// The dependency direction is:
///
///   features -> core
///   app -> features, core
library;

export 'audio.dart';
export 'layout.dart';
export 'l10n.dart';
export 'platform.dart';
export 'startup.dart';
export 'theme.dart';
export 'time.dart';
