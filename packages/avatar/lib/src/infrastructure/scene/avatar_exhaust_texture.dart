import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';

/// Builds the soft round sprite the exhaust particles are drawn with.
///
/// A particle plume is only convincing when each billboard has a soft edge.
/// A hard-edged quad reads as a stack of rectangles, and a flat white circle
/// reads as a bubble, so this bakes the three things that make a puff look
/// like a puff: a radial falloff to zero alpha, a slightly hotter core, and
/// low-frequency noise that breaks the perfect circle so neighbouring puffs
/// never line up into a visible grid.
///
/// Generated in-process from pixels rather than shipped as a PNG: the sprite is
/// a handful of kilobytes of arithmetic, the falloff has to stay matched to the
/// additive blend the exhaust uses, and there is no asset to license or load.
class ExhaustSpriteFactory {
  const ExhaustSpriteFactory._();

  /// Side length of the generated sprite, in pixels.
  static const int size = 64;

  /// Uploads a freshly generated soft-puff sprite to the GPU.
  ///
  /// Straight (non-premultiplied) alpha, matching what
  /// [Texture2D.fromImage] produces for the other textures in the project, so
  /// the sprite shader's `SRGBToLinear(base.rgb)` sees the same encoding either
  /// way.
  static Texture2D build() {
    final pixels = buildPixels();
    return Texture2D.fromPixels(pixels, size, size);
  }

  /// The sprite's RGBA pixels, exposed for tests and for reuse without a GPU.
  static Uint8List buildPixels() {
    final pixels = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        // Centre the disc and measure distance in units of the sprite's radius
        // so the falloff is resolution independent.
        final nx = (x + 0.5) / size * 2.0 - 1.0;
        final ny = (y + 0.5) / size * 2.0 - 1.0;
        final r = math.sqrt(nx * nx + ny * ny);

        // Smooth radial falloff. `pow` sharpens the shoulder so the sprite has
        // a visible body instead of a uniform blur, and the clamp keeps
        // anything outside the disc fully transparent rather than negative.
        final falloff = math
            .pow((1.0 - r).clamp(0.0, 1.0).toDouble(), 1.9)
            .toDouble();

        // A hotter core: the inner third lifts alpha again so overlapping
        // additive puffs stack into a bright centre the way real flame does.
        final core = r < 0.45 ? (1.0 - r / 0.45) * 0.35 : 0.0;

        // Low-frequency wobble. Two sine lobes are enough to make the disc
        // irregular; more octaves would only cost time for detail the sprite
        // is too small to show.
        final wobble =
            1.0 +
            math.sin(nx * 4.1 + ny * 2.3) * 0.10 +
            math.cos(nx * 2.7 - ny * 3.9) * 0.08;

        final alpha = ((falloff + core) * wobble).clamp(0.0, 1.0);

        final i = (y * size + x) * 4;
        // White, so the material's per-particle colour (set by the emitter's
        // colour-over-life gradient) is what actually tints the puff.
        pixels[i] = 255;
        pixels[i + 1] = 255;
        pixels[i + 2] = 255;
        pixels[i + 3] = (alpha * 255.0).round().clamp(0, 255);
      }
    }
    return pixels;
  }
}
