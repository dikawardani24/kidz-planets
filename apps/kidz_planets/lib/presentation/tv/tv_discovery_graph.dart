import 'package:core/platform.dart';
import 'package:planets/domain.dart';

/// Relationship-first navigation model for the TV Explore screen.
///
/// The solar system itself is the interface: D-pad presses move between
/// meaningful celestial objects derived from the planet catalogue, never
/// hardcoded into widgets.
///
/// - LEFT / RIGHT move within one level: among the primary bodies
///   (the Sun and the planets, in orbit-radius order) or among the moons
///   of one shared parent (in catalogue order).
/// - DOWN descends: a body with moons goes to its first moon; a moon goes
///   to its next sibling, so every moon stays reachable from the D-pad.
/// - UP ascends: a moon returns to its parent planet.
///
/// When there is no meaningful related object (UP from a planet, DOWN from
/// a moonless body, sideways at the edge of a single-moon family), [step]
/// returns null and the caller stays put: the remote must never jump to
/// unrelated UI just to make every press do something.
class TvDiscoveryGraph {
  TvDiscoveryGraph({
    required List<String> primaries,
    required Map<String, List<String>> childrenByParent,
    required Map<String, String?> parentById,
  }) : _primaries = List.unmodifiable(primaries),
       _childrenByParent = {
         for (final entry in childrenByParent.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       },
       _parentById = Map.unmodifiable(parentById);

  /// Builds the graph from the planet catalogue.
  ///
  /// Primaries (everything that is not a moon, the Sun included) are ordered
  /// by [Planet.orbitRadius] so LEFT / RIGHT follow the system outward from
  /// the Sun. Moons keep catalogue order within their parent.
  factory TvDiscoveryGraph.fromPlanets(List<Planet> planets) {
    final primaries = planets.where((p) => !p.isMoon).toList(growable: false)
      ..sort((a, b) => a.orbitRadius.compareTo(b.orbitRadius));
    final childrenByParent = <String, List<String>>{};
    final parentById = <String, String?>{};
    for (final planet in planets) {
      parentById[planet.id] = planet.parentPlanetId;
      final parent = planet.parentPlanetId;
      if (parent != null) {
        (childrenByParent[parent] ??= []).add(planet.id);
      }
    }
    return TvDiscoveryGraph(
      primaries: [for (final p in primaries) p.id],
      childrenByParent: childrenByParent,
      parentById: parentById,
    );
  }

  /// Fallback when no catalogue metadata is available (e.g. bare id lists):
  /// every id is a primary in the given order.
  factory TvDiscoveryGraph.fromIds(List<String> bodyIds) => TvDiscoveryGraph(
    primaries: bodyIds,
    childrenByParent: const {},
    parentById: {for (final id in bodyIds) id: null},
  );

  final List<String> _primaries;
  final Map<String, List<String>> _childrenByParent;
  final Map<String, String?> _parentById;

  /// Primary bodies in navigation order (Sun first, then outward).
  List<String> get primaries => _primaries;

  /// Parent planet of [id], or null for primaries and unknown ids.
  String? parentOf(String id) => _parentById[id];

  /// Moons of [parentId] in catalogue order, or empty when moonless.
  List<String> childrenOf(String parentId) =>
      _childrenByParent[parentId] ?? const [];

  /// Whether [id] is a known discovery target at all.
  bool knows(String id) =>
      _parentById.containsKey(id) || _primaries.contains(id);

  /// One D-pad step from [currentId]. Null means stay: no meaningful
  /// related object in that direction.
  String? step(String? currentId, TvRemoteKey direction) {
    if (_primaries.isEmpty) return null;
    switch (direction) {
      case TvRemoteKey.left:
        return _sideways(currentId, -1);
      case TvRemoteKey.right:
        return _sideways(currentId, 1);
      case TvRemoteKey.up:
        // A moon returns to its parent; primaries have nowhere to ascend.
        if (currentId == null) return null;
        return parentOf(currentId);
      case TvRemoteKey.down:
        if (currentId == null) return _primaries.first;
        // Descend into the first moon when there is one ...
        final children = childrenOf(currentId);
        if (children.isNotEmpty) return children.first;
        // ... otherwise keep walking a moon family so DOWN alone can tour
        // every sibling (Jupiter DOWN Io, DOWN Europa, ...).
        final parent = parentOf(currentId);
        if (parent == null) return null;
        return _sibling(currentId, parent, 1);
      case TvRemoteKey.center:
      case TvRemoteKey.back:
      case TvRemoteKey.playPause:
        return null;
    }
  }

  String? _sideways(String? currentId, int delta) {
    if (currentId == null) {
      return delta > 0 ? _primaries.first : _primaries.last;
    }
    final parent = parentOf(currentId);
    final lane = parent == null
        ? _primaries
        : (_childrenByParent[parent] ?? const []);
    if (lane.isEmpty) return null;
    var index = lane.indexOf(currentId);
    if (index < 0) return lane.first;
    final next = lane[(index + delta) % lane.length];
    // A lane of one would toggle the mark off (mark re-taps unmark), so a
    // lone moon's sideways press stays put instead of re-selecting itself.
    if (next == currentId) return null;
    return next;
  }

  String? _sibling(String currentId, String parent, int delta) {
    final siblings = _childrenByParent[parent] ?? const [];
    if (siblings.length < 2) return null;
    final index = siblings.indexOf(currentId);
    if (index < 0) return siblings.first;
    return siblings[(index + delta) % siblings.length];
  }
}
