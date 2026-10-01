import 'package:flutter/widgets.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/data/localizations/mission_translations_id.dart';

/// Locale-keyed mission copy. One row per mission per language.
const Map<String, Map<int, MissionCopy>> missionCopyByLanguage = {
  'id': missionCopyId,
};

MissionCopy _copyFor(int missionId, Locale locale) =>
    missionCopyByLanguage[locale.languageCode]?[missionId] ??
    const MissionCopy();

/// A [MissionState] with its copy resolved for the active language.
class LocalizedMission {
  const LocalizedMission({
    required this.mission,
    required this.title,
    required this.description,
    this.startPoint,
    this.direction,
    this.hints = const [],
  });

  final MissionState mission;
  final String title;
  final String description;
  final String? startPoint;
  final String? direction;
  final List<String> hints;

  int get id => mission.id;
  String get targetPlanetId => mission.targetPlanetId;
  bool get completed => mission.completed;

  /// The clue at [level], clamped to the last one so asking for more clues
  /// past the end repeats the final one rather than throwing.
  String clueAt(int level) =>
      hints.isEmpty ? description : hints[level.clamp(0, hints.length - 1)];

  @override
  String toString() => 'LocalizedMission($id, $title)';
}

/// Resolves [mission]'s copy into [locale], degrading per field to English.
///
/// English is not a special case in the table: it is simply what the state
/// already carries, so a locale with no row renders in English rather than
/// blank, and a partially translated locale fills the gaps from English.
LocalizedMission localizedMission(MissionState mission, Locale locale) {
  final copy = _copyFor(mission.id, locale);
  // Hints replace wholesale rather than per index, so a mission can never
  // read as a mix of Indonesian clues and an English one halfway down.
  final hints = copy.hints ?? mission.hints;
  return LocalizedMission(
    mission: mission,
    title: copy.title ?? mission.title,
    description: copy.description ?? mission.description,
    startPoint: copy.startPoint ?? mission.startPoint,
    direction: copy.direction ?? mission.direction,
    hints: hints,
  );
}

List<LocalizedMission> localizedMissions(
  List<MissionState> missions,
  Locale locale,
) =>
    [for (final m in missions) localizedMission(m, locale)];
