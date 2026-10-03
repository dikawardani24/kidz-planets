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

  /// How long the climb lasts.
  ///
  /// The page hands over to the Explorer on exactly this beat, so the two
  /// cannot drift: the rocket is at the top of its climb, fully faded, exactly
  /// when the handover begins.
  static const Duration launchDuration = Duration(milliseconds: 650);

  @override
  State<IntroRocket> createState() => _IntroRocketState();
}

class _IntroRocketState extends State<IntroRocket>
    with TickerProviderStateMixin {
  late final AnimationController _loop;

  /// The climb, on its own monotonic controller.
  ///
  /// This used to be sampled out of [_loop]'s sine, which meant the launch
  /// progress depended on wherever the 3.5s float happened to be when the CTA
  /// was tapped: the rocket would jump 0-80px instantly, sometimes appear
  /// already faded, and never finish in step with the handover. A dedicated
  /// forward-only controller makes the beat repeatable and lets the idle
  /// float fade out underneath it instead of fighting it.
  late final AnimationController _launch;
  late final Animation<double> _climb;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
    _launch = AnimationController(
      vsync: this,
      duration: IntroRocket.launchDuration,
    );
    _climb = CurvedAnimation(parent: _launch, curve: Curves.easeInCubic);
  }

  @override
  void didUpdateWidget(IntroRocket oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.launching && !oldWidget.launching) _launch.forward();
  }

  @override
  void dispose() {
    _loop.dispose();
    _launch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_loop, _launch]),
      builder: (context, _) {
        final t = _loop.value * math.pi * 2;
        final climb = _climb.value;
        // The idle float, rock and flicker all fade out as the rocket climbs:
        // a floating, wobbling rocket reads as "still here" while it is on its
        // way out.
        final idle = 1 - climb;
        // `rocketFloat`: ±12px drift and a ±2° rock, eased as a sine.
        final float = math.sin(t) * -6 * idle;
        final rock = math.sin(t) * 2 * math.pi / 180 * idle;
        // `flameFlicker` runs ~23x faster than the float on its own phase, and
        // stretches out as the rocket accelerates away.
        final flicker = 0.5 + 0.5 * math.sin(t * 23.3);
        return Transform.translate(
          offset: Offset(0, -160 * climb + float),
          child: Transform.rotate(
            angle: rock,
            child: Opacity(
              opacity: 1 - climb,
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
}
