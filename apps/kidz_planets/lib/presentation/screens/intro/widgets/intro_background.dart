import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The deep-space backdrop behind the intro: gradient + nebulae + stars.
///
/// A `StatelessWidget` with precomputed star specs, so the twinkle runs on one
/// looping controller without rebuilding the star list every frame — the
/// reason a naive `setState`-per-twinkle starfield drops frames on low-end
/// devices. The stars are plain positioned dots (the prototype's `.star` divs),
/// not a particle system: nothing here allocates during the animation.
class IntroBackground extends StatefulWidget {
  const IntroBackground({super.key});

  /// How many twinkling stars to scatter, matching the prototype's 75.
  @visibleForTesting
  static const int starCount = 75;

  @override
  State<IntroBackground> createState() => _IntroBackgroundState();
}

class _IntroBackgroundState extends State<IntroBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;
  late final List<_StarSpec> _stars;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    final random = math.Random(20261002);
    _stars = List.generate(IntroBackground.starCount, (_) {
      return _StarSpec(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: 1 + random.nextDouble() * 2.5,
        phase: random.nextDouble(),
        // The prototype varies twinkle speed per star (1.5–4.5s); the phase
        // offsets on one shared loop read the same to a child.
        speed: 0.6 + random.nextDouble() * 0.9,
      );
    });
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _twinkle,
        builder: (context, _) => CustomPaint(
          painter: _SpacePainter(time: _twinkle.value, stars: _stars),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// One star's fixed spec: position as a fraction of the canvas, diameter in
/// logical pixels, twinkle phase and relative speed.
class _StarSpec {
  const _StarSpec({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
  });

  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;
}

/// Paints the prototype's `.space-bg`: radial gradient, two nebulae, stars.
///
/// One painter, one canvas, no layers: the nebulae are radial-gradient
/// circles and the stars are anti-aliased dots with a soft glow at peak
/// twinkle (the prototype's `box-shadow: 0 0 8px #ffffff, 0 0 15px #70d6ff`).
class _SpacePainter extends CustomPainter {
  _SpacePainter({required this.time, required this.stars});

  final double time;
  final List<_StarSpec> stars;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Base: `radial-gradient(circle at 50% 30%, #1e155c, #0e0b3b, #060417)`.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.1,
          colors: const [
            Color(0xFF1E155C),
            Color(0xFF0E0B3B),
            Color(0xFF060417),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    // Two breathing nebulae, drifting slowly like the prototype's 10s pulse.
    _nebula(canvas, size, const Offset(-0.15, -0.1), 0.55, time);
    _nebula(canvas, size, const Offset(1.1, 1.1), 0.6, 1 - time);

    for (final star in stars) {
      final twinkle =
          0.5 + 0.5 * math.sin((time * star.speed + star.phase) * math.pi * 2);
      final center = Offset(star.x * size.width, star.y * size.height);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2 + 0.8 * twinkle);
      canvas.drawCircle(center, star.size * (0.8 + 0.4 * twinkle), paint);
      if (twinkle > 0.75) {
        canvas.drawCircle(
          center,
          star.size * 2.2,
          Paint()
            ..color = const Color(0xFF70D6FF)
                .withValues(alpha: 0.25 * (twinkle - 0.75) * 4),
        );
      }
    }
  }

  void _nebula(Canvas canvas, Size size, Offset at, double r, double pulse) {
    final radius = math.max(size.width, size.height) * r;
    final breathe = 1 + 0.1 * math.sin(pulse * math.pi * 2);
    canvas.drawCircle(
      Offset(at.dx * size.width, at.dy * size.height),
      radius * breathe,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF7832FF).withValues(alpha: 0.15),
                const Color(0xFF3296FF).withValues(alpha: 0.05),
                const Color(0xFF3296FF).withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 0.7],
            ).createShader(
              Rect.fromCircle(
                center: Offset(at.dx * size.width, at.dy * size.height),
                radius: radius * breathe,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(_SpacePainter old) => old.time != time;
}
