import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/data/datasources/planet_catalog.dart';
import 'package:kidz_planets/data/localizations/planet_translations_id.dart';
import 'package:kidz_planets/domain/entities/planet.dart';

import 'helpers/translation_allowlist.dart';

/// Both Indonesian content files, guarded together.
///
/// The first drafts of both files contained fragments of English and CJK glued
/// into the middle of Indonesian sentences ("opsyang", "berputarcreating",
/// "Bumi.planet ketiga"). Nothing about the Dart type system catches that, and
/// a reader who does not speak Indonesian will not either, so the checks below
/// are mechanical.
const translationFiles = [
  'lib/data/localizations/planet_translations_id.dart',
  'lib/data/localizations/mission_translations_id.dart',
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

  group('allowlist', () {
    test('the planet name allowlist has no stale entries', () {
      // A name that starts being translated should drop out of the list, and a
      // name that quietly reverts to English should drop in. Either way the
      // list must not accumulate entries nobody is checking.
      final stale = <String>[];
      for (final id in allowedIdenticalNames) {
        final planet = PlanetCatalog.planets.firstWhere((p) => p.id == id);
        if (planetCopyId[id]?.name != planet.name) stale.add(id);
      }
      for (final key in allowedIdenticalHotspotTitles) {
        final parts = key.split('/');
        final planet =
            PlanetCatalog.planets.firstWhere((p) => p.id == parts[0]);
        final hotspot = planet.hotspots
            .firstWhere((h) => hotspotSlug(h.title) == parts[1]);
        if (planetCopyId[parts[0]]?.hotspots[parts[1]]?.title != hotspot.title) {
          stale.add(key);
        }
      }
      expect(stale, isEmpty, reason: 'stale allowlist entries: $stale');
    });

    test('every allowlist entry is a real row', () {
      for (final id in allowedIdenticalNames) {
        expect(planetCopyId.containsKey(id), isTrue, reason: id);
      }
    });
  });
}
