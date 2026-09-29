import 'package:flutter/widgets.dart';
import 'package:kidz_planets/data/datasources/planet_catalog.dart';
import 'package:kidz_planets/data/localizations/planet_copy.dart';
import 'package:kidz_planets/data/localizations/planet_translations_id.dart';
import 'package:kidz_planets/domain/entities/planet.dart';

/// Locale-keyed planet copy. One row per body per language.
const Map<String, Map<String, PlanetCopy>> planetCopyByLanguage = {
  'id': planetCopyId,
};

PlanetCopy _copyFor(Planet planet, Locale locale) =>
    planetCopyByLanguage[locale.languageCode]?[planet.id] ?? const PlanetCopy();

/// A [Hotspot] with its copy resolved for the active language.
class LocalizedHotspot {
  const LocalizedHotspot({
    required this.hotspot,
    required this.planetId,
    required this.title,
    required this.description,
  });

  final Hotspot hotspot;
  final String planetId;
  final String title;
  final String description;

  /// Spoken copy, falling back to [description] when a language has no script
  /// yet, so a hotspot is never silent.
  String narrationFor(Locale locale) {
    final copy = _copyFor(
      _planetOf(planetId),
      locale,
    ).hotspots[hotspot.slug];
    return copy?.narration ?? description;
  }
}

/// A [Planet] with its copy resolved for the active language.
class LocalizedPlanet {
  const LocalizedPlanet({
    required this.planet,
    required this.name,
    required this.tag,
    required this.fact,
    required this.hotspots,
  });

  final Planet planet;
  final String name;
  final String tag;
  final String fact;
  final List<LocalizedHotspot> hotspots;

  /// Spoken copy for the body, falling back to [fact] when a language has no
  /// script yet.
  String narrationFor(Locale locale) =>
      _copyFor(planet, locale).narration ?? fact;

  String get id => planet.id;
  bool get isSun => planet.isSun;
  bool get isMoon => planet.isMoon;
  bool get hasRing => planet.hasRing;
  String get textureAsset => planet.textureAsset;
  String get diameter => planet.diameter;
  String get temperature => planet.temperature;
  String get dayLength => planet.dayLength;
  List<Hotspot> get rawHotspots => planet.hotspots;
}

Planet _planetOf(String planetId) => PlanetCatalog.planets.firstWhere(
      (p) => p.id == planetId,
      orElse: () => throw ArgumentError('unknown planet $planetId'),
    );

/// Resolves [planet]'s copy into [locale], degrading per field to English.
///
/// English is not a special case in the table: it is simply what the entity
/// already carries, so a locale with no row renders in English rather than
/// blank, and a partially translated locale fills the gaps from English.
LocalizedPlanet localizedPlanet(Planet planet, Locale locale) {
  final copy = _copyFor(planet, locale);
  return LocalizedPlanet(
    planet: planet,
    name: copy.name ?? planet.name,
    tag: copy.tag ?? planet.tag,
    fact: copy.fact ?? planet.fact,
    hotspots: [
      for (final h in planet.hotspots)
        LocalizedHotspot(
          hotspot: h,
          planetId: planet.id,
          title: copy.hotspots[h.slug]?.title ?? h.title,
          description: copy.hotspots[h.slug]?.description ?? h.description,
        ),
    ],
  );
}

List<LocalizedPlanet> localizedPlanets(List<Planet> planets, Locale locale) =>
    [for (final p in planets) localizedPlanet(p, locale)];

/// The localized name of a body, for callers that hold only its id.
String localizedPlanetName(String planetId, Locale locale) =>
    localizedPlanet(_planetOf(planetId), locale).name;

/// The localized title of one hotspot, for callers holding a [HotspotRef]
/// rather than the whole body, such as the toast overlay.
String localizedHotspotTitle(HotspotRef hotspot, Locale locale) =>
    localizedPlanet(_planetOf(hotspot.planetId), locale)
        .hotspots
        .where((h) => h.hotspot.slug == hotspot.slug)
        .firstOrNull
        ?.title ??
    hotspot.hotspot.title;
