/// Shared infrastructure for the Kidz Planets workspace.
///
/// Core owns localization, theme, audio and utility abstractions that more than
/// one feature needs. It must never depend on a feature package, and it must
/// never hold feature business logic: if something here would only ever be
/// used by the avatar, it belongs in the avatar package.
library;
