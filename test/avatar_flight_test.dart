import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/controllers/avatar_controller.dart';
import 'package:kidz_planets/application/state/avatar_state.dart';

/// Every flight style is pinned through the `@visibleForTesting` seam instead
/// of the 6s switcher, which picks a style at random and would make the path
/// formulas unrepeatable.
const Size viewport = Size(400, 800);
const Offset maxPosition = Offset(100, 200);

/// [updateFlight] scales elapsed time by 1.8, so a single tick of
/// `targetT / 1.8` lands the avatar at exactly `targetT` on the path.
double tickFor(double targetT) => targetT / 1.8;

AvatarController freshController(FlightStyle style) {
  final controller = AvatarController()..debugSetFlightStyle(style);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('FlightStyle.circle', () {
    test('starts on the right-hand edge of its orbit at t=0', () {
      final c = freshController(FlightStyle.circle);
      c.updateFlight(0, viewport, maxPosition);

      // centre (50, 100) plus a radius of 40 x 70 with cos(0)=1, sin(0)=0.
      expect(c.state.screenPosition, const Offset(90, 100));
    });

    test('is horizontally centred a quarter period in', () {
      final c = freshController(FlightStyle.circle);
      c.updateFlight(tickFor(math.pi / 2), viewport, maxPosition);

      // cos(pi/2) = 0 collapses x onto the centre line; the vertical axis
      // runs at 1.3x the horizontal rate so y has already swung past centre.
      expect(c.state.screenPosition!.dx, closeTo(50, 1e-9));
      expect(c.state.screenPosition!.dy, greaterThan(100));
    });

    test('reverses vertical direction between the two half periods', () {
      final down = freshController(FlightStyle.circle);
      down.updateFlight(tickFor(math.pi / 2), viewport, maxPosition);

      final up = freshController(FlightStyle.circle);
      // t*1.3 crosses pi between these two samples, so sin flips sign.
      up.updateFlight(tickFor(math.pi), viewport, maxPosition);

      expect(down.state.screenPosition!.dy, greaterThan(100));
      expect(up.state.screenPosition!.dy, lessThan(100));
    });
  });

  group('FlightStyle.zigzag', () {
    test('traverses to the far right edge mid-sweep', () {
      final c = freshController(FlightStyle.zigzag);
      // progress = (t * 0.5) % 2 == 1.0, the turning point of the sweep.
      c.updateFlight(tickFor(2), viewport, maxPosition);

      expect(c.state.screenPosition!.dx, closeTo(100, 1e-9));
    });

    test('returns to the near left edge on the next sweep', () {
      final c = freshController(FlightStyle.zigzag);
      // progress = (4 * 0.5) % 2 == 0, back at the start of the sweep.
      c.updateFlight(tickFor(4), viewport, maxPosition);

      expect(c.state.screenPosition!.dx, closeTo(0, 1e-9));
    });

    test('oscillates vertically on a faster sine than it sweeps', () {
      final a = freshController(FlightStyle.zigzag);
      a.updateFlight(tickFor(2), viewport, maxPosition);
      final b = freshController(FlightStyle.zigzag);
      b.updateFlight(tickFor(2.2), viewport, maxPosition);

      expect(a.state.screenPosition!.dy, isNot(closeTo(b.state.screenPosition!.dy, 1e-6)));
    });
  });

  group('FlightStyle.edge', () {
    Offset at(double targetT) {
      final c = freshController(FlightStyle.edge);
      c.updateFlight(tickFor(targetT), viewport, maxPosition);
      return c.state.screenPosition!;
    }

    test('starts at the top-left corner', () {
      expect(at(0), const Offset(0, 0));
    });

    test('crosses to the right edge after travelling one width', () {
      // The perimeter is 2 * (100 + 200) = 600 and the speed is 140 units/s,
      // so t = 100 / 140 puts it exactly at the top-right corner.
      expect(at(100 / 140), const Offset(100, 0));
    });

    test('crosses to the bottom edge after one width plus one height', () {
      expect(at((100 + 200) / 140), const Offset(100, 200));
    });

    test('reaches the bottom-left corner after two widths plus one height',
        () {
      expect(at((2 * 100 + 200) / 140), const Offset(0, 200));
    });

    test('wraps back to the start after a full perimeter', () {
      expect(at(600 / 140), const Offset(0, 0));
    });
  });

  group('updateFlight invariants', () {
    test('accumulates flightTime across frames', () {
      final c = freshController(FlightStyle.circle);
      c.updateFlight(0.5, viewport, maxPosition);
      expect(c.state.flightTime, closeTo(0.5, 1e-12));
      c.updateFlight(0.25, viewport, maxPosition);
      expect(c.state.flightTime, closeTo(0.75, 1e-12));
    });

    test('stays inside the viewport for every style over a long run', () {
      for (final style in FlightStyle.values) {
        final c = freshController(style);
        for (var i = 0; i < 400; i++) {
          c.updateFlight(1 / 60, viewport, maxPosition);
          final p = c.state.screenPosition!;
          expect(p.dx, inInclusiveRange(0, maxPosition.dx), reason: '$style x');
          expect(p.dy, inInclusiveRange(0, maxPosition.dy), reason: '$style y');
        }
      }
    });

    test('always reports the flying idle action', () {
      for (final style in FlightStyle.values) {
        final c = freshController(style);
        c.updateFlight(0.1, viewport, maxPosition);
        expect(c.state.idleAction, AvatarIdleAction.flying, reason: '$style');
      }
    });

    test('produces a finite position even for a degenerate viewport', () {
      for (final style in FlightStyle.values) {
        final c = freshController(style);
        c.updateFlight(0.3, viewport, Offset.zero);
        expect(c.state.screenPosition, const Offset(0, 0), reason: '$style');
      }
    });
  });

  group('flight style switcher', () {
    /// A fresh listener is replayed the current state immediately, so the
    /// registration call is dropped and only later notifications are recorded.
    List<FlightStyle> recordSwitches(AvatarController c) {
      final seen = <FlightStyle>[];
      c.addListener((s) => seen.add(s.flightStyle));
      expect(seen, hasLength(1), reason: 'new listeners get current state');
      seen.clear();
      return seen;
    }

    test('does not switch before six seconds have passed', () {
      fakeAsync((async) {
        final c = AvatarController();
        final seen = recordSwitches(c);

        async.elapse(const Duration(seconds: 5));
        expect(seen, isEmpty);

        c.dispose();
      });
    });

    test('switches to a valid style exactly on the six second mark', () {
      fakeAsync((async) {
        final c = AvatarController();
        final seen = recordSwitches(c);

        async.elapse(const Duration(seconds: 6));
        expect(seen, hasLength(1));
        expect(seen.single, isIn(FlightStyle.values));
        expect(c.state.idleAction, AvatarIdleAction.flying);

        c.dispose();
      });
    });

    test('keeps switching every six seconds', () {
      fakeAsync((async) {
        final c = AvatarController();
        final seen = recordSwitches(c);

        async.elapse(const Duration(seconds: 18));
        expect(seen, hasLength(3));
        expect(seen.every((s) => FlightStyle.values.contains(s)), isTrue);

        c.dispose();
      });
    });

    test('dispose cancels the timer', () {
      fakeAsync((async) {
        final c = AvatarController();
        final seen = recordSwitches(c);

        async.elapse(const Duration(seconds: 6));
        expect(seen, hasLength(1));

        c.dispose();
        async.elapse(const Duration(seconds: 60));

        expect(seen, hasLength(1), reason: 'no updates after dispose');
      });
    });

    test('is cancelled rather than left pending when disposed mid-cycle', () {
      fakeAsync((async) {
        AvatarController().dispose();
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
      });
    });
  });
}
