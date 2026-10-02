import 'package:flutter_test/flutter_test.dart';

import 'package:mission/data.dart';

const garbageTokens = [
  'opsyang',
  'championed',
  'bustedastro',
  'rental-tone',
  'negative hanya',
  'berputarcreating',
  'menyinject',
  'named planet',
  'sealing',
  'fromopsyang',
  '.planet ',
  'danplanet',
  'ini planet',
  'все',
  'это',
  'этот',
];

void main() {
  final missions = MissionCatalog.missions;

  group('coverage', () {
    test('every mission has an Indonesian row', () {
      final missing = missions
          .map((m) => m.id)
          .where((id) => !missionCopyId.containsKey(id))
          .toList();
      expect(missing, isEmpty, reason: 'no Indonesian copy for: $missing');
    });

    test('Indonesian has no rows for missions that do not exist', () {
      final extra = missionCopyId.keys
          .where((id) => !missions.any((m) => m.id == id))
          .toList();
      expect(extra, isEmpty, reason: 'orphan mission rows: $extra');
    });

    test('every field is translated', () {
      final blank = <String>[];
      for (final m in missions) {
        final c = missionCopyId[m.id];
        if (c == null) continue;
        if (c.title == null || c.title!.trim().isEmpty) {
          blank.add('${m.id}.title');
        }
        if (c.description == null || c.description!.trim().isEmpty) {
          blank.add('${m.id}.description');
        }
        if (c.startPoint == null || c.startPoint!.trim().isEmpty) {
          blank.add('${m.id}.startPoint');
        }
        if (c.direction == null || c.direction!.trim().isEmpty) {
          blank.add('${m.id}.direction');
        }
      }
      expect(blank, isEmpty, reason: 'blank: $blank');
    });

    test('no field is still the English text', () {
      final untranslated = <String>[];
      for (final m in missions) {
        final c = missionCopyId[m.id];
        if (c == null) continue;
        if (c.title == m.title) untranslated.add('${m.id}.title');
        if (c.description == m.description) {
          untranslated.add('${m.id}.description');
        }
        if (c.startPoint == m.startPoint) {
          untranslated.add('${m.id}.startPoint');
        }
        if (c.direction == m.direction) {
          untranslated.add('${m.id}.direction');
        }
        if (c.hints != null) {
          for (var i = 0; i < c.hints!.length; i++) {
            if (i < m.hints.length && c.hints![i] == m.hints[i]) {
              untranslated.add('${m.id}.hints[$i]');
            }
          }
        }
      }
      expect(untranslated, isEmpty, reason: 'still English: $untranslated');
    });
  });

  group('clue escalation survives translation', () {
    test('each mission still has three clues', () {
      for (final m in missions) {
        expect(
          missionCopyId[m.id]?.hints,
          hasLength(3),
          reason: 'mission ${m.id}',
        );
      }
    });

    test('clues are distinct within a mission', () {
      for (final m in missions) {
        final hints = missionCopyId[m.id]!.hints!;
        expect(
          hints.toSet(),
          hasLength(hints.length),
          reason: 'mission ${m.id} repeats a clue',
        );
      }
    });

    test('clues get blunter as they escalate, not vaguer', () {
      // The English copy escalates from a visual trait to a position to a
      // near-answer. A translation that loses the ordering teaches the child
      // nothing, so the last clue must still be the longest or at least not
      // the shortest.
      for (final m in missions) {
        final hints = missionCopyId[m.id]!.hints!;
        expect(
          hints.last.length,
          greaterThan(hints.first.length),
          reason: 'mission ${m.id} escalation is inverted',
        );
      }
    });
  });
}
