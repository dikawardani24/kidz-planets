import 'package:kidz_planets/domain/entities/planet.dart';

/// Copy for one hotspot in one language.
///
/// Every field is nullable so a partial translation degrades to English per
/// field rather than blanking the sheet.
class HotspotCopy {
  const HotspotCopy({this.title, this.description, this.narration});
  final String? title;
  final String? description;
  final String? narration;
}

/// Copy for one body in one language, same per-field fallback.
class PlanetCopy {
  const PlanetCopy({
    this.name,
    this.tag,
    this.fact,
    this.narration,
    this.hotspots = const {},
  });

  final String? name;
  final String? tag;
  final String? fact;
  final String? narration;

  /// Keyed by [hotspotSlug] of the English title.
  final Map<String, HotspotCopy> hotspots;
}
