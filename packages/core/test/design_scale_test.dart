import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/layout.dart';

void main() {
  group('DesignScale.sharedFactorFor', () {
    test('the reference phone reproduces authored pixels exactly', () {
      expect(DesignScale.sharedFactorFor(const Size(390, 844)), 1.0);
    });

    test('landscape phones keep their scale (orientation-invariant)', () {
      expect(
        DesignScale.sharedFactorFor(const Size(844, 390)),
        DesignScale.sharedFactorFor(const Size(390, 844)),
      );
    });

    test('smaller phones scale down gently', () {
      final factor = DesignScale.sharedFactorFor(const Size(360, 800));
      expect(factor, lessThan(1.0));
      expect(factor, greaterThan(0.9));
    });

    test('tiny phones hit the readability floor, never zero', () {
      expect(
        DesignScale.sharedFactorFor(const Size(320, 568)),
        DesignScale.minSharedFactor,
      );
    });

    test('tablets land mid-range', () {
      final factor = DesignScale.sharedFactorFor(const Size(800, 1280));
      expect(factor, greaterThan(1.5));
      expect(factor, lessThanOrEqualTo(DesignScale.maxSharedFactor));
    });

    test('720p TV scales up proportionally', () {
      expect(
        DesignScale.sharedFactorFor(const Size(1280, 720)),
        closeTo(1.58, 0.02),
      );
    });

    test('1080p and 4K TVs cap at the composition maximum', () {
      expect(
        DesignScale.sharedFactorFor(const Size(1920, 1080)),
        DesignScale.maxSharedFactor,
      );
      expect(
        DesignScale.sharedFactorFor(const Size(3840, 2160)),
        DesignScale.maxSharedFactor,
      );
    });
  });

  group('DesignScale.tvFactorFor', () {
    test('1080p is the reference', () {
      expect(
        DesignScale.tvFactorFor(const Size(1920, 1080)),
        closeTo(1.0, 0.001),
      );
    });

    test('720p scales linearly in both axes at once', () {
      expect(
        DesignScale.tvFactorFor(const Size(1280, 720)),
        closeTo(2 / 3, 0.001),
      );
    });

    test('4K doubles the reference', () {
      expect(
        DesignScale.tvFactorFor(const Size(3840, 2160)),
        closeTo(2.0, 0.001),
      );
    });
  });

  group('proportion preservation', () {
    test('one factor scales every dimension: ratios survive', () {
      const scale = DesignScale.test(1.58);
      expect(scale.px(400) / scale.px(200), 2.0);
      expect(scale.radius(20), scale.px(20));
    });

    test('font floors bind only below the readability minimum', () {
      const scale = DesignScale.test(0.9);
      expect(scale.font(20, min: 18), 18); // 20*0.9 floored
      expect(scale.font(20), closeTo(18.0, 0.001));
      const big = DesignScale.test(1.7);
      expect(big.font(20, min: 18), closeTo(34.0, 0.001)); // above floor
    });
  });
}
