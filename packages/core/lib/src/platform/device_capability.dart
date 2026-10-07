import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Capability tier of the device the app is running on.
///
/// Centralized device-capability decision (single point of truth): features
/// never branch on form factor or RAM themselves, they consume this tier.
/// In particular this is NOT `isTelevision`: a capable TV and a constrained
/// phone must each get the tier their hardware earns.
enum DeviceCapability {
  /// Full visual quality: full-resolution textures, everything preloaded.
  standard,

  /// Constrained hardware (e.g. a ~2 GB Android TV): same scenes, same
  /// content, same interactions — but large textures decode at a budgeted
  /// resolution so peak loading memory stays clear of the low-memory killer.
  constrained,
}

/// Device-capability classification and resolution.
///
/// RAM-based rather than form-factor-based: the ~2 GB Android TV lands in
/// [DeviceCapability.constrained] because of its memory, not because it is a
/// TV, and a constrained phone would land there the same way.
abstract final class DeviceCapabilityProbe {
  /// Devices at or below this total RAM are [DeviceCapability.constrained].
  ///
  /// 3 GiB (not 2): the TV reports ~2 GB total, of which Android, system
  /// services, the launcher and the graphics stack all take a share before
  /// Flutter allocates a byte. A 3 GB device running a 1080p+ UI with
  /// mipmapped 3D textures has the same headroom problem, so it shares the
  /// tier. Adjust only with device measurements, not theory.
  static const int constrainedBelowOrEqualBytes = 3 * 1024 * 1024 * 1024;

  /// Pure classification: total system RAM in, tier out. Unknown (`null`)
  /// fails open to [DeviceCapability.standard] — full quality stays the
  /// default and only measured-constrained devices step down.
  static DeviceCapability classify({required int? totalMemoryBytes}) {
    if (totalMemoryBytes != null &&
        totalMemoryBytes <= constrainedBelowOrEqualBytes) {
      return DeviceCapability.constrained;
    }
    return DeviceCapability.standard;
  }

  /// Parses the `MemTotal` line of a Linux `/proc/meminfo` dump into bytes.
  /// Returns `null` when the dump is missing or unparsable.
  static int? parseMemTotalBytes(String? meminfo) {
    if (meminfo == null) return null;
    final match = RegExp(
      r'^MemTotal:\s*(\d+)\s*kB',
      multiLine: true,
    ).firstMatch(meminfo);
    if (match == null) return null;
    final kb = int.tryParse(match.group(1)!);
    if (kb == null) return null;
    return kb * 1024;
  }

  /// Resolves this device's tier once. Never throws: any failure (non-Linux
  /// host, unreadable `/proc/meminfo`, unparsable content) yields
  /// [DeviceCapability.standard].
  ///
  /// [meminfoReader] is a test seam; production reads `/proc/meminfo`.
  static Future<DeviceCapability> resolve({
    Future<String?> Function()? meminfoReader,
  }) async {
    try {
      final text = await (meminfoReader ?? _readMeminfo)();
      return classify(totalMemoryBytes: parseMemTotalBytes(text));
    } catch (_) {
      return DeviceCapability.standard;
    }
  }

  static Future<String?> _readMeminfo() async {
    final file = File('/proc/meminfo');
    if (!await file.exists()) return null;
    return file.readAsString();
  }
}

/// This device's capability tier, resolved once and shared.
///
/// Read with `await ref.read(deviceCapabilityProvider.future)` from async
/// startup work (e.g. before the solar-system build) — never during a frame.
final deviceCapabilityProvider = FutureProvider<DeviceCapability>((ref) async {
  return DeviceCapabilityProbe.resolve();
});

/// Maximum texture decode width for a capability tier, in pixels.
///
/// Constrained devices decode 2K planet textures at 1024 wide (aspect
/// preserved, smaller images never upscaled): ~2 MB decoded instead of ~8 MB
/// per texture, ~2.7 MB of GPU+mips instead of ~10.7 MB — while mipmapping
/// keeps minified views identical. `null` means full resolution.
int? maxTextureDecodeWidthFor(DeviceCapability capability) =>
    switch (capability) {
      DeviceCapability.standard => null,
      DeviceCapability.constrained => 1024,
    };
