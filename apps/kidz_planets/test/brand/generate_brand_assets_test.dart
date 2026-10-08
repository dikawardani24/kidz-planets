import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Generates every Planetaria raster brand asset from one painter.
///
/// Run with:
///
///   GENERATE_BRAND_ASSETS=true flutter test test/brand/generate_brand_assets_test.dart
///
/// Without the flag the test passes trivially, so ordinary `flutter test`
/// runs stay clean and hermetic. The painter below is the single source of
/// truth for the planet-and-ring mark: the Android launcher (legacy +
/// adaptive), the Android splash mark, the iOS app icons, the iOS launch
/// image, the web icons and the TV banner all derive from it, so they can
/// never drift apart.
///
/// Design notes (kept in code, not in a design tool, for reproducibility):
/// - Deep-space indigo tile, amber ringed planet, one small moon, seeded
///   stars. No text: wordmarks turn to mush below 100px.
/// - The planet itself always sits inside the Android adaptive-icon safe
///   circle; only the ring tips are allowed into the bleed zone.
void main() {
  testWidgets('generate Planetaria brand assets', (tester) async {
    if (Platform.environment['GENERATE_BRAND_ASSETS'] != 'true') {
      return;
    }
    final out = _Writer('test/brand/tmp');
    await _generateAll(out);
    debugPrint('brand assets written under ${out.root}');
  }, skip: false);
}

class _Writer {
  _Writer(this.root);

  final String root;

  Future<void> png(
    String relativePath,
    int width,
    int height,
    void Function(Canvas, Size) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(canvas, Size(width.toDouble(), height.toDouble()));
    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$root/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    debugPrint('wrote $relativePath (${width}x$height)');
  }
}

Future<void> _generateAll(_Writer out) async {
  // Android legacy launcher (full tile).
  const legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144};
  for (final entry in legacy.entries) {
    await out.png(
      'android/mipmap-${entry.key}/ic_launcher.png',
      entry.value,
      entry.value,
      _paintTile,
    );
  }
  await out.png('android/mipmap-xxxhdpi/ic_launcher.png', 192, 192, _paintTile);

  // Android adaptive foreground (transparent; planet inside the safe circle).
  const fg = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324};
  for (final entry in fg.entries) {
    await out.png(
      'android/mipmap-${entry.key}/ic_launcher_foreground.png',
      entry.value,
      entry.value,
      _paintForeground,
    );
  }
  await out.png(
    'android/mipmap-xxxhdpi/ic_launcher_foreground.png',
    432,
    432,
    _paintForeground,
  );

  // Android splash mark (transparent; intrinsic padding included).
  const splash = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324};
  for (final entry in splash.entries) {
    await out.png(
      'android/drawable-${entry.key}/planetaria_mark.png',
      entry.value,
      entry.value,
      _paintMark,
    );
  }
  await out.png(
    'android/drawable-xxxhdpi/planetaria_mark.png',
    432,
    432,
    _paintMark,
  );

  // TV banner (wide space tile, no text).
  await out.png('android/drawable/tv_banner.png', 320, 180, _paintBanner);

  // iOS app icons (opaque tiles, exact pixels per Contents.json).
  const iosSizes = [20, 29, 40, 58, 76, 80, 87, 120, 152, 167, 180, 1024];
  for (final size in iosSizes) {
    await out.png('ios/Icon-App-$size.png', size, size, _paintTile);
  }

  // iOS launch image (transparent mark; storyboard supplies the background).
  await out.png('ios/LaunchImage.png', 192, 192, _paintMark);
  await out.png('ios/LaunchImage@2x.png', 384, 384, _paintMark);
  await out.png('ios/LaunchImage@3x.png', 576, 576, _paintMark);

  // Web icons + favicon.
  await out.png('web/favicon.png', 64, 64, _paintTile);
  await out.png('web/Icon-192.png', 192, 192, _paintTile);
  await out.png('web/Icon-512.png', 512, 512, _paintTile);
  await out.png('web/Icon-maskable-192.png', 192, 192, _paintMaskable);
  await out.png('web/Icon-maskable-512.png', 512, 512, _paintMaskable);
}

// ---------------------------------------------------------------------------
// The mark itself.
// ---------------------------------------------------------------------------

/// Deep-space tile the full-bleed icons use.
void _paintTile(Canvas canvas, Size size) {
  _paintSpace(canvas, size);
  _paintSystem(
    canvas,
    size,
    center: Offset(size.width * 0.5, size.height * 0.46),
    planetRadius: size.shortestSide * 0.27,
  );
}

