import 'package:equatable/equatable.dart';

/// Turns a hotspot title into the key used for both its audio file and its
/// translation row.
///
/// Lives in the domain layer because a hotspot is identified by nothing but
/// its title, and both the audio catalog and the translation table need that
/// identity. Letting the two derive it separately is how a translated title
/// ends up pointing at a file that was never recorded.
String hotspotSlug(String title) => title
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

/// A kid-friendly hotspot shown in the planet detail sheet.
class Hotspot extends Equatable {
  const Hotspot({
    required this.title,
    required this.description,
    required this.icon,
    this.narration,
  });

  final String title;
  final String description;
  final String icon;

  /// Spoken copy, written for the ear rather than the screen. Falls back to
  /// [description] when absent so the sheet never goes mute.
  final String? narration;

  /// Stable key for this hotspot, used for its audio filename and its
  /// translation row. Derived from the English title because that is the only
  /// field that has to exist before the app can load either.
  String get slug => hotspotSlug(title);

  @override
  List<Object?> get props => [title, description, icon, narration];
}

/// A hotspot together with the body it belongs to.
///
/// A [Hotspot] on its own is not enough to address: [Hotspot.slug] is only
/// unique within one planet, so the audio file and the translation row both
/// need the owner. The detail sheet and the toast carry this rather than a
/// string, so the view resolves the name in the active language instead of
/// freezing whatever English the catalogue happened to hold.
class HotspotRef extends Equatable {
  const HotspotRef({required this.planetId, required this.hotspot});

  final String planetId;
  final Hotspot hotspot;

  String get slug => hotspot.slug;

  @override
  List<Object?> get props => [planetId, hotspot];
}

/// Immutable description of one solar-system body.
///
/// Pure data (DIP): rendering lives in `infrastructure/scene`,
/// content lives in `data/datasources`.
class Planet extends Equatable {
  const Planet({
    required this.id,
    required this.name,
    required this.tag,
    required this.fact,
    required this.radius,
    required this.orbitRadius,
    required this.orbitSpeed,
    required this.startAngle,
    required this.colorValue,
    required this.tiltDegrees,
    required this.textureAsset,
    required this.diameter,
    required this.temperature,
    required this.dayLength,
    required this.hotspots,
    this.narration,
    this.parentPlanetId,
    this.isMoon = false,
    this.ringTextureAsset,
    this.ringInnerFactor = 1.35,
    this.ringOuterFactor = 2.1,
    this.isSun = false,
  });

  final String id;
  final String name;
  final String tag;
  final String fact;

  /// Conversational script read aloud for this body. Kept separate from
  /// [fact] so the spoken voice can address the child directly while the
  /// on-screen text stays factual. Falls back to [fact] when absent.
  final String? narration;

  /// Parent planet for natural satellites. Moon orbit values are relative to
  /// the parent planet rather than the Sun.
  final String? parentPlanetId;

  /// True when this body is a moon rather than one of the eight planets.
  final bool isMoon;

  /// Visual 3D radius in world units (already kid-scaled).
  final double radius;

  /// Orbit radius in world units.
  final double orbitRadius;

  /// Radians travelled per simulation-second at 1x speed.
  final double orbitSpeed;

  /// Starting orbit angle in radians.
  final double startAngle;

  final int colorValue;
  final double tiltDegrees;
  final String textureAsset;

  final String diameter;
  final String temperature;
  final String dayLength;

  final List<Hotspot> hotspots;

  /// Optional flat ring (Saturn).
  final String? ringTextureAsset;
  final double ringInnerFactor;
  final double ringOuterFactor;
  final bool isSun;

  bool get hasRing => ringTextureAsset != null;

  @override
  List<Object?> get props => [id, parentPlanetId, isMoon];
}
