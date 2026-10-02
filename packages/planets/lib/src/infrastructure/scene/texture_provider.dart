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
class AssetTextureProvider implements TextureProvider {
  final Map<String, Future<TextureSource>> _cache = {};

  @override
  Future<TextureSource> get(String assetPath) {
    return _cache.putIfAbsent(assetPath, () => Texture2D.fromAsset(assetPath));
  }

  @override
  int get cachedCount => _cache.length;

  @override
  void dispose() => _cache.clear();
}