import 'package:core/l10n.dart';
import 'package:core/startup.dart';

/// Localized phase line above the bar for a typed progress message.
String introPhaseFor(StartupMessage message, AppLocalizations t) =>
    switch (message) {
      StartupMessage.preparing => t.introPhasePreparing,
      StartupMessage.solarSystem => t.introPhaseSolarSystem,
      StartupMessage.sun => t.introPhaseSun,
      StartupMessage.planets => t.introPhasePlanets,
      StartupMessage.moons => t.introPhaseMoons,
      StartupMessage.companion => t.introPhaseCompanion,
      StartupMessage.missions => t.introPhaseMissions,
      StartupMessage.sounds => t.introPhaseSounds,
      StartupMessage.ready => t.introPhaseReady,
    };

/// Quoted line inside the message card for a typed progress message.
String introMessageFor(StartupMessage message, AppLocalizations t) =>
    switch (message) {
      StartupMessage.preparing => t.introPhasePreparing,
      StartupMessage.solarSystem => t.introPhaseSolarSystem,
      StartupMessage.sun => t.introPhaseSun,
      StartupMessage.planets => t.introPhasePlanets,
      StartupMessage.moons => t.introPhaseMoons,
      StartupMessage.companion => t.introPhaseCompanion,
      StartupMessage.missions => t.introPhaseMissions,
      StartupMessage.sounds => t.introPhaseSounds,
      StartupMessage.ready => t.introCompleteTitle,
    };

/// The small caption under the intro title (the prototype's
/// `loading-subtitle`, which follows the current phase's `sub` line).
///
/// A switch expression, so a new [StartupMessage] is a compile error here
/// rather than a missing caption on a child's screen.
String introSubtitleFor(StartupMessage message, AppLocalizations t) =>
    switch (message) {
      StartupMessage.preparing => t.introStagePreparing,
      StartupMessage.solarSystem => t.introStageSolarSystem,
      StartupMessage.sun => t.introStageSun,
      StartupMessage.planets => t.introStagePlanets,
      StartupMessage.moons => t.introStageMoons,
      StartupMessage.companion => t.introStageCompanion,
      StartupMessage.missions => t.introStageMissions,
      StartupMessage.sounds => t.introStageSounds,
      StartupMessage.ready => t.introStageReady,
    };
