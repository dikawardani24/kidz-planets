import 'package:flutter_scene/scene.dart';

/// Async texture cache (SRP: texture fetching only).
///
/// Uses [Texture2D.fromAsset] directly, so planet JPG/PNG textures load
/// without the `buildTextures` / `.fstex` pipeline — zero extra setup,
/// hot-reload friendly.
abstract class TextureProvider {
  Future<TextureSource> get(String assetPath);
  void dispose();
}

/// In-memory cache over [Texture2D.fromAsset] (ISP: narrow interface).
class AssetTextureProvider implements TextureProvider {
  final Map<String, Future<TextureSource>> _cache = {};

  @override
  Future<TextureSource> get(String assetPath) {
    return _cache.putIfAbsent(
      assetPath,
      () => Texture2D.fromAsset(assetPath),
    );
  }

  @override
  void dispose() => _cache.clear();
}
