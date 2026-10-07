import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';

/// Async texture cache (SRP: texture fetching only).
///
/// Uses [Texture2D.fromAsset] directly, so planet JPG/PNG textures load
/// without the `buildTextures` / `.fstex` pipeline — zero extra setup,
/// hot-reload friendly.
abstract class TextureProvider {
  /// The texture for [assetPath], loaded at most once.
  ///
  /// Concurrent callers for the same asset share one load: caching the
  /// [Future] rather than the finished texture is what makes two bodies asking
  /// for the same image at the same moment produce one upload.
  Future<TextureSource> get(String assetPath);

  /// How many assets are currently resident, for diagnostics and tests.
  int get cachedCount;

  void dispose();
}

/// In-memory cache over [Texture2D.fromAsset] (ISP: narrow interface).
///
/// Lives for as long as the scene controller, which is why a warm start is warm:
/// the second run of the app finds these futures already completed instead of
/// decoding eight megabytes of planets again.
///
/// [maxDecodeWidth] budgets the decode for constrained devices: when set,
/// images wider than it decode scaled down to it (aspect preserved, smaller
/// images never upscaled) through the same mipmapped [Texture2D.fromImage]
/// path. A 2048-wide planet texture becomes ~2 MB decoded / ~2.7 MB of
/// GPU+mips instead of ~8 MB / ~10.7 MB. Set it before the first [get] — it
/// is part of the cache key contract, not a runtime dial.
class AssetTextureProvider implements TextureProvider {
  AssetTextureProvider({this.maxDecodeWidth});

  int? maxDecodeWidth;

  final Map<String, Future<TextureSource>> _cache = {};

  @override
  Future<TextureSource> get(String assetPath) {
    return _cache.putIfAbsent(assetPath, () => _load(assetPath));
  }

  Future<TextureSource> _load(String assetPath) {
    final maxWidth = maxDecodeWidth;
    if (maxWidth == null) return Texture2D.fromAsset(assetPath);
    return _loadBudgeted(assetPath, maxWidth);
  }

  /// Same result as [Texture2D.fromAsset] with a capped decode width.
  ///
  /// Mirrors `Texture2D.fromAsset` step for step (bundle load → decode →
  /// mipmapped upload → release the decoded image) so budgeted textures carry
  /// the identical sampling and mip chain as full-resolution ones.
  static Future<TextureSource> _loadBudgeted(
    String assetPath,
    int maxWidth,
  ) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final image = await imageFromBytes(bytes, maxWidth: maxWidth);
    try {
      return await Texture2D.fromImage(image);
    } finally {
      image.dispose();
    }
  }

  @override
  int get cachedCount => _cache.length;

  @override
  void dispose() => _cache.clear();
}