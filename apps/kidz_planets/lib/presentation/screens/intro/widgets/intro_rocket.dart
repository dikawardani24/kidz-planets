import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The cute rocket centerpiece: a floating 🚀 with a flickering flame.
///
/// Deliberately emoji + gradients, not the Explorer's 3D companion: the
/// prototype draws its rocket as a big emoji with a CSS flame, and — more
/// importantly — the intro must stay smooth while the GPU is busy decoding
/// planet textures. A `SceneView` here would contend for the same raster
/// thread the startup work needs. One looping controller drives both the
/// gentle float (the prototype's 3.5s `rocketFloat`) and the fast flame
/// flicker (its 0.15s `flameFlicker`), so the rocket costs a single ticker.
class IntroRocket extends StatefulWidget {
  const IntroRocket({super.key, this.launching = false});

  /// True once startup completes: the rocket climbs and fades, the
  /// prototype's launch into the Explorer.
  final bool launching;

  @override
  State<IntroRocket> createState() => _IntroRocketState();
}

class _IntroRocketState extends State<IntroRocket>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        final t = _loop.value * math.pi * 2;
        // `rocketFloat`: ±12px drift and a ±2° rock, eased as a sine.
        final float = math.sin(t) * -6;
        final rock = math.sin(t) * 2 * math.pi / 180;
        // `flameFlicker` runs ~23x faster than the float on its own phase.
        final flicker = 0.5 + 0.5 * math.sin(t * 23.3);
        return Transform.translate(
          offset: Offset(0, widget.launching ? -160 * _launchT(t) : float),
          child: Transform.rotate(
            angle: rock,
            child: Opacity(
              opacity: widget.launching ? 1 - _launchT(t) : 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🚀',
                    style: TextStyle(
                      fontSize: 76,
                      shadows: [
                        Shadow(
                          color: const Color(0xFF7000FF).withValues(alpha: 0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                  // Flame + exhaust puffs, stacked under the emoji's tail.
                  Transform.scale(
                    scaleY: 1 + flicker * 0.25,
                    scaleX: 1 - flicker * 0.1,
                    child: Container(
                      width: 12,
                      height: 24,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0xFFFACC15),
                            Color(0xFFF97316),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 6,
                    height: 10 + flicker * 4,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(999),
                      ),
                      color: const Color(0xFF60A5FA).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Launch progress 0→1, derived from wall time so it needs no controller.
  double _launchT(double t) => (0.5 + 0.5 * math.sin(t / 4)).clamp(0.0, 1.0);
}
