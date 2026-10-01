import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locales the app ships copy for. Order is irrelevant; [AppLocalizations]
/// decides the fallback chain.
const List<Locale> kSupportedLocales = [Locale('en'), Locale('id')];

/// The language the child has explicitly chosen, or `null` to follow the
/// device. `null` is the default so a child whose phone is already in
/// Bahasa Indonesia gets Indonesian without touching a switch.
class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null);

  void select(Locale locale) {
    if (!kSupportedLocales.any((l) => l.languageCode == locale.languageCode)) return;
    state = locale;
  }

  /// Resolves [state] against the device language, matching on language code
  /// only so `id_ID` and `id_ID_POSIX` both land on Indonesian. Anything
  /// unrecognised falls through to English rather than showing raw keys.
  Locale resolve(Locale? deviceLocale) {
    final chosen = state;
    final candidate = chosen ?? deviceLocale;
    if (candidate == null) return const Locale('en');
    return kSupportedLocales.firstWhere(
      (l) => l.languageCode == candidate.languageCode,
      orElse: () => const Locale('en'),
    );
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale?>(
  (ref) => LocaleController(),
);