/// Adaptive-icon foreground: transparent, planet inside the safe circle.
void _paintForeground(Canvas canvas, Size size) {
  _paintStars(canvas, size, seed: 11, countScale: 0.7);
  _paintSystem(
    canvas,
    size,
    center: Offset(size.width * 0.5, size.height * 0.5),
    planetRadius: size.shortestSide * 0.21,
  );
}

/// Centered splash/launch mark with intrinsic padding.
void _paintMark(Canvas canvas, Size size) {
  _paintSystem(
    canvas,
    size,
    center: Offset(size.width * 0.5, size.height * 0.5),
    planetRadius: size.shortestSide * 0.28,
    glow: true,
  );
}

/// Maskable web icon: artwork pulled into the ~70% safe zone.
void _paintMaskable(Canvas canvas, Size size) {
  _paintSpace(canvas, size);
  _paintSystem(
    canvas,
    size,
    center: Offset(size.width * 0.5, size.height * 0.5),
    planetRadius: size.shortestSide * 0.19,
  );
}

/// Wide TV banner: planet left of centre, moon trailing right.
void _paintBanner(Canvas canvas, Size size) {
  _paintSpace(canvas, size);
  _paintSystem(
    canvas,
    size,
    center: Offset(size.width * 0.32, size.height * 0.52),
    planetRadius: size.height * 0.30,
  );
  _paintMoon(
    canvas,
    Offset(size.width * 0.68, size.height * 0.34),
    size.height * 0.07,
  );
}

void _paintSpace(Canvas canvas, Size size) {
  final bg = Rect.fromLTWH(0, 0, size.width, size.height);
  canvas.drawRect(
    bg,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B2358), Color(0xFF060417)],
      ).createShader(bg),
  );
  _paintStars(canvas, size, seed: 7, countScale: 1.0);
}

void _paintStars(
  Canvas canvas,
  Size size, {
  required int seed,
  required double countScale,
}) {
  final random = math.Random(seed);
  final count = (size.width * size.height / (108 * 108) * 42 * countScale)
      .round()
      .clamp(12, 220);
  for (var i = 0; i < count; i++) {
    final p = Offset(
      random.nextDouble() * size.width,
      random.nextDouble() * size.height,
    );
    final r = (0.6 + random.nextDouble() * 1.6) * size.shortestSide / 108;
    canvas.drawCircle(
      p,
      r.clamp(0.5, 3.0),
      Paint()
        ..color = Colors.white.withValues(
          alpha: 0.35 + random.nextDouble() * 0.55,
        ),
    );
  }
}

/// The ringed planet: glow, back ring, shaded sphere, front ring, moon.
void _paintSystem(
  Canvas canvas,
  Size size, {
  required Offset center,
  required double planetRadius,
  bool glow = false,
}) {
  final r = planetRadius;
  if (glow) {
    canvas.drawCircle(
      center,
      r * 2.1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF59E0B).withValues(alpha: 0.22),
            const Color(0xFFF59E0B).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 2.1)),
    );
  }

  // Ring geometry: wide tilted ellipse around the planet.
  final ringRect = Rect.fromCenter(
    center: Offset.zero,
    width: r * 2.9,
    height: r * 1.02,
  );
  const tilt = -0.35;
  final ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = (r * 0.13).clamp(1.5, 14.0)
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFBFE6FF).withValues(alpha: 0.95);

  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(tilt);
  // Back half of the ring (upper arc in the tilted frame).
  canvas.drawArc(ringRect, math.pi * 1.02, math.pi * 0.96, false, ringPaint);
  canvas.restore();

  // Shaded sphere, lit from the upper left.
  final sphereRect = Rect.fromCircle(center: center, radius: r);
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.38, -0.42),
        radius: 1.15,
        colors: [Color(0xFFFFD9A0), Color(0xFFF59E0B), Color(0xFFB45309)],
      ).createShader(sphereRect),
  );
  // Soft terminator on the lower right.
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.55, 0.6),
        radius: 0.9,
        colors: [
          const Color(0xFF7C2D12).withValues(alpha: 0.0),
          const Color(0xFF7C2D12).withValues(alpha: 0.45),
        ],
      ).createShader(sphereRect),
  );

  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(tilt);
  // Front half of the ring (lower arc in the tilted frame).
  canvas.drawArc(ringRect, math.pi * 0.02, math.pi * 0.96, false, ringPaint);
  canvas.restore();

  _paintMoon(canvas, center + Offset(r * 1.9, -r * 1.55), r * 0.22);
}

void _paintMoon(Canvas canvas, Offset center, double radius) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.4),
        radius: 1.1,
        colors: [Color(0xFFF1F5F9), Color(0xFF94A3B8)],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
}
