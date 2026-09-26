import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/entities/planet.dart';

/// Speaks short, kid-friendly facts for the selected solar-system body.
class PlanetTtsService {
  final FlutterTts _tts = FlutterTts();

  Future<void> speakPlanet(Planet planet) async {
    await speak(planet.name, planet.fact);
  }

  Future<void> speak(String title, String description) async {
    try {
      await _tts.stop();
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.08);
      await _tts.setVolume(1.0);
      await _tts.setLanguage('en-US');
      await _tts.speak('$title. $description');
    } catch (_) {
      // TTS is an enhancement; a missing/failed engine must not break the UI.
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> replay(Planet planet) => speakPlanet(planet);
}
