import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kidz_planets/data/datasources/planet_catalog.dart';
import 'package:kidz_planets/domain/entities/planet.dart';
import 'package:kidz_planets/infrastructure/services/planet_narration_service.dart';
import 'package:kidz_planets/infrastructure/services/planet_tts_service.dart';

class _FakePlayer extends AudioPlayer {
  _FakePlayer({this.available = true});

  final bool available;
  final List<String> loaded = [];
  final List<String> played = [];
  int playCalls = 0;

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
  Future<void> stop() async {}
}

class _RecordingTts extends PlanetTtsService {
  final List<String> spoken = [];
  int stopCalls = 0;

  @override
  Future<void> speakPlanet(Planet planet) async {
    spoken.add('planet:${planet.id}');
  }

  @override
  Future<void> speakHotspot(Hotspot hotspot) async {
    spoken.add('hotspot:${hotspot.title}');
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

void main() {
  // PlanetTtsService constructs a real FlutterTts, which registers a method
  // call handler and therefore needs the binding to exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  Planet byId(String id) => PlanetCatalog.planets.firstWhere((p) => p.id == id);

  final earth = byId('earth');
  final saturn = byId('saturn');

  test('plays the bundled mp3 instead of device tts when available', () async {
    final player = _FakePlayer();
    final tts = _RecordingTts();
    final service = PlanetNarrationService(player: player, fallback: tts);

    await service.speakPlanet(earth);

    expect(
      player.played,
      ['assets/audio/narration/planets/earth.mp3'],
    );
    expect(tts.spoken, isEmpty);
    await service.dispose();
  });

  test('falls back to device tts when the mp3 cannot be loaded', () async {
    final player = _FakePlayer(available: false);
    final tts = _RecordingTts();
    final service = PlanetNarrationService(player: player, fallback: tts);

    await service.speakPlanet(saturn);

    expect(player.playCalls, 0);
    expect(tts.spoken, ['planet:saturn']);
    await service.dispose();
  });

  test('hotspot slugs match the generator naming convention', () {
    expect(
      NarrationAudioCatalog.hotspot('Great Red Spot'),
      'assets/audio/narration/hotspots/great_red_spot.mp3',
    );
    expect(
      NarrationAudioCatalog.hotspot('79+ Moons'),
      'assets/audio/narration/hotspots/79_moons.mp3',
    );
  });

  test('a newer selection is not overwritten by an older request', () async {
    final player = _FakePlayer();
    final tts = _RecordingTts();
    final service = PlanetNarrationService(player: player, fallback: tts);

    final first = service.speakPlanet(earth);
    final second = service.speakPlanet(saturn);
    await Future.wait([first, second]);

    expect(player.played.last, 'assets/audio/narration/planets/saturn.mp3');
    await service.dispose();
  });

  test('stop halts narration and prevents later playback', () async {
    final player = _FakePlayer();
    final tts = _RecordingTts();
    final service = PlanetNarrationService(player: player, fallback: tts);

    await service.speakPlanet(earth);
    final playsBeforeStop = player.playCalls;
    await service.stop();

    expect(player.playCalls, playsBeforeStop);
    expect(tts.stopCalls, greaterThan(0));
    await service.dispose();
  });
}
