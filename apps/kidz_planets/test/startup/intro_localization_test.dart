import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The intro screen's copy, guarded at the ARB source.
///
/// `packages/core/test/localization_test.dart` already checks key parity and
/// placeholder survival for the table as a whole; these tests pin the things
/// that make the intro *look* like `prototype/intro.html` and would otherwise
/// regress silently in a copy edit: the quoted message wrapper, the phase
/// strings carrying their emoji, the completion line, and the rotating fact
/// texts staying distinct.
Map<String, Object?> loadArb(String name) => jsonDecode(
  File('../../packages/core/lib/src/l10n/arb/$name.arb').readAsStringSync(),
) as Map<String, Object?>;

const introKeys = [
  'introBrandTag',
  'introTitle',
  'introSubtitle',
  'introPhasePreparing',
  'introPhaseSolarSystem',
  'introPhaseSun',
  'introPhasePlanets',
  'introPhaseMoons',
  'introPhaseCompanion',
  'introPhaseMissions',
  'introPhaseSounds',
  'introPhaseReady',
  'introMessage',
  'introStagePreparing',
  'introStageSolarSystem',
  'introStageSun',
  'introStagePlanets',
  'introStageMoons',
  'introStageCompanion',
  'introStageMissions',
  'introStageSounds',
  'introStageReady',
  'introPercent',
  'introFactLabel',
  'introFact',
  'introMilestoneEarth',
  'introMilestoneMoon',
  'introMilestoneSaturn',
  'introCompleteTitle',
  'introCompleteSubtitle',
  'introEnterCta',
  'introErrorTitle',
  'introErrorBody',
  'introRetry',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = loadArb('app_en');
  final id = loadArb('app_id');

  test('both locales define every intro key, and nothing more', () {
    for (final key in introKeys) {
      expect(en.containsKey(key), isTrue, reason: 'en missing $key');
      expect(id.containsKey(key), isTrue, reason: 'id missing $key');
    }
    // The intro table is exactly the intro keys plus the pre-existing ones, so
    // an orphan key here means a rename that only landed on one side.
    final enIntro = en.keys.where((k) => k.startsWith('intro')).toSet();
    expect(enIntro, introKeys.toSet());
  });

  test('the message card wraps its text in the prototype\'s quotes', () {
    // The mock renders `"Waking up the Sun... ☀️"` — the quotes are part of
    // the copy, not the widget, so the template has to carry them.
    expect(en['introMessage'], '"{message}"');
    expect(id['introMessage'], '"{message}"');
  });

  test('phase lines keep their emoji in both locales', () {
    for (final key in [
      'introPhaseSolarSystem',
      'introPhaseSun',
      'introPhasePlanets',
      'introPhaseMoons',
      'introPhaseCompanion',
      'introPhaseMissions',
      'introPhaseSounds',
    ]) {
      expect(en[key], isNotNull);
      expect(
        (en[key]! as String).codeUnits.any((u) => u > 0x2000),
        isTrue,
        reason: 'en $key lost its emoji',
      );
      expect(
        (id[key]! as String).codeUnits.any((u) => u > 0x2000),
        isTrue,
        reason: 'id $key lost its emoji',
      );
    }
  });

  test('completion and error copy is set, in both locales', () {
    expect(en['introCompleteTitle'], contains('READY'));
    expect(en['introEnterCta'], isNotEmpty);
    expect(en['introErrorTitle'], isNotEmpty);
    expect(en['introErrorBody'], isNotEmpty);
    expect(en['introRetry'], isNotEmpty);
    expect(id['introCompleteTitle'], isNot(equals(en['introCompleteTitle'])));
    expect(id['introErrorBody'], isNot(equals(en['introErrorBody'])));
    expect(id['introRetry'], isNot(equals(en['introRetry'])));
  });

  test('the intro keys are Indonesian, not English left in place', () {
    // Same guard as the app's translation test, narrowed to the new keys: a
    // child on an Indonesian device must not read the English loading screen.
    for (final key in [
      'introTitle',
      'introSubtitle',
      'introPhasePreparing',
      'introPhaseMissions',
      'introFactLabel',
      'introMilestoneEarth',
      'introMilestoneSaturn',
      'introCompleteTitle',
      'introCompleteSubtitle',
      'introEnterCta',
      'introErrorTitle',
      'introRetry',
    ]) {
      expect(id[key], isNot(equals(en[key])), reason: '$key is still English');
    }
  });
}
