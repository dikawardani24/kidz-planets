import 'package:equatable/equatable.dart';

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

  @override
  List<Object?> get props => [title, description, icon, narration];
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
