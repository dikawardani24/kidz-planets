import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Both Indonesian content files, guarded together.
///
/// The first drafts of both files contained fragments of English and CJK glued
/// into the middle of Indonesian sentences ("opsyang", "berputarcreating",
/// "Bumi.planet ketiga"). Nothing about the Dart type system catches that, and
/// a reader who does not speak Indonesian will not either, so the checks below
/// are mechanical.
///
/// This is the one translation check that stays in the app: the two tables live
/// in different feature packages and the corruption they invite is the same in
/// both. Each package also guards its own table alongside its coverage tests.
const translationFiles = [
  // Relative to the workspace root: the two tables now live in the feature
  // packages that own their copy, not beside the app.
  '../../packages/planets/lib/src/data/localizations/planet_translations_id.dart',
  '../../packages/mission/lib/src/data/localizations/mission_translations_id.dart',
];

const garbageTokens = [
  'opsyang',
  'championed',
  'bustedastro',
  'rental-tone',
  'negative hanya',
  'berputarcreating',
  'menyinject',
  'named planet',
  'fromopsyang',
  '.planet ',
  'danplanet',
];

void main() {
  group('corruption guard', () {
    for (final path in translationFiles) {
      test('$path has no pasted-garbage token', () {
        final blob = File(path).readAsStringSync().toLowerCase();
        for (final token in garbageTokens) {
          expect(blob, isNot(contains(token.toLowerCase())), reason: token);
        }
      });

      test('$path contains no CJK or Cyrillic characters', () {
        // A stray ideograph or Cyrillic letter means text was pasted from the
        // wrong source and never read over.
        final pattern = RegExp(r'[\u0400-\u04FF\u4e00-\u9fff]');
        final hit = pattern.firstMatch(File(path).readAsStringSync());
        expect(hit, isNull, reason: 'found "${hit?.group(0)}"');
      });
    }
  });
}
