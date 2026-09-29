import 'package:equatable/equatable.dart';

/// A message the application layer wants shown, without deciding how it reads
/// in any language.
///
/// The controller and the state are deliberately free of `AppLocalizations`:
/// they are the domain and application layers, and importing a generated
/// presentation class into them would make every message a breaking change
/// whenever copy is reworded. So a message travels as an id plus arguments and
/// is resolved at the widget, where the active locale is actually known.
///
/// Ids are matched by [AppMessageId], an enum, so a typo is a compile error
/// rather than a raw key on screen.
enum AppMessageId {
  alertSandboxTitle,
  alertSandboxDescription,
  alertEarthTitle,
  alertEarthDescription,
  alertSaturnTitle,
  alertSaturnDescription,
  alertJupiterTitle,
  alertJupiterDescription,
  alertSunTitle,
  alertSunDescription,
  toastMissionComplete,
  toastMissionVerified,
  toastSandboxReady,
  celebrationMissionTitle,
  celebrationDiscovered,
}

class AppMessage extends Equatable {
  const AppMessage(this.id, [this.args = const {}]);

  final AppMessageId id;

  /// Values substituted into the localized template, keyed by placeholder
  /// name: `id`, `title`, `target`.
  final Map<String, Object?> args;

  @override
  List<Object?> get props => [id, args];
}
