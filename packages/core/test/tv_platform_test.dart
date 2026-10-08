import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/platform.dart';

void main() {
  group('classifyFormFactor', () {
    test('phone window is mobile', () {
      expect(
        classifyFormFactor(
          windowSize: const Size(390, 844),
          isTelevision: false,
        ),
        DeviceFormFactor.mobile,
      );
    });

    test('600dp shortest side is tablet', () {
      expect(
        classifyFormFactor(
          windowSize: const Size(800, 600),
          isTelevision: false,
        ),
        DeviceFormFactor.tablet,
      );
    });

    test('television wins over any window size', () {
      expect(
        classifyFormFactor(
          windowSize: const Size(390, 844),
          isTelevision: true,
        ),
        DeviceFormFactor.television,
      );
      expect(
        classifyFormFactor(
          windowSize: const Size(1920, 1080),
          isTelevision: true,
        ),
        DeviceFormFactor.television,
      );
    });
  });

  group('resolveTvInputLayer', () {
    test('nothing active is the explorer', () {
      expect(
        resolveTvInputLayer(
          modalOpen: false,
          missionOpen: false,
          detailOpen: false,
          avatarFocused: false,
        ),
        TvInputLayer.explorer,
      );
    });

    test('modal outranks everything', () {
      expect(
        resolveTvInputLayer(
          modalOpen: true,
          missionOpen: true,
          detailOpen: true,
          avatarFocused: true,
        ),
        TvInputLayer.modal,
      );
    });

    test('mission outranks detail and avatar', () {
      expect(
        resolveTvInputLayer(
          modalOpen: false,
          missionOpen: true,
          detailOpen: true,
          avatarFocused: true,
        ),
        TvInputLayer.mission,
      );
    });

    test('detail outranks avatar', () {
      expect(
        resolveTvInputLayer(
          modalOpen: false,
          missionOpen: false,
          detailOpen: true,
          avatarFocused: true,
        ),
        TvInputLayer.detail,
      );
    });

    test('avatar alone owns the remote', () {
      expect(
        resolveTvInputLayer(
          modalOpen: false,
          missionOpen: false,
          detailOpen: false,
          avatarFocused: true,
        ),
        TvInputLayer.avatar,
      );
    });
  });

  group('isActionForLayer', () {
    test('explorer receives everything', () {
      for (final action in TvExplorerAction.values) {
        expect(
          isActionForLayer(action, TvInputLayer.explorer),
          isTrue,
          reason: '$action',
        );
      }
    });

    test('a dialog consumes everything except back and play/pause', () {
      for (final action in TvExplorerAction.values) {
        final expected =
            action == TvExplorerAction.back ||
            action == TvExplorerAction.playPause;
        expect(
          isActionForLayer(action, TvInputLayer.modal),
          expected,
          reason: '$action',
        );
      }
    });

    test('mission and detail layers bubble back and play/pause only', () {
      for (final layer in [TvInputLayer.mission, TvInputLayer.detail]) {
        expect(isActionForLayer(TvExplorerAction.back, layer), isTrue);
        expect(isActionForLayer(TvExplorerAction.playPause, layer), isTrue);
        expect(isActionForLayer(TvExplorerAction.navigate, layer), isFalse);
        expect(isActionForLayer(TvExplorerAction.select, layer), isFalse);
      }
    });
  });

  group('nearestInDirection', () {
    const origin = Offset(500, 500);

    test('picks the nearest candidate in the requested direction', () {
      expect(
        nearestInDirection(
          origin: origin,
          direction: const Offset(1, 0),
          candidates: const [
            (id: 'far', center: Offset(900, 500)),
            (id: 'near', center: Offset(600, 500)),
            (id: 'behind', center: Offset(100, 500)),
          ],
        ),
        'near',
      );
    });

    test('ignores candidates outside the half-plane', () {
      expect(
        nearestInDirection(
          origin: origin,
          direction: const Offset(0, -1),
          candidates: const [
            (id: 'below', center: Offset(500, 900)),
            (id: 'far-left', center: Offset(100, 800)),
          ],
        ),
        isNull,
      );
    });

    test('widgets and bodies compete by position, not kind', () {
      // A chrome control slightly off-axis but close beats a body far away.
      expect(
        nearestInDirection(
          origin: origin,
          direction: const Offset(1, 0),
          candidates: const [
            (id: 'chrome:zoom-in', center: Offset(600, 560)),
            (id: 'saturn', center: Offset(1500, 500)),
          ],
        ),
        'chrome:zoom-in',
      );
    });

    test('zero direction selects nothing', () {
      expect(
        nearestInDirection(
          origin: origin,
          direction: Offset.zero,
          candidates: const [(id: 'earth', center: Offset(600, 500))],
        ),
        isNull,
      );
    });
  });

  group('tvDirectionForKey', () {
    test('maps arrow names to unit directions', () {
      expect(tvDirectionForKey('left'), const Offset(-1, 0));
      expect(tvDirectionForKey('right'), const Offset(1, 0));
      expect(tvDirectionForKey('up'), const Offset(0, -1));
      expect(tvDirectionForKey('down'), const Offset(0, 1));
    });
  });
  group('TvControlMode', () {
    test('toggled switches browse and rotate', () {
      expect(TvControlMode.browse.toggled, TvControlMode.rotate);
      expect(TvControlMode.rotate.toggled, TvControlMode.browse);
    });
  });

  group('resolveBackFocus', () {
    test('chrome focus always re-seats into the scene', () {
      expect(
        resolveBackFocus(
          focusInScene: false,
          focusInChrome: true,
          canUnwind: true,
        ),
        TvBackFocusAction.toScene,
      );
      expect(
        resolveBackFocus(
          focusInScene: false,
          focusInChrome: true,
          canUnwind: false,
        ),
        TvBackFocusAction.toScene,
      );
    });

    test('lost focus re-seats into the scene, never to chrome', () {
      expect(
        resolveBackFocus(
          focusInScene: false,
          focusInChrome: false,
          canUnwind: false,
        ),
        TvBackFocusAction.toScene,
      );
    });

    test('scene focus unwinds while the hierarchy owns the press', () {
      expect(
        resolveBackFocus(
          focusInScene: true,
          focusInChrome: false,
          canUnwind: true,
        ),
        TvBackFocusAction.unwind,
      );
    });

    test('empty-handed scene focus offers the cluster, never the system', () {
      expect(
        resolveBackFocus(
          focusInScene: true,
          focusInChrome: false,
          canUnwind: false,
        ),
        TvBackFocusAction.toChrome,
      );
    });
  });
}
