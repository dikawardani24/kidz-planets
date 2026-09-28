import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/entities/planet.dart';

/// Centralised speech tuning for the Kidz Planets guide.
class TtsVoiceProfile {
  const TtsVoiceProfile({
    this.language = 'en-US',
    this.speechRate = 0.44,
    this.pitch = 1.04,
    this.volume = 1.0,
  });

  final String language;
  final double speechRate;
  final double pitch;
  final double volume;
}

class TtsVoiceCandidate {
  const TtsVoiceCandidate({
    required this.name,
    required this.locale,
    this.quality,
    this.latency,
    this.networkRequired,
  });

  final String name;
  final String locale;
  final String? quality;
  final int? latency;
  final bool? networkRequired;

  Map<String, String> toVoiceMap() => {'name': name, 'locale': locale};
}

/// Selects an English voice only when the platform gives us evidence that it
/// is higher quality. Network-backed does not automatically mean natural.
TtsVoiceCandidate? selectBestEnglishVoice(Iterable<Object?> voices) {
  TtsVoiceCandidate? best;
  var bestScore = double.negativeInfinity;

  for (final voice in voices) {
    final candidate = _readCandidate(voice);
    if (candidate == null) continue;

    final score = _score(candidate);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }

  return bestScore >= 30 ? best : null;
}

TtsVoiceCandidate? _readCandidate(Object? voice) {
  if (voice is! Map) return null;

  final name = voice['name'];
  final locale = voice['locale'];

  if (name is! String || locale is! String) return null;
  if (name.isEmpty || !_isEnglish(locale)) return null;

  final quality = voice['quality'];
  final latency = voice['latency'];
  final networkRequired = voice['network_required'];

  return TtsVoiceCandidate(
    name: name,
    locale: locale,
    quality: quality?.toString(),
    latency: latency is num ? latency.toInt() : null,
    networkRequired: networkRequired is bool ? networkRequired : null,
  );
}

bool _isEnglish(String locale) {
  final normalized = locale.toLowerCase().replaceAll('_', '-');
  return normalized == 'en' || normalized.startsWith('en-');
}

const _qualityMarkers = <String>[
  'neural',
  'natural',
  'enhanced',
  'premium',
];

const _lowQualityMarkers = <String>[
  'compact',
  'eloquence',
  'espeak',
  'pico',
  'whisper',
];

double _score(TtsVoiceCandidate candidate) {
  final name = candidate.name.toLowerCase();
  final haystack = '$name ${candidate.quality?.toLowerCase() ?? ''}';

  var score = 0.0;

  for (final marker in _qualityMarkers) {
    if (haystack.contains(marker)) {
      score += 35;
      break;
    }
  }

  final numericQuality = int.tryParse(candidate.quality ?? '');
  if (numericQuality != null) {
    score += (numericQuality / 10).clamp(0.0, 50.0);
  }

  switch (candidate.locale.toLowerCase().replaceAll('_', '-')) {
    case 'en-us':
      score += 8;
    case 'en-gb':
      score += 5;
  }

  for (final marker in _lowQualityMarkers) {
    if (name.contains(marker)) score -= 50;
  }

  return score;
}

/// Kid-friendly speech service.
///
/// Dedicated narration is spoken without repeating the UI title. For example,
/// the screen can show "Saturn" while the voice starts with "Look at Saturn!"
/// instead of saying "Saturn. Look at Saturn!".
class PlanetTtsService {
  PlanetTtsService({
    FlutterTts? tts,
    this.profile = const TtsVoiceProfile(),
  }) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final TtsVoiceProfile profile;

  Future<void> _queue = Future<void>.value();
  int _generation = 0;
  bool _settingsApplied = false;

  Future<void> speakPlanet(Planet planet) {
    final narration = planet.narration;
    if (narration != null && narration.trim().isNotEmpty) {
      return speakNarration(narration);
    }

    return speakNarration('${planet.name}. ${planet.fact}');
  }

  Future<void> speakHotspot(Hotspot hotspot) {
    final narration = hotspot.narration;
    if (narration != null && narration.trim().isNotEmpty) {
      return speakNarration(narration);
    }

    return speakNarration('${hotspot.title}. ${hotspot.description}');
  }

  Future<void> speakNarration(String narration) {
    final text = _prepareNarration(narration);
    return _enqueue(++_generation, text);
  }

  Future<void> speak(String title, String description) {
    return speakNarration('$title. $description');
  }

  Future<void> replay(Planet planet) => speakPlanet(planet);

  Future<void> stop() {
    _generation++;
    return _enqueue(_generation, null);
  }

  Future<void> _enqueue(int generation, String? text) {
    _queue = _queue
        .then((_) => _run(generation, text))
        .catchError((Object _) {});
    return _queue;
  }

  Future<void> _run(int generation, String? text) async {
    try {
      await _tts.stop();
      if (text == null || generation != _generation) return;

      if (!_settingsApplied) {
        _settingsApplied = true;
        await _applySettings();
        if (generation != _generation) return;
      }

      await _guard(() => _tts.awaitSpeakCompletion(true));
      if (generation != _generation) return;

      await _tts.speak(text);
    } catch (_) {
      // TTS is an enhancement. Never let an engine failure break exploration.
    }
  }

  Future<void> _applySettings() async {
    await _guard(() => _tts.setSpeechRate(profile.speechRate));
    await _guard(() => _tts.setPitch(profile.pitch));
    await _guard(() => _tts.setVolume(profile.volume));
    await _guard(() => _tts.setLanguage(profile.language));

    final voice = await _pickVoiceMap();
    if (voice != null) {
      await _guard(() => _tts.setVoice(voice));
    }
  }

  Future<Map<String, String>?> _pickVoiceMap() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return null;

      return selectBestEnglishVoice(voices)?.toVoiceMap();
    } catch (_) {
      return null;
    }
  }

  String _prepareNarration(String value) {
    return value
        .replaceAll('—', ', ')
        .replaceAll('–', ', ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Unsupported on this platform, or rejected by the engine.
    }
  }
}
