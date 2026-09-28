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
}

void main() {
  // AudioPlayer configures an audio_session channel in its constructor, so the
  // binding must exist even though every call is overridden below.
  TestWidgetsFlutterBinding.ensureInitialized();

  Planet byId(String id) => PlanetCatalog.planets.firstWhere((p) => p.id == id);

  final earth = byId('earth');
  final saturn = byId('saturn');

  test('plays the bundled mp3 asset', () async {
    final player = _FakePlayer();
    final service = PlanetNarrationService(player: player);

    await service.speakPlanet(earth);

    expect(player.played, ['assets/audio/narration/planets/earth.mp3']);
    await service.dispose();
  });

  test('hotspot narration uses the slugged asset path', () async {
    final player = _FakePlayer();
    final service = PlanetNarrationService(player: player);
    final hotspot = saturn.hotspots.first;

    await service.speakHotspot(hotspot);

    expect(
      player.played,
      [NarrationAudioCatalog.hotspot(hotspot.title)],
    );
    expect(player.played.single, startsWith('assets/audio/narration/hotspots/'));
    await service.dispose();
  });

  test('a missing asset does not throw and does not play', () async {
    final player = _FakePlayer(available: false);
    final service = PlanetNarrationService(player: player);

    await expectLater(service.speakPlanet(saturn), completes);
    expect(player.playCalls, 0);
    await service.dispose();
  });

  test('a newer selection is not overwritten by an older request', () async {
    final player = _FakePlayer();
    final service = PlanetNarrationService(player: player);

    final first = service.speakPlanet(earth);
    final second = service.speakPlanet(saturn);
    await Future.wait([first, second]);

    expect(player.played.last, 'assets/audio/narration/planets/saturn.mp3');
    await service.dispose();
  });

  test('stop halts the current narration', () async {
    final player = _FakePlayer();
    final service = PlanetNarrationService(player: player);

    await service.speakPlanet(earth);
    final playsBeforeStop = player.playCalls;
    final stopsBeforeStop = player.stopCalls;
    await service.stop();

    expect(player.playCalls, playsBeforeStop);
    expect(player.stopCalls, greaterThan(stopsBeforeStop));
    await service.dispose();
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
