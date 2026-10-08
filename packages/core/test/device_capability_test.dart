import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:core/platform.dart';

void main() {
  group('DeviceCapabilityProbe.classify', () {
    test('2 GB TV is constrained', () {
      expect(
        DeviceCapabilityProbe.classify(
          totalMemoryBytes: 2 * 1024 * 1024 * 1024,
        ),
        DeviceCapability.constrained,
      );
    });

    test('3 GB boundary device is constrained', () {
      expect(
        DeviceCapabilityProbe.classify(
          totalMemoryBytes:
              DeviceCapabilityProbe.constrainedBelowOrEqualBytes,
        ),
        DeviceCapability.constrained,
      );
    });

    test('4 GB phone is standard', () {
      expect(
        DeviceCapabilityProbe.classify(
          totalMemoryBytes: 4 * 1024 * 1024 * 1024,
        ),
        DeviceCapability.standard,
      );
    });

    test('unknown memory fails open to standard (full quality default)', () {
      expect(
        DeviceCapabilityProbe.classify(totalMemoryBytes: null),
        DeviceCapability.standard,
      );
    });
  });

  group('DeviceCapabilityProbe.parseMemTotalBytes', () {
    test('parses a real /proc/meminfo MemTotal line', () {
      const meminfo =
          'MemTotal:        1923456 kB\n'
          'MemFree:          123456 kB\n';
      expect(
        DeviceCapabilityProbe.parseMemTotalBytes(meminfo),
        1923456 * 1024,
      );
    });

    test('returns null for missing or garbage input', () {
      expect(DeviceCapabilityProbe.parseMemTotalBytes(null), isNull);
      expect(DeviceCapabilityProbe.parseMemTotalBytes(''), isNull);
      expect(
        DeviceCapabilityProbe.parseMemTotalBytes('MemFree: 1 kB\n'),
        isNull,
      );
    });
  });

  group('DeviceCapabilityProbe.resolve', () {
    test('2 GB meminfo resolves constrained', () async {
      final capability = await DeviceCapabilityProbe.resolve(
        meminfoReader: () async => 'MemTotal:        2000000 kB\n',
      );
      expect(capability, DeviceCapability.constrained);
    });

    test('8 GB meminfo resolves standard', () async {
      final capability = await DeviceCapabilityProbe.resolve(
        meminfoReader: () async => 'MemTotal:        8000000 kB\n',
      );
      expect(capability, DeviceCapability.standard);
    });

    test('reader failure resolves standard, never throws', () async {
      final capability = await DeviceCapabilityProbe.resolve(
        meminfoReader: () async => throw const FileSystemException(),
      );
      expect(capability, DeviceCapability.standard);
    });
  });

  group('maxTextureDecodeWidthFor', () {
    test('standard keeps full resolution', () {
      expect(
        maxTextureDecodeWidthFor(DeviceCapability.standard),
        isNull,
      );
    });

    test('constrained budgets to 1024 wide', () {
      expect(
        maxTextureDecodeWidthFor(DeviceCapability.constrained),
        1024,
      );
    });
  });
}
