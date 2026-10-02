import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/l10n.dart';

/// Wraps [child] in the minimum app scaffolding a localized widget needs.
///
/// Every widget that calls [AppLocalizations.of] throws without the delegates
/// being installed above it, and a bare `MaterialApp` does not install them.
/// Tests that pump a panel directly would otherwise fail on a lookup rather
/// than on whatever they actually assert, so they go through here instead.
Widget localizedApp(
  Widget child, {
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: kSupportedLocales,
      home: child,
    ),
  );
}

/// Pumps [child] inside [localizedApp] and settles the first frame.
Future<void> pumpLocalized(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    localizedApp(child, locale: locale, overrides: overrides),
  );
  await tester.pumpAndSettle();
}
