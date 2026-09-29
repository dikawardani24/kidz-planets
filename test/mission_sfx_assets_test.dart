import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/infrastructure/services/planet_sound_service.dart';

/// Sample rates MPEG-2 defines, indexed by the header's 2-bit rate field.
/// The cues are 24 kHz, so only that entry is expected to be referenced.
const _mpeg2Rates = [22050, 24000, 16000];

/// Bitrates in kbps for MPEG-2 Layer III, indexed by the header's 4-bit rate
/// field. Index 0 is "free" and 15 is "bad", so both are rejected.
const _mpeg2Layer3Bitrates = [
  0, 8, 16, 24, 32, 40, 48, 56, //
  64, 80, 96, 112, 128, 144, 160, 0,
];

/// Byte length of a leading ID3v2 tag, or 0 when the stream starts directly on
/// an MPEG frame. The size field is four synchsafe bytes, so it is not a plain
/// little-endian integer.
int _id3TagLength(Uint8List bytes) {
  final hasId3 =
      bytes.length > 10 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33;
  if (!hasId3) return 0;

  final tagSize = (bytes[6] & 0x7f) |
      ((bytes[7] & 0x7f) << 7) |
      ((bytes[8] & 0x7f) << 14) |
      ((bytes[9] & 0x7f) << 21);
  return 10 + tagSize;
}

/// A decoded MPEG stream: the format every frame agreed on, plus how long the
/// whole asset actually is.
class _Mp3Stream {
  const _Mp3Stream({
    required this.sampleRate,
    required this.channels,
    required this.bitrateKbps,
    required this.totalSamples,
  });

  final int sampleRate;
  final int channels;
  final int bitrateKbps;
  final int totalSamples;

  Duration get duration =>
      Duration(microseconds: totalSamples * 1000000 ~/ sampleRate);
}

/// Walks the MPEG frames in [bytes] and sums their sample counts, so the test
/// can assert the asset is really decodable audio of a sensible length rather
/// than a file that merely exists.
_Mp3Stream _readMp3(Uint8List bytes) {
  _Mp3Stream? first;
  var totalSamples = 0;
  var frames = 0;
  var offset = 0;

  offset += _id3TagLength(bytes);

  while (offset + 4 <= bytes.length) {
    final b0 = bytes[offset];
    final b1 = bytes[offset + 1];

    // Frame sync is 11 set bits.
    if (b0 != 0xff || (b1 & 0xe0) != 0xe0) {
      offset++;
      continue;
    }

    final b2 = bytes[offset + 2];
    final b3 = bytes[offset + 3];

    final versionBits = (b1 >> 3) & 0x03; // 3 = MPEG-1, 2 = MPEG-2
    final layerBits = (b1 >> 1) & 0x03; // 1 = Layer III
    final bitrateIndex = (b2 >> 4) & 0x0f;
    final rateIndex = (b2 >> 2) & 0x03;
    final padding = (b2 >> 1) & 0x01;
    final mode = (b3 >> 6) & 0x03; // 3 = mono

    if (versionBits != 2) {
      throw FormatException('expected MPEG-2, got version bits $versionBits');
    }
    if (layerBits != 1) {
      throw FormatException('expected Layer III, got layer bits $layerBits');
    }
    if (bitrateIndex == 0 || bitrateIndex == 15 || rateIndex == 3) {
      // Free-format or reserved; not something ffmpeg's libmp3lame emits.
      throw FormatException('frame is free-format or reserved at $offset');
    }

    final sampleRate = _mpeg2Rates[rateIndex];
    final bitrateKbps = _mpeg2Layer3Bitrates[bitrateIndex];
    // MPEG-2 Layer III always codes 576 samples per frame; the final frame is
    // zero-padded, which is why the exact duration comes from counting frames.
    const samplesPerFrame = 576;

    first ??= _Mp3Stream(
      sampleRate: sampleRate,
      channels: mode == 3 ? 1 : 2,
      bitrateKbps: bitrateKbps,
      totalSamples: 0,
    );
    expect(
      sampleRate,
      first.sampleRate,
      reason: 'sample rate changes mid-stream at byte $offset',
    );
    expect(
      first.channels,
      mode == 3 ? 1 : 2,
      reason: 'channel mode changes mid-stream at byte $offset',
    );

    final frameLength = 72 * bitrateKbps * 1000 ~/ sampleRate + padding;
    totalSamples += samplesPerFrame;
    frames++;
    offset += frameLength;
  }

  expect(frames, greaterThan(0), reason: 'no MPEG frames found');

  final header = first!;
  return _Mp3Stream(
    sampleRate: header.sampleRate,
    channels: header.channels,
    bitrateKbps: header.bitrateKbps,
    totalSamples: totalSamples,
  );
}

