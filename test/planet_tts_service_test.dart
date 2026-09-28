import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/data/datasources/planet_catalog.dart';
import 'package:kidz_planets/domain/entities/planet.dart';
import 'package:kidz_planets/infrastructure/services/planet_tts_service.dart';

Map<String, dynamic> voice(String name, String locale, {String? quality}) =>
    {'name': name, 'locale': locale, 'quality': ?quality};

TtsVoiceCandidate? select(List<Object?> voices) => selectBestEnglishVoice(voices);

void main() {
  // Needed to install mock handlers on the flutter_tts platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('voice selection priority', () {
    test('prefers a neural en-US voice over everything else', () {
      final picked = select([
        voice('Alex', 'en-US'),
        voice('Daniel (Neural)', 'en-GB'),
        voice('Aria (Neural)', 'en-US'),
        voice('Karen', 'en-AU'),
      ]);
      expect(picked?.name, 'Aria (Neural)');
    });

    test('prefers an enhanced en-GB voice over a plain en-GB voice', () {
      final picked = select([
        voice('Daniel', 'en-GB'),
        voice('Serena (Enhanced)', 'en-GB'),
      ]);
      expect(picked?.name, 'Serena (Enhanced)');
    });

    test('falls back to en-US when no quality voice exists', () {
      final picked = select([
        voice('Karen', 'en-AU'),
        voice('Samantha', 'en-US'),
      ]);
      expect(picked?.name, 'Samantha');
    });

    test('accepts any English voice when there is no en-US', () {
      final picked = select([
        voice('Karen', 'en-AU'),
        voice('Rishi', 'en-IN'),
        voice('Lotta', 'sv-SE'),
      ]);
      // No US/GB voice exists, so it must still land on an English one
      // rather than returning null or grabbing the Swedish voice.
      expect(picked?.locale, 'en-AU');
    });

    test('prefers a quality voice even when no en-US or en-GB exists', () {
      final picked = select([
        voice('Rishi', 'en-IN'),
        voice('Karen (Natural)', 'en-AU'),
      ]);
      expect(picked?.name, 'Karen (Natural)');
    });

    test('uses the iOS quality field when the name has no marker', () {
      final picked = select([
        voice('Moira', 'en-IE'),
        voice('Fiona', 'en-IE', quality: 'enhanced'),
      ]);
      expect(picked?.name, 'Fiona');
    });

    test('shunns low-fidelity voices even when they are en-US', () {
      final picked = select([
        voice('Google US English (Compact)', 'en-US'),
        voice('Samantha', 'en-US'),
      ]);
      expect(picked?.name, 'Samantha');
    });

    test('ignores non-English voices entirely', () {
      final picked = select([
        voice('Thomas', 'fr-FR'),
        voice('Anna', 'de-DE'),
        voice('Kyoko', 'ja-JP'),
      ]);
      expect(picked, isNull);
    });

    test('returns null when the device exposes no voices', () {
      expect(select([]), isNull);
    });

    test('ignores malformed entries instead of throwing', () {
      final picked = select([
        {'name': 'NoLocale'},
        {'locale': 'en-US'},
        {'name': 42, 'locale': 'en-US'},
        {'name': '', 'locale': 'en-US'},
        voice('Samantha', 'en-US'),
      ]);
      expect(picked?.name, 'Samantha');
    });

    test('accepts underscore locale separators', () {
      final picked = select([voice('Samantha', 'en_US')]);
      expect(picked?.locale, 'en_US');
    });

    test('voice map carries the name and locale the plugin expects', () {
      final picked = select([voice('Aria (Neural)', 'en-US')]);
      expect(picked?.toVoiceMap(), {'name': 'Aria (Neural)', 'locale': 'en-US'});
    });
  });

  group('narration content', () {
    test('every body has its own narration, distinct from the on-screen fact', () {
      final bodies = PlanetCatalog.planets;
      expect(bodies.length, 9);

      final scripts = <String>{};
      for (final planet in bodies) {
        final narration = planet.narration;
        expect(narration, isNotNull, reason: '${planet.id} has no narration');
        expect(narration, isNotEmpty);
        expect(narration, isNot(planet.fact),
            reason: '${planet.id} would read the raw on-screen fact');
        scripts.add(narration!);
      }
      // Each body reads differently, so no copy-paste duplicates.
      expect(scripts.length, bodies.length);
    });

    test('every hotspot has narration distinct from its description', () {
      for (final planet in PlanetCatalog.planets) {
        for (final hotspot in planet.hotspots) {
          expect(hotspot.narration, isNotNull,
              reason: '${planet.id}/${hotspot.title} has no narration');
          expect(hotspot.narration, isNot(hotspot.description));
        }
      }
    });

    test('narration avoids runaway exclamation marks', () {
      for (final planet in PlanetCatalog.planets) {
        var text = '${planet.narration}';
        for (final hotspot in planet.hotspots) {
          text += ' ${hotspot.narration}';
        }
        expect(RegExp('!').allMatches(text).length, lessThanOrEqualTo(3),
            reason: '${planet.id} over-uses exclamation marks');
      }
    });

    test('narration uses short sentences', () {
      for (final planet in PlanetCatalog.planets) {
        final longest = planet.narration!
            .split(RegExp(r'(?<=[.!?])\s+'))
            .map((s) => s.length)
            .reduce((a, b) => a > b ? a : b);
        expect(longest, lessThan(150),
            reason: '${planet.id} has a sentence that will drag in the ear');
      }
    });

    test('narration spells out numbers and symbols TTS mangles', () {
      for (final planet in PlanetCatalog.planets) {
        var text = '${planet.narration}';
        for (final hotspot in planet.hotspots) {
          text += ' ${hotspot.narration}';
        }
        // Digits and % are read inconsistently across engines ("15" can come
        // out as "fifteen" or "one five"), so the scripts spell them out.
        expect(text, isNot(matches(RegExp(r'\d'))),
            reason: '${planet.id} narration contains a digit');
        expect(text, isNot(contains('%')),
            reason: '${planet.id} narration contains a percent sign');
      }
    });
  });

  group('graceful degradation', () {
    test('speaking without a TTS engine never throws', () async {
      // No mock handler is installed, so every platform call fails.
      final service = PlanetTtsService();
      final earth = PlanetCatalog.planets.firstWhere((p) => p.id == 'earth');

      await expectLater(service.speakPlanet(earth), completes);
      await expectLater(service.speakHotspot(earth.hotspots.first), completes);
      await expectLater(service.replay(earth), completes);
      await expectLater(service.stop(), completes);
    });

    test('a body without narration still speaks its on-screen fact', () async {
      final spoken = <String>[];
      final channel = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      channel.setMockMethodCallHandler(const MethodChannel('flutter_tts'),
          (call) async {
        if (call.method == 'getVoices') return <Map<String, dynamic>>[];
        if (call.method == 'speak') spoken.add(call.arguments as String);
        return null;
      });
      addTearDown(
          () => channel.setMockMethodCallHandler(const MethodChannel('flutter_tts'), null));

      const bare = Planet(
        id: 'pluto',
        name: 'Pluto',
        tag: 'Dwarf',
        fact: 'Pluto is a tiny icy dwarf planet.',
        radius: 1,
        orbitRadius: 1,
        orbitSpeed: 1,
        startAngle: 0,
        colorValue: 0xFFFFFFFF,
        tiltDegrees: 0,
        textureAsset: 'assets/textures/sun.jpg',
        diameter: '2377 km',
        temperature: '-229C',
        dayLength: '6.4 days',
        hotspots: [],
      );

      await PlanetTtsService().speakPlanet(bare);
      expect(spoken.single, 'Pluto. Pluto is a tiny icy dwarf planet.');
    });
  });

  group('no overlapping narration', () {
    late List<String> calls;
    late TestDefaultBinaryMessenger messenger;

    setUp(() {
      calls = [];
      messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'),
          (call) async {
        calls.add(call.method);
        if (call.method == 'getVoices') return <Map<String, dynamic>>[];
        if (call.method == 'speak') {
          calls.add('speak:${call.arguments}');
        }
        return null;
      });
    });

    tearDown(() =>
        messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), null));

    /// Speaks of the engine, ignoring the parameter-setting calls.
    List<String> utterances() =>
        calls.where((c) => c.startsWith('speak:')).toList();

    test('rapid planet switching only lets the last selection speak', () async {
      final service = PlanetTtsService();
      final byId = {for (final p in PlanetCatalog.planets) p.id: p};

      // Fire without awaiting, the way a fast tapper triggers it. Awaiting
      // only the last one drains the queue without cancelling it.
      unawaited(service.speakPlanet(byId['mars']!));
      unawaited(service.speakPlanet(byId['jupiter']!));
      await service.speakPlanet(byId['saturn']!);

      expect(utterances(), hasLength(1));
      expect(utterances().single, contains('Look at Saturn!'));
    });

    test('each utterance is preceded by a stop, never overlapping', () async {
      final service = PlanetTtsService();
      final byId = {for (final p in PlanetCatalog.planets) p.id: p};

      unawaited(service.speakPlanet(byId['venus']!));
      await service.speakPlanet(byId['earth']!);

      // A speak must never be immediately followed by another speak: the
      // engine is only ever driven stop → speak → stop → speak.
      for (var i = 0; i < calls.length - 1; i++) {
        if (calls[i].startsWith('speak:')) {
          expect(calls[i + 1], 'stop',
              reason: 'a new utterance started before the old one was stopped');
        }
      }
    });

    test('settings are configured once, not on every utterance', () async {
      final service = PlanetTtsService();
      final byId = {for (final p in PlanetCatalog.planets) p.id: p};

      unawaited(service.speakPlanet(byId['earth']!));
      await service.speakPlanet(byId['mars']!);

      expect(calls.where((c) => c == 'setLanguage'), hasLength(1));
      expect(calls.where((c) => c == 'setSpeechRate'), hasLength(1));
    });

    test('closing the detail cancels a pending utterance', () async {
      final service = PlanetTtsService();
      final byId = {for (final p in PlanetCatalog.planets) p.id: p};

      unawaited(service.speakPlanet(byId['saturn']!));
      await service.stop();

      expect(utterances(), isEmpty);
    });

    test('a requested voice is applied when the device offers one', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final applied = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'),
          (call) async {
        if (call.method == 'getVoices') {
          return [
            voice('Samantha', 'en-US'),
            voice('Aria (Neural)', 'en-US'),
          ];
        }
        if (call.method == 'setVoice') applied.add(call.arguments as Map);
        return null;
      });
      addTearDown(() =>
          messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), null));

      final service = PlanetTtsService();
      await service.speak('Hello', 'Welcome to space.');

      expect(applied.single, {'name': 'Aria (Neural)', 'locale': 'en-US'});
    });

    test('speaks normally when the device lists no English voice', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final spoken = <String>[];
      final setVoiceCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'),
          (call) async {
        if (call.method == 'getVoices') {
          return [voice('Thomas', 'fr-FR'), voice('Kyoko', 'ja-JP')];
        }
        if (call.method == 'setVoice') setVoiceCalls.add(call);
        if (call.method == 'speak') spoken.add(call.arguments as String);
        return null;
      });
      addTearDown(() =>
          messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), null));

      final service = PlanetTtsService();
      await service.speak('Hello', 'Welcome to space.');

      // No voice override, but narration still happens.
      expect(setVoiceCalls, isEmpty);
      expect(spoken.single, 'Hello. Welcome to space.');
    });

    test('a setVoice rejection does not block the remaining settings', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final seen = <String>[];
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'),
          (call) async {
        seen.add(call.method);
        if (call.method == 'getVoices') {
          return [voice('Aria (Neural)', 'en-US')];
        }
        if (call.method == 'setVoice') {
          throw PlatformException(code: 'unsupported');
        }
        if (call.method == 'speak') seen.add('SPOKE');
        return null;
      });
      addTearDown(() =>
          messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), null));

      await PlanetTtsService().speak('Hello', 'Welcome to space.');

      expect(seen, contains('setLanguage'));
      expect(seen, contains('SPOKE'));
    });
  });
}
