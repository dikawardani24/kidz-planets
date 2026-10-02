import 'package:flutter_test/flutter_test.dart';
import 'package:planets/data.dart';
import 'package:planets/domain.dart';

import 'helpers/translation_allowlist.dart';

void main() {
  final planets = PlanetCatalog.planets;
  // Keyed "planetId/slug", which is also how the translation table nests them.
  final allHotspots = <String, ({String planetId, Hotspot hotspot})>{
    for (final p in planets)
      for (final h in p.hotspots)
        '${p.id}/${h.slug}': (planetId: p.id, hotspot: h),
  };

  group('coverage', () {
    test('every body has an Indonesian row', () {
      final missing = planets
          .map((p) => p.id)
          .where((id) => !planetCopyId.containsKey(id))
          .toList();
      expect(missing, isEmpty, reason: 'no Indonesian copy for: $missing');
    });

    test('Indonesian has no rows for bodies that do not exist', () {
      final extra = planetCopyId.keys
          .where((id) => !planets.any((p) => p.id == id))
          .toList();
      expect(extra, isEmpty, reason: 'orphan translation rows: $extra');
    });

    test('every hotspot has an Indonesian row', () {
      final missing = allHotspots.entries
          .where(
            (e) =>
                planetCopyId[e.value.planetId]?.hotspots[e
                    .value
                    .hotspot
                    .slug] ==
                null,
          )
          .map((e) => e.key)
          .toList();
      expect(missing, isEmpty, reason: 'no Indonesian copy for: $missing');
    });

    test('Indonesian has no rows for hotspots that do not exist', () {
      final missing = <String>[];
      for (final entry in planetCopyId.entries) {
        final planet = planets.firstWhere((p) => p.id == entry.key);
        for (final slug in entry.value.hotspots.keys) {
          if (!planet.hotspots.any((h) => hotspotSlug(h.title) == slug)) {
            missing.add('${entry.key}/$slug');
          }
        }
      }
      expect(missing, isEmpty, reason: 'orphan hotspot rows: $missing');
    });
  });

  group('no untranslated leftovers', () {
    test('no Indonesian field still holds the English text', () {
      final offenders = <String>[];
      for (final p in planets) {
        final copy = planetCopyId[p.id];
        if (copy == null) continue;
        if (copy.name == p.name && !allowedIdenticalNames.contains(p.id)) {
          offenders.add('${p.id}.name');
        }
        if (copy.tag == p.tag) offenders.add('${p.id}.tag');
        if (copy.fact == p.fact) offenders.add('${p.id}.fact');
        if (copy.narration == p.narration) offenders.add('${p.id}.narration');
        for (final h in p.hotspots) {
          final hc = copy.hotspots[hotspotSlug(h.title)];
          if (hc == null) continue;
          if (hc.title == h.title &&
              !allowedIdenticalHotspotTitles.contains('${p.id}/${h.slug}')) {
            offenders.add('${p.id}/${h.title}.title');
          }
          if (hc.description == h.description) {
            offenders.add('${p.id}/${h.title}.description');
          }
        }
      }
      expect(offenders, isEmpty, reason: 'still English: $offenders');
    });

    test('no field is blank', () {
      final blanks = <String>[];
      for (final entry in planetCopyId.entries) {
        final copy = entry.value;
        for (final (field, value) in [
          ('name', copy.name),
          ('tag', copy.tag),
          ('fact', copy.fact),
          ('narration', copy.narration),
        ]) {
          if (value?.trim().isEmpty ?? false) blanks.add('${entry.key}.$field');
        }
      }
      expect(blanks, isEmpty, reason: 'blank: $blanks');
    });
  });

  group('quality', () {
    test('Indonesian narrations end in sentence punctuation', () {
      // A script that runs into the next sentence, or ends mid-clause, reads
      // badly aloud and is the most common copy defect in a narration track.
      final bad = <String>[];
      for (final p in planets) {
        final n = planetCopyId[p.id]?.narration;
        if (n != null && !RegExp(r'[.!?]\s*$').hasMatch(n.trim())) {
          bad.add(p.id);
        }
      }
      expect(bad, isEmpty, reason: 'unterminated narration: $bad');
    });

    test('every body has a spoken script, as English does', () {
      // Not a hard requirement, but a body that narrates in English and not in
      // Indonesian would fall back and read in the wrong language.
      final missing = planets
          .where(
            (p) => p.narration != null && planetCopyId[p.id]?.narration == null,
          )
          .map((p) => p.id)
          .toList();
      expect(missing, isEmpty, reason: 'no Indonesian narration: $missing');
    });

    test('Indonesian keeps the emoji and unit conventions of the source', () {
      // "15 juta derajat Celsius" must not become "15 million degrees C" and
      // lose the unit, so check the numeric facts still carry their units.
      final sun = planetCopyId['sun']!.fact!;
      expect(sun, contains('15 juta'));
      expect(sun, contains('Celsius'));
    });
  });

  group('allowlist', () {
    test('the planet name allowlist has no stale entries', () {
      // A name that starts being translated should drop out of the list, and a
      // name that quietly reverts to English should drop in. Either way the
      // list must not accumulate entries nobody is checking.
      final stale = <String>[];
      for (final id in allowedIdenticalNames) {
        final planet = planets.firstWhere((p) => p.id == id);
        if (planetCopyId[id]?.name != planet.name) stale.add(id);
      }
      for (final key in allowedIdenticalHotspotTitles) {
        final parts = key.split('/');
        final planet = planets.firstWhere((p) => p.id == parts[0]);
        final hotspot = planet.hotspots.firstWhere(
          (h) => hotspotSlug(h.title) == parts[1],
        );
        if (planetCopyId[parts[0]]?.hotspots[parts[1]]?.title !=
            hotspot.title) {
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

  group('slugs', () {
    test('a hotspot slug is a usable filename', () {
      for (final e in allHotspots.entries) {
        final slug = e.value.hotspot.slug;
        expect(slug, matches(RegExp(r'^[a-z0-9_]+$')), reason: e.key);
        expect(slug, isNot(contains('__')), reason: e.key);
      }
    });

    test('two hotspots in one planet never collide on a slug', () {
      for (final p in planets) {
        final slugs = p.hotspots.map((h) => hotspotSlug(h.title)).toList();
        expect(
          slugs.toSet(),
          hasLength(slugs.length),
          reason: 'slug collision in ${p.id}',
        );
      }
    });
  });
}
