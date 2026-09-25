import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/controllers/explorer_controller.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/application/state/simulation_clock.dart';
import 'package:kidz_planets/data/datasources/planet_catalog.dart';
import 'package:kidz_planets/data/datasources/solar_system_local_datasource.dart';
import 'package:kidz_planets/data/repositories/solar_system_repository_impl.dart';

ExplorerController makeController() {
  final repo = SolarSystemRepositoryImpl(SolarSystemLocalDataSource());
  return ExplorerController(clock: SimulationClock(), initialMissions: repo.getMissions());
}

void main() {
  test('catalog has sun + 8 planets with textures', () {
    expect(PlanetCatalog.planets.length, 9);
    expect(PlanetCatalog.planets.first.id, 'sun');
    for (final p in PlanetCatalog.planets) {
      expect(p.textureAsset, startsWith('assets/textures/'));
      expect(p.radius, greaterThan(0));
    }
    final saturn = PlanetCatalog.planets.firstWhere((p) => p.id == 'saturn');
    expect(saturn.hasRing, isTrue);
  });

  test('selecting a mission planet completes it + toasts', () {
    final c = makeController();
    expect(c.state.missions.where((m) => m.completed), isEmpty);
    c.selectPlanet('earth');
    expect(c.state.selectedPlanetId, 'earth');
    expect(c.state.focusedPlanetId, 'earth');
    expect(c.state.missions.firstWhere((m) => m.targetPlanetId == 'earth').completed, isTrue);
    expect(c.state.toasts, isNotEmpty);
    c.closeDetail();
    expect(c.state.selectedPlanetId, isNull);
    expect(c.state.focusedPlanetId, isNull);
    c.dispose();
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

  test('toggles flip state', () {
    final c = makeController();
    c.toggleRunning();
    expect(c.state.running, isFalse);
    c.toggleOrbits();
    expect(c.state.showOrbits, isFalse);
    c.toggleLabels();
    expect(c.state.showLabels, isFalse);
    c.setTab(ExplorerTab.missions);
    expect(c.state.tab, ExplorerTab.missions);
    c.dispose();
  });
}