/// What a shipped mission cue is expected to be.
///
/// The two cues are deliberately different shapes: the success cue is a longer
/// stereo jingle that loops for as long as the celebration dialog is on screen,
/// and the failure cue is a short mono blip. Asserting one shape for both hid
/// a swapped or re-encoded asset, so each carries its own expectations.
class _Cue {
  const _Cue({
    required this.path,
    required this.channels,
    required this.bitrateKbps,
    required this.minDuration,
    required this.maxDuration,
  });

  final String path;
  final int channels;
  final int bitrateKbps;
  final Duration minDuration;
  final Duration maxDuration;
}

void main() {
  // RootBundle needs a binding to resolve the asset manifest.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mission catalog points at the mission sfx directory', () {
    expect(
      PlanetSoundCatalog.missionSuccess,
      'assets/audio/sfx/missions/mission_success.mp3',
    );
    expect(
      PlanetSoundCatalog.missionFailure,
      'assets/audio/sfx/missions/mission_failure.mp3',
    );
  });

  final sounds = {
    'success': _Cue(
      path: PlanetSoundCatalog.missionSuccess,
      channels: 2,
      bitrateKbps: 160,
      minDuration: const Duration(seconds: 3),
      maxDuration: const Duration(seconds: 5),
    ),
    'failure': _Cue(
      path: PlanetSoundCatalog.missionFailure,
      channels: 1,
      bitrateKbps: 96,
      minDuration: const Duration(milliseconds: 300),
      maxDuration: const Duration(milliseconds: 800),
    ),
  };

  for (final sound in sounds.entries) {
    test('mission ${sound.key} asset is present in the source tree', () {
      // Checked on disk rather than through RootBundle: `flutter test` serves
      // RootBundle from the generated build/unit_test_assets/ bundle, which
      // keeps serving files that have since been deleted from the tree.
      // Tests run with the package root as the working directory.
      final file = File(sound.value.path);
      expect(
        file.existsSync(),
        isTrue,
        reason: '${sound.value.path} is missing; regenerate or re-download it',
      );
      expect(file.lengthSync(), greaterThan(1024));
    });

    test('mission ${sound.key} asset is bundled and decodable', () async {
      // RootBundle is exactly what AudioPlayer.setAsset reads from, so a
      // missing pubspec asset entry or a wrong filename fails here.
      final data = await rootBundle.load(sound.value.path);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      // ffmpeg writes either a bare MPEG frame sync or an ID3v2 tag in front of
      // one. Compared as bytes because the sync word is not valid ASCII.
      final firstFrame = _id3TagLength(bytes) == 0 ? 0 : _id3TagLength(bytes);
      expect(
        bytes[firstFrame],
        0xff,
        reason: 'no MPEG frame sync in ${sound.value.path}',
      );
      expect(
        bytes[firstFrame + 1] & 0xe0,
        0xe0,
        reason: 'malformed MPEG sync word in ${sound.value.path}',
      );

      final stream = _readMp3(bytes);
      expect(stream.channels, sound.value.channels,
          reason: 'the shipped ${sound.key} cue is '
              '${sound.value.channels == 1 ? 'mono' : 'stereo'}');
      // Matches the 24 kHz used by the narration and by
      // tool/generate_planet_sfx.py, so the cue needs no resampling.
      expect(stream.sampleRate, 24000);
      expect(stream.bitrateKbps, sound.value.bitrateKbps);

      // A cue that is silent or unbounded would be a bug in its own right:
      // missions replay these every time a planet is tapped, and the success
      // cue loops until the celebration is dismissed. The tolerance is one
      // frame because the last frame is zero-padded to 576 samples.
      expect(stream.duration, greaterThanOrEqualTo(sound.value.minDuration));
      expect(stream.duration, lessThanOrEqualTo(sound.value.maxDuration));
    });
  }
}

