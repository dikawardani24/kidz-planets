import 'package:flutter/widgets.dart';
import 'package:kidz_planets/application/state/app_message.dart';
import 'package:kidz_planets/l10n/generated/app_localizations.dart';
import 'package:kidz_planets/l10n/localized_planet.dart';

/// Resolves an [AppMessage] into the active language.
///
/// Lives in the l10n layer rather than on the enum so that adding a message
/// forces a decision here, and the switch is exhaustive over
/// [AppMessageId] so a new id that nobody translated fails to compile.
///
/// [locale] is required rather than defaulted: a message that names a body has
/// to name it in the language the child is looking at, and a silent default
/// would quietly hand back the English name in an Indonesian build.
extension AppMessageLocalization on AppMessage {
  String resolve(AppLocalizations t, Locale locale) {
    String named(String key) {
      final value = args[key];
      if (value == null) {
        throw ArgumentError('AppMessage.$id is missing the "$key" argument');
      }
      return value.toString();
    }

    return switch (id) {
      AppMessageId.alertSandboxTitle => t.alertSandboxTitle,
      AppMessageId.alertSandboxDescription => t.alertSandboxDescription,
      AppMessageId.alertEarthTitle => t.alertEarthTitle,
      AppMessageId.alertEarthDescription => t.alertEarthDescription,
      AppMessageId.alertSaturnTitle => t.alertSaturnTitle,
      AppMessageId.alertSaturnDescription => t.alertSaturnDescription,
      AppMessageId.alertJupiterTitle => t.alertJupiterTitle,
      AppMessageId.alertJupiterDescription => t.alertJupiterDescription,
      AppMessageId.alertSunTitle => t.alertSunTitle,
      AppMessageId.alertSunDescription => t.alertSunDescription,
      AppMessageId.toastMissionComplete => t.toastMissionComplete(named('title')),
      AppMessageId.toastMissionVerified =>
        t.toastMissionVerified(named('title')),
      AppMessageId.toastSandboxReady => t.toastSandboxReady,
      AppMessageId.celebrationMissionTitle =>
        t.celebrationTitle(int.parse(named('id'))),
      AppMessageId.celebrationDiscovered =>
        t.celebrationBody(localizedPlanetName(named('planetId'), locale)),
    };
  }
}

/// Reads a message in the current locale, read from the widget context.
extension AppLocalizationsMessages on AppLocalizations {
  String message(AppMessage m, Locale locale) => m.resolve(this, locale);
}
