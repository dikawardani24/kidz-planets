import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/presentation/widgets/overlays/bottom_nav.dart';
import 'package:kidz_planets/presentation/widgets/panels/companion_safe_area.dart';

import 'helpers/localized_app.dart';

/// A phone-shaped window, so the expectations below are the ones a real device
/// would produce rather than the ones a test-sized box happens to.
const _phone = Size(390, 844);

/// The insets a notched phone reports: a status bar and a home indicator.
const _notch = EdgeInsets.only(top: 47, bottom: 34);

void main() {
  group('CompanionSafeArea', () {
    test('keeps the toy clear of the status bar, the top bar and the nav', () {
      final area = CompanionSafeArea.forViewport(_phone, _notch);

      // Below the status bar plus the top bar, plus the edge gap.
      expect(area.min.dy, greaterThanOrEqualTo(_notch.top + 50));
      // Above the home indicator, the nav and its margin, minus the toy.
      expect(area.max.dy, lessThanOrEqualTo(_phone.height - 148 - 34 - 70));
      expect(area.isUsable, isTrue);
    });

    test('grows with the window rather than using a fixed screen size', () {
      final small = CompanionSafeArea.forViewport(const Size(320, 568), _notch);
      final large = CompanionSafeArea.forViewport(
        const Size(1024, 1366),
        _notch,
      );

      expect(large.max.dx, greaterThan(small.max.dx));
      expect(large.max.dy, greaterThan(small.max.dy));
      // The insets are a fixed size, so the larger window is also roomier once
      // they are taken out. A hard-coded viewport would fail this outright.
      expect(
        large.max.dx - large.min.dx,
        greaterThan(small.max.dx - small.min.dx),
      );
    });

    test('honours a landscape window', () {
      final area = CompanionSafeArea.forViewport(const Size(844, 390), _notch);

      expect(area.isUsable, isTrue);
      // The nav is narrower in landscape but the same height, so the toy still
      // has to stay above it.
      expect(area.max.dy, lessThan(390 - 148));
    });

    test('a window with no insets still keeps the chrome clear', () {
      final area = CompanionSafeArea.forViewport(_phone, EdgeInsets.zero);

      expect(area.min.dy, greaterThanOrEqualTo(50));
      expect(area.max.dy, lessThanOrEqualTo(_phone.height - 148 - 70));
    });

    test('a window too small for the toy collapses instead of inverting', () {
      // A clamp whose bounds are the wrong way round throws, and a split screen
      // on a small phone really can be this narrow.
      final area = CompanionSafeArea.forViewport(const Size(100, 100), _notch);

      expect(area.min.dx, lessThanOrEqualTo(area.max.dx));
      expect(area.min.dy, lessThanOrEqualTo(area.max.dy));
      expect(area.isUsable, isFalse);
      expect(() => area.clamp(const Offset(50, 50)), returnsNormally);
    });

    test('clamp holds both edges, not just the far one', () {
      final area = CompanionSafeArea.forViewport(_phone, _notch);

      expect(area.clamp(const Offset(-100, -100)), area.min);
      expect(area.clamp(const Offset(9999, 9999)), area.max);
      final middle = Offset(
        (area.min.dx + area.max.dx) / 2,
        (area.min.dy + area.max.dy) / 2,
      );
      expect(area.clamp(middle), middle);
    });

    test('compact layouts drop the chrome allowances', () {
      // The same widget is laid out outside the explorer stack, where there is
      // no top bar or nav to avoid, and reserving room for bars that are not
      // there would leave the toy unable to reach the bottom of the screen.
      final normal = CompanionSafeArea.forViewport(_phone, _notch);
      final compact = CompanionSafeArea.forViewport(
        _phone,
        _notch,
        compact: true,
      );

      expect(compact.min.dy, lessThan(normal.min.dy));
      expect(compact.max.dy, greaterThan(normal.max.dy));
    });
  });

  group('the bottom nav extent the toy is kept clear of', () {
    testWidgets('the reserved height matches the nav the app actually draws', (
      tester,
    ) async {
      // Measured inside a stack, because that is how the nav is really laid out:
      // a bare `home` would measure it in a different place and the number would
      // not be the one the companion has to stay clear of.
      await pumpLocalized(
        tester,
        const Scaffold(body: Stack(children: [ExplorerBottomNav()])),
      );

      final height = tester.getSize(find.byType(ExplorerBottomNav)).height;

      // A companion that trusts a stale number here parks the toy behind the
      // nav. The constant is derived from the nav's own paddings, so this only
      // fails for the parts that cannot be derived: the icon's height against
      // the label's, and the glass border.
      expect(
        height,
        closeTo(bottomNavExtent, 0.5),
        reason:
            'bottomNavExtent is $bottomNavExtent but the nav is '
            '${height.toStringAsFixed(1)} tall; update it or the companion '
            'will settle behind the nav',
      );
    });
  });
}
