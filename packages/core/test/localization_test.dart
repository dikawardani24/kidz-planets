import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/l10n.dart';

/// Reads an ARB file straight from disk.
///
/// The generated delegate exposes getters but no key list, so parity has to be
/// checked at the source. That is also the better place to check it: a key
/// added to the template and forgotten in the translation is exactly the bug
/// that shows up as raw English leaking into an otherwise-Indonesian screen,
/// and it is invisible to a test that only walks the generated class.
Map<String, Object?> loadArb(String name) =>
    jsonDecode(File('lib/src/l10n/arb/$name.arb').readAsStringSync())
        as Map<String, Object?>;

/// Keys, i.e. everything that is not ARB metadata.
Iterable<String> arbKeys(Map<String, Object?> arb) =>
    arb.keys.where((k) => !k.startsWith('@'));

Map<String, Object?> enArb = loadArb('app_en');
Map<String, Object?> idArb = loadArb('app_id');

/// Strings a child would notice if they came back in English. A few values are
/// legitimately identical in both languages (Diameter, their), so rather than
/// trying to whitelist those by hand this lists the ones that must change.
const mustDiffer = [
  'bannerSwipeToSpin',
  'bannerZoom',
  'bannerAllExplored',
  'bannerPlayMode',
  'navExplore',
  'navPlayground',
  'navMissions',
  'missionNeedBiggerClue',
  'missionGotIt',
  'missionStartHere',
  'missionLookForThis',
  'companionMoveLabel',
  'tooltipLanguage',
  'playgroundTitle',
  'spaceMissions',
  'close',
];

final placeholderPatterns = <String, RegExp>{
  'speedLabel': RegExp(r'\{speed\}'),
  'bannerMission': RegExp(r'\{id\}'),
  'missionPill': RegExp(r'\{id\}'),
  'missionHeading': RegExp(r'\{id\}'),
  'missionStartAt': RegExp(r'\{point\}'),
  'celebrationTitle': RegExp(r'\{id\}'),
  'celebrationBody': RegExp(r'\{target\}'),
  'toastMissionComplete': RegExp(r'\{title\}'),
  'toastMissionVerified': RegExp(r'\{title\}'),
  'missionCount': RegExp(r'\{completed\}'),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('locale resolution', () {
    test('follows the device when nothing is chosen', () {
      expect(
        LocaleController().resolve(const Locale('id', 'ID')),
        const Locale('id'),
      );
    });

    test('an unrecognised device language falls back to English', () {
      final c = LocaleController();
      expect(c.resolve(const Locale('fr', 'FR')), const Locale('en'));
      expect(c.resolve(null), const Locale('en'));
    });

    test('a region variant still matches its language', () {
      expect(
        LocaleController().resolve(const Locale('id', 'ID_POSIX')),
        const Locale('id'),
      );
    });

    test('an explicit choice overrides the device', () {
      final c = LocaleController();
      c.select(const Locale('en'));
      expect(c.resolve(const Locale('id', 'ID')), const Locale('en'));
    });

    test('an unsupported choice is ignored and the last good one kept', () {
      // Keeping the child's existing pick matters: falling back to null would
      // silently hand control back to the device language.
      final c = LocaleController();
      c.select(const Locale('id'));
      c.select(const Locale('fr'));
      expect(c.resolve(null), const Locale('id'));
    });

    test('never returns a locale the app cannot load', () {
      // The generated delegate throws outright on an unsupported locale
      // rather than falling back, so this is the guard that keeps a French or
      // Japanese device from crashing the app on first frame.
      for (final input in <Locale?>[
        null,
        const Locale('ru'),
        const Locale('zh', 'CN'),
        const Locale('pt', 'BR'),
        const Locale('en', 'GB'),
      ]) {
        expect(
          kSupportedLocales,
          contains(LocaleController().resolve(input)),
          reason: 'resolve($input) produced an unloadable locale',
        );
      }
    });
  });

  group('translation coverage', () {
    test('Indonesian defines every key English does', () {
      final missing = arbKeys(enArb)
          .where((k) => !idArb.containsKey(k))
          .toList();
      expect(missing, isEmpty, reason: 'missing Indonesian copy: $missing');
    });

    test('Indonesian adds no keys English does not have', () {
      final extra = arbKeys(idArb).where((k) => !enArb.containsKey(k)).toList();
      expect(extra, isEmpty, reason: 'orphan Indonesian keys: $extra');
    });

    test('no Indonesian value is still the English string', () {
      final untranslated = mustDiffer
          .where((k) => idArb[k] == enArb[k])
          .toList();
      expect(untranslated, isEmpty, reason: 'not translated: $untranslated');
    });

    test('no Indonesian value is blank', () {
      final blank = arbKeys(idArb)
          .where((k) => (idArb[k] as String).trim().isEmpty)
          .toList();
      expect(blank, isEmpty, reason: 'blank Indonesian copy: $blank');
    });

    test('placeholders survive translation', () {
      // A dropped placeholder silently renders "Mission : Find Earth".
      for (final entry in placeholderPatterns.entries) {
        expect(
          enArb[entry.key],
          matches(entry.value),
          reason: 'English ${entry.key} lost its placeholder',
        );
        expect(
          idArb[entry.key],
          matches(entry.value),
          reason: 'Indonesian ${entry.key} lost its placeholder',
        );
      }
    });

    test('placeholder sets match between the two locales', () {
      final pattern = RegExp(r'\{(\w+)\}');
      for (final key in arbKeys(enArb)) {
        final enNames = pattern
            .allMatches(enArb[key]! as String)
            .map((m) => m.group(1))
            .toSet();
        final idNames = pattern
            .allMatches(idArb[key]! as String)
            .map((m) => m.group(1))
            .toSet();
        expect(idNames, enNames, reason: '$key placeholders differ');
      }
    });
  });

  group('lookup', () {
    Future<AppLocalizations> load(Locale locale) =>
        AppLocalizations.delegate.load(locale);

    test('serves English copy for the English locale', () async {
      expect((await load(const Locale('en'))).navExplore, 'Explore');
    });

    test('serves Indonesian copy for the Indonesian locale', () async {
      expect((await load(const Locale('id'))).navExplore, 'Jelajahi');
    });

    test('an Indonesian region variant still resolves', () async {
      expect((await load(const Locale('id', 'ID'))).navExplore, 'Jelajahi');
    });

    test('an unsupported locale is rejected by the delegate, not faked', () {
      // Documents why `resolve` must never hand the delegate a locale the app
      // does not ship. If this ever starts returning English instead, the
      // guard in `resolve` has become redundant and can be revisited.
      expect(
        () => AppLocalizations.delegate.load(const Locale('fr')),
        throwsA(isA<AssertionError>()),
      );
    });

    test('generated placeholders are substituted, not printed', () async {
      final t = await load(const Locale('id'));
      expect(t.bannerMission(2, 'Bumi'), 'Misi 2: Bumi');
      expect(t.speedLabel('1.5'), '1.5x');
    });
  });
}
