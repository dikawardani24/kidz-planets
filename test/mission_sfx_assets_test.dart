import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/infrastructure/services/planet_sound_service.dart';

/// Minimal RIFF/WAVE reader so the test asserts the assets are really
/// decodable PCM audio, not just non-empty files.
class _Wave {
  const _Wave({
    required this.formatTag,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.duration,
  });

  final int formatTag;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final Duration duration;
}

_Wave _readWave(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);

  String tag(int offset) => ascii.decode(bytes.sublist(offset, offset + 4));

  // Index every RIFF chunk by id, recording where its body starts and how
  // long it is. "fmt " and "data" may appear in either order.
  final body = <String, int>{};
  final size = <String, int>{};

  var offset = 12; // Skip "RIFF" + chunk size + "WAVE".
  while (offset + 8 <= bytes.length) {
    final chunkId = tag(offset);
    final chunkSize = view.getUint32(offset + 4, Endian.little);
    body[chunkId] = offset + 8;
    size[chunkId] = chunkSize;
    // Chunks are word-aligned, so an odd size is followed by a pad byte.
    offset += 8 + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }

  expect(body, contains('fmt '), reason: 'WAV is missing its "fmt " chunk');
  expect(body, contains('data'), reason: 'WAV is missing its "data" chunk');

  final fmt = body['fmt ']!;
  final formatTag = view.getUint16(fmt, Endian.little);
  final channels = view.getUint16(fmt + 2, Endian.little);
  final sampleRate = view.getUint32(fmt + 4, Endian.little);
  final bitsPerSample = view.getUint16(fmt + 14, Endian.little);

  final frames = size['data']! ~/ (bitsPerSample ~/ 8 * channels);
  return _Wave(
    formatTag: formatTag,
    channels: channels,
    sampleRate: sampleRate,
    bitsPerSample: bitsPerSample,
    duration: Duration(microseconds: frames * 1000000 ~/ sampleRate),
  );
}

void main() {
  // RootBundle needs a binding to resolve the asset manifest.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mission catalog points at the mission sfx directory', () {
    expect(
      PlanetSoundCatalog.missionSuccess,
      'assets/audio/sfx/missions/mission_success.wav',
    );
    expect(
      PlanetSoundCatalog.missionFailure,
      'assets/audio/sfx/missions/mission_failure.wav',
    );
  });

  final sounds = {
    'success': PlanetSoundCatalog.missionSuccess,
    'failure': PlanetSoundCatalog.missionFailure,
  };

  for (final sound in sounds.entries) {
    test('mission ${sound.key} asset is present in the source tree', () {
      // Checked on disk rather than through RootBundle: `flutter test` serves
      // RootBundle from the generated build/unit_test_assets/ bundle, which
      // keeps serving files that have since been deleted from the tree.
      // Tests run with the package root as the working directory.
      final file = File(sound.value);
      expect(
        file.existsSync(),
        isTrue,
        reason: '${sound.value} is missing; regenerate or re-download it',
      );
      expect(file.lengthSync(), greaterThan(1024));
    });

    test('mission ${sound.key} asset is bundled and decodable', () async {
      // RootBundle is exactly what AudioPlayer.setAsset reads from, so a
      // missing pubspec asset entry or a wrong filename fails here.
      final data = await rootBundle.load(sound.value);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      expect(
        ascii.decode(bytes.sublist(0, 4)),
        'RIFF',
        reason: 'not a RIFF container: ${sound.value}',
      );
      expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');

      final wave = _readWave(bytes);
      expect(wave.formatTag, 1, reason: 'must be uncompressed PCM');
      expect(wave.channels, 1, reason: 'beds are mono');
      expect(wave.bitsPerSample, 16);
      // Matches the 24 kHz used by tool/generate_planet_sfx.py.
      expect(wave.sampleRate, 24000);

      // A one-shot that is silent or unbounded would be a bug in its own
      // right: missions replay these every time a planet is tapped.
      expect(
        wave.duration,
        greaterThanOrEqualTo(const Duration(milliseconds: 150)),
      );
      expect(wave.duration, lessThanOrEqualTo(const Duration(seconds: 2)));
    });
  }
}
