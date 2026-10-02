import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/l10n.dart';
import 'package:core/time.dart';
import 'package:planets/data.dart';
import 'package:planets/state.dart';

ExplorerController makeController() =>
    ExplorerController(clock: SimulationClock());

void main() {
  test('catalog has sun + 8 planets with textures', () {
    expect(PlanetCatalog.planets.length, 27);
    expect(PlanetCatalog.moons.length, 18);
    expect(PlanetCatalog.planets.first.id, 'sun');
    for (final p in PlanetCatalog.planets.where((p) => !p.isMoon)) {
      expect(p.textureAsset, startsWith('assets/textures/'));
      expect(p.radius, greaterThan(0));
    }
    for (final moon in PlanetCatalog.moons) {
      expect(moon.isMoon, isTrue);
      expect(moon.parentPlanetId, isNotNull);
      expect(moon.radius, greaterThan(0));
    }
    final saturn = PlanetCatalog.planets.firstWhere((p) => p.id == 'saturn');
    expect(saturn.hasRing, isTrue);
  });

  test('selecting a body focuses it and re-tapping the same one clears it', () {
    final c = makeController();

    c.selectPlanet('earth');
    expect(c.state.selectedPlanetId, 'earth');
    expect(c.state.focusedPlanetId, 'earth');

    // Re-tapping the body that is already focused is how the child backs out,
    // so it must not raise a second selection.
    c.selectPlanet('earth');
    expect(c.state.selectedPlanetId, isNull);
    expect(c.state.focusedPlanetId, isNull);

    c.selectPlanet('mars');
    c.closeDetail();
    expect(c.state.selectedPlanetId, isNull);
    expect(c.state.focusedPlanetId, isNull);

    c.dispose();
  });

  test('toasts are raised, stack and expire on their own', () {
    fakeAsync((async) {
      final c = makeController();

      c.showToast(const AppMessage(AppMessageId.toastSandboxReady));
      expect(c.state.toasts, hasLength(1));

      // A second toast stacks rather than replacing, so neither is lost. Raised
      // a second later so the two expiries are distinguishable.
      async.elapse(const Duration(seconds: 1));
      c.showToast(
        const AppMessage(AppMessageId.toastMissionComplete, {'title': 'Earth'}),
      );
      expect(c.state.toasts, hasLength(2));

      // Each toast owns its own timer, so the first leaves without taking the
      // second with it.
      async.elapse(const Duration(seconds: 2));
      expect(c.state.toasts, hasLength(1));

      async.elapse(const Duration(seconds: 1));
      expect(c.state.toasts, isEmpty);

      c.dispose();
    });
  });

  test('simulation clock scales time by speed and pauses', () {
    final clock = SimulationClock();
    clock.tick(1.0);
    expect(clock.elapsedSeconds, 1.0);
    clock.setSpeed(2.0);
    clock.tick(1.0);
    expect(clock.elapsedSeconds, 3.0);
    clock.pause();
    clock.tick(5.0);
    expect(clock.elapsedSeconds, 3.0);
    clock.resume();
    clock.tick(0.5);
    expect(clock.elapsedSeconds, 4.0);
    clock.dispose();
  });

  test('toggles flip the explorer\'s own state', () {
    final c = makeController();
    c.toggleRunning();
    expect(c.state.running, isFalse);
    c.toggleOrbits();
    expect(c.state.showOrbits, isFalse);
    c.toggleLabels();
    expect(c.state.showLabels, isFalse);
    c.dispose();
  });
}
