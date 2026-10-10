import 'package:flutter_test/flutter_test.dart';
import 'package:planets/scene.dart';

void main() {
  group('sceneViewTicksWhile (occlusion policy)', () {
    test('ticks while the avatar page is closed', () {
      expect(sceneViewTicksWhile(avatarPageVisible: false), isTrue);
    });

    test('pauses while the opaque avatar page covers the scene', () {
      // The page is fully opaque, so every rasterized frame is discarded
      // unseen; pausing stops repaints, per-frame logic and GPU raster
      // together. Translucent dialogs and partial panels are deliberately
      // not part of this policy: the live scene stays visible behind them.
      expect(sceneViewTicksWhile(avatarPageVisible: true), isFalse);
    });
  });
}
