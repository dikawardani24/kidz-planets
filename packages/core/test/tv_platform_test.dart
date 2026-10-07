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
        expect(isActionForLayer(TvExplorerAction.focusNext, layer), isFalse);
        expect(isActionForLayer(TvExplorerAction.select, layer), isFalse);
      }
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
