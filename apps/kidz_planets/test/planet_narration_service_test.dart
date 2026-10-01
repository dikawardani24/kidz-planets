import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kidz_planets/data/datasources/planet_catalog.dart';
import 'package:kidz_planets/domain/entities/planet.dart';
import 'package:kidz_planets/infrastructure/services/planet_narration_service.dart';

class _FakePlayer extends AudioPlayer {
  _FakePlayer({this.available = true});

  final bool available;
  final List<String> loaded = [];
  final List<String> played = [];
  int playCalls = 0;
  int stopCalls = 0;

  @override
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async {
    if (!available) {
      throw StateError('Asset not found: $assetPath');
    }
    loaded.add(assetPath);
    return const Duration(milliseconds: 100);
  }

  @override
  Future<void> play() async {
    playCalls++;
    played.add(loaded.isEmpty ? '<none>' : loaded.last);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  // The crossfade ramps the volume on every step, and dispose tears the player
  // down. Both would otherwise reach the real plugin, which is absent here and
  // whose MissingPluginException the service catches and swallows, which is
  // exactly what these tests must not be able to hide behind.
  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}

/// A service whose whole crossfade pair is fake, plus the players it built.
///
/// Both players are recorded so a test can assert on them together, and so a
/// regression back to one real player in the pair shows up as a missing
/// recording rather than as a silently swallowed exception.
({PlanetNarrationService service, List<_FakePlayer> players}) _buildService({
  bool available = true,
}) {
  final players = <_FakePlayer>[];
  final service = PlanetNarrationService(
    playerFactory: () {
      final player = _FakePlayer(available: available);
      players.add(player);
      return player;
    },
  );
  return (service: service, players: players);
}

List<String> _playedAcross(Iterable<_FakePlayer> players) => [
      for (final player in players) ...player.played,
    ];

int _total(Iterable<_FakePlayer> players, int Function(_FakePlayer) read) =>
    players.map(read).fold(0, (a, b) => a + b);

void main() {
  // AudioPlayer configures an audio_session channel in its constructor, so the
  // binding must exist even though every call is overridden below.
  TestWidgetsFlutterBinding.ensureInitialized();

  Planet byId(String id) => PlanetCatalog.planets.firstWhere((p) => p.id == id);

  final earth = byId('earth');
  final saturn = byId('saturn');

  test('builds a pair of substitutable players, so nothing escapes to the '
      'platform', () {
    final harness = _buildService();
    expect(
      harness.players,
      hasLength(2),
      reason: 'a single injected player would leave a real AudioPlayer in the '
          'crossfade pair and the service would swallow its errors',
    );
  });

  test('plays the bundled mp3 asset', () async {
    final harness = _buildService();

    await harness.service.speakPlanet(earth);

    expect(_playedAcross(harness.players), [
      'assets/audio/narration/planets/earth.mp3',
    ]);
    await harness.service.dispose();
  });

  test('hotspot narration uses the slugged asset path', () async {
    final harness = _buildService();
    final hotspot = saturn.hotspots.first;

    await harness.service.speakHotspot(hotspot);

    expect(
      _playedAcross(harness.players),
      [NarrationAudioCatalog.hotspot(hotspot.title)],
    );
    expect(
      _playedAcross(harness.players).single,
      startsWith('assets/audio/narration/hotspots/'),
    );
    await harness.service.dispose();
  });

  test('a missing asset does not throw and does not play', () async {
    final harness = _buildService(available: false);

    await expectLater(harness.service.speakPlanet(saturn), completes);
    expect(_total(harness.players, (p) => p.playCalls), 0);
    await harness.service.dispose();
  });

  test('a newer selection is not overwritten by an older request', () async {
    final harness = _buildService();

    final first = harness.service.speakPlanet(earth);
    final second = harness.service.speakPlanet(saturn);
    await Future.wait([first, second]);

    // The first request is superseded mid-flight, so only the newer one ever
    // reaches play(): the abandoned planet must not be the last thing heard.
    expect(_playedAcross(harness.players).last,
        'assets/audio/narration/planets/saturn.mp3');
    await harness.service.dispose();
  });

  test('a superseded request never loads its asset either', () async {
    final harness = _buildService();

    await Future.wait([
      harness.service.speakPlanet(earth),
      harness.service.speakPlanet(saturn),
    ]);

    expect(
      [
        for (final player in harness.players) ...player.loaded,
      ],
      ['assets/audio/narration/planets/saturn.mp3'],
    );
    await harness.service.dispose();
  });

  test('stop halts the current narration', () async {
    final harness = _buildService();

    await harness.service.speakPlanet(earth);
    final playsBeforeStop = _total(harness.players, (p) => p.playCalls);
    final stopsBeforeStop = _total(harness.players, (p) => p.stopCalls);

    await harness.service.stop();

    expect(_total(harness.players, (p) => p.playCalls), playsBeforeStop);
    expect(_total(harness.players, (p) => p.stopCalls), greaterThan(stopsBeforeStop));
    await harness.service.dispose();
  });

  test('asset slugs match the generator naming convention', () {
    expect(
      NarrationAudioCatalog.planet('saturn'),
      'assets/audio/narration/planets/saturn.mp3',
    );
    expect(
      NarrationAudioCatalog.hotspot('Great Red Spot'),
      'assets/audio/narration/hotspots/great_red_spot.mp3',
    );
    expect(
      NarrationAudioCatalog.hotspot('79+ Moons'),
      'assets/audio/narration/hotspots/79_moons.mp3',
    );
  });
}
