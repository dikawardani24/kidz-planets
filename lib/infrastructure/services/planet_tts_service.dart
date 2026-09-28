import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/entities/planet.dart';

/// Centralised speech tuning. Change these to restyle the whole app voice.
///
/// The target is a warm, enthusiastic guide for young listeners: a little
/// slower than a default narrator so words stay clear, and a touch higher in
/// pitch for energy — deliberately short of cartoonish.
class TtsVoiceProfile {
  const TtsVoiceProfile({
    this.language = 'en-US',
    this.speechRate = 0.40,
    this.pitch = 1.14,
    this.volume = 1.0,
  });

  final String language;
  final double speechRate;
  final double pitch;
  final double volume;
}

/// One voice as reported by the platform, reduced to the fields we score on.
class TtsVoiceCandidate {
  const TtsVoiceCandidate({required this.name, required this.locale, this.quality});

  final String name;
  final String locale;
  final String? quality;

  /// Substring of [voice] mapped to the shape `setVoice` expects.
  Map<String, String> toVoiceMap() => {'name': name, 'locale': locale};
}

/// Picks the most natural-sounding English voice the device actually offers.
///
/// Preference order, highest score first:
///  1. an en-US/en-GB voice advertising quality (Neural, Natural, Enhanced…)
///  2. any en-US voice
///  3. any other English voice
///
/// Returns null when the device exposes no English voice, so the caller can
/// fall back to the system default rather than guessing a name.
///
/// Accepts loosely typed entries on purpose: values that cross the platform
/// channel arrive as `Map<Object?, Object?>`, not `Map<String, dynamic>`.
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
  return best;
}

TtsVoiceCandidate? _readCandidate(Object? voice) {
  if (voice is! Map) return null;
  final name = voice['name'];
  final locale = voice['locale'];
  if (name is! String || locale is! String) return null;
  if (name.isEmpty || !_isEnglish(locale)) return null;
  final quality = voice['quality'];
  return TtsVoiceCandidate(
    name: name,
    locale: locale,
    quality: quality is String ? quality : null,
  );
}

bool _isEnglish(String locale) {
  final normalized = locale.toLowerCase().replaceAll('_', '-');
  return normalized == 'en' || normalized.startsWith('en-');
}

/// Name fragments that mark a voice as a modern, natural-sounding one.
/// Deliberately limited to quality words: matching on specific voice names
/// (a particular "Daniel" or "Karen") would be a device-specific guess and
/// would fight the locale preference below.
const _qualityMarkers = <String>[
  'neural',
  'natural',
  'enhanced',
  'premium',
  'siri',
];

/// Name fragments that mark a voice as low fidelity; heavily penalised so a
/// plain-but-solid voice always wins over a "Compact" or robotic one.
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

  var quality = 0;
  for (final marker in _qualityMarkers) {
    if (haystack.contains(marker)) {
      quality = 2;
      if (name.contains('neural') || name.contains('natural')) quality = 3;
      break;
    }
  }

  var score = quality * 10.0;
  score += switch (candidate.locale.toLowerCase().replaceAll('_', '-')) {
    'en-us' => 2.0,
    'en-gb' => 1.5,
    _ => 0.0,
  };

  for (final marker in _lowQualityMarkers) {
    if (name.contains(marker)) score -= 20;
  }
  return score;
}

/// Speaks kid-friendly narration for the selected solar-system body.
///
/// Every platform call is guarded: text-to-speech is an enhancement, and a
/// missing or failing engine must never break planet selection or the detail
/// sheet. Utterances are serialised through [_queue] and tagged with a
/// generation number, so rapidly switching planets can never leave two voices
/// talking over each other.
class PlanetTtsService {
  PlanetTtsService({FlutterTts? tts, this.profile = const TtsVoiceProfile()})
      : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final TtsVoiceProfile profile;

  /// Serialises stop → configure → speak so utterances never interleave.
  Future<void> _queue = Future<void>.value();

  /// Bumped by every request; an utterance whose generation is stale is
  /// dropped before it reaches the engine.
  int _generation = 0;
  bool _settingsApplied = false;

  /// Speaks the body overview, falling back to the on-screen fact when a
  /// body has no narration script yet.
  Future<void> speakPlanet(Planet planet) {
    return speak(planet.name, planet.narration ?? planet.fact);
  }

  /// Speaks a hotspot: its title first, then the conversational script.
  Future<void> speakHotspot(Hotspot hotspot) {
    return speak(hotspot.title, hotspot.narration ?? hotspot.description);
  }

  /// Speaks [title], then [description] as one utterance so the engine treats
  /// it as a single phrase and pauses naturally at the join.
  Future<void> speak(String title, String description) {
    final text = '$title. $description';
    return _enqueue(++_generation, text);
  }

  Future<void> replay(Planet planet) => speakPlanet(planet);

  /// Cancels the current utterance and invalidates anything still queued.
  Future<void> stop() {
    _generation++;
    return _enqueue(_generation, null);
  }

  Future<void> _enqueue(int generation, String? text) {
    _queue = _queue
        .then((_) => _run(generation, text))
        // A failed utterance must not poison the chain for the next one.
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

      await _tts.speak(text);
    } catch (_) {
      // Enhancement only — swallow engine errors so the UI keeps working.
    }
  }

  /// Applies each setting independently: platforms vary in what they support,
  /// and one rejected call must not prevent the others from taking effect.
  Future<void> _applySettings() async {
    await _guard(() => _tts.setSpeechRate(profile.speechRate));
    await _guard(() => _tts.setPitch(profile.pitch));
    await _guard(() => _tts.setVolume(profile.volume));
    await _guard(() => _tts.setLanguage(profile.language));

    final voice = await _pickVoiceMap();
    if (voice != null) await _guard(() => _tts.setVoice(voice));
  }

  /// Voice discovery is optional; a device that cannot list voices (or lists
  /// none in English) simply keeps its system default.
  Future<Map<String, String>?> _pickVoiceMap() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return null;
      return selectBestEnglishVoice(voices)?.toVoiceMap();
    } catch (_) {
      return null;
    }
  }

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Unsupported on this platform, or rejected by the engine.
    }
  }
}
