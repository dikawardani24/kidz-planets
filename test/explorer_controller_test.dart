import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/controllers/explorer_controller.dart';
import 'package:kidz_planets/application/state/app_message.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/application/state/simulation_clock.dart';
import 'package:kidz_planets/data/datasources/planet_catalog.dart';
import 'package:kidz_planets/domain/entities/mission.dart';
import 'package:kidz_planets/domain/entities/planet.dart';

import 'helpers/app_messages.dart';

const List<Mission> kMissions = [
  Mission(id: 1, title: 'Find Earth', description: 'd1', targetPlanetId: 'earth'),
  Mission(id: 2, title: 'Visit Mars', description: 'd2', targetPlanetId: 'mars'),
];

void main() {
  // ExplorerController owns a PlanetSoundService, and AudioPlayer registers an
  // audio_session channel in its constructor.
  TestWidgetsFlutterBinding.ensureInitialized();

  late SimulationClock clock;
  late ExplorerController c;

  void makeController({List<Mission> missions = kMissions}) {
    clock = SimulationClock();
    c = ExplorerController(clock: clock, initialMissions: missions);
    addTearDown(c.dispose);
  }

  /// A real catalogue hotspot, found by slug. Framing and toasts are keyed on
  /// slugs rather than English titles, so the fixtures have to be real ones:
  /// a made-up title would pass a substring check and prove nothing.
  HotspotRef hotspot(String slug, {String planetId = 'earth'}) {
    final planet = PlanetCatalog.planets.firstWhere((p) => p.hotspots.any((h) => h.slug == slug),
        orElse: () => throw ArgumentError('no hotspot $slug in the catalogue'));
    return HotspotRef(
      planetId: planetId,
      hotspot: planet.hotspots.firstWhere((h) => h.slug == slug),
    );
  }

  setUp(makeController);

  group('showHotspot', () {
    test('holds the hotspot as a reference, not as English text', () {
      final ref = hotspot('polar_ice_caps', planetId: 'mars');
      c.selectPlanet('mars');
      c.showHotspot(ref.hotspot, planetId: 'mars');

      expect(c.state.detailHotspot, ref);
    });

    test('tilts the camera up for a polar hotspot', () {
      c.selectPlanet('mars');
      c.showHotspot(hotspot('polar_ice_caps').hotspot, planetId: 'mars');

      expect(c.state.detailPhi, 0.95);
    });

    test('tilts up for cloud and crater hotspots too', () {
      for (final slug in ['white_cirrus_clouds', 'cratered_face']) {
        makeController();
        c.selectPlanet('venus');
        c.showHotspot(hotspot(slug).hotspot, planetId: hotspot(slug).planetId);
        expect(c.state.detailPhi, 0.95, reason: slug);
      }
    });

    test('pulls back for the ring hotspot', () {
      c.selectPlanet('saturn');
      c.showHotspot(hotspot('icy_rings').hotspot, planetId: 'saturn');

      expect(c.state.detailPhi, 0.65);
      expect(c.state.detailZoom, 0.85);
    });

    test('toasts for a storm hotspot', () {
      c.selectPlanet('jupiter');
      final ref = hotspot('great_red_spot', planetId: 'jupiter');
      c.showHotspot(ref.hotspot, planetId: 'jupiter');

      expect(c.state.toasts.single.hotspot, ref);
    });

    test('toasts for runaway heat and solar wind', () {
      for (final slug in ['runaway_heat', 'solar_wind']) {
        makeController();
        c.selectPlanet('venus');
        c.showHotspot(hotspot(slug).hotspot, planetId: hotspot(slug).planetId);
        expect(c.state.toasts, isNotEmpty, reason: slug);
      }
    });

    test('leaves the camera alone for an ordinary hotspot', () {
      c.selectPlanet('moon');
      c.updateDetailCamera(zoom: 1.4, theta: 0.2, phi: 0.5);
      c.showHotspot(hotspot('liquid_oceans').hotspot, planetId: 'earth');

      expect(c.state.detailZoom, 1.4);
      expect(c.state.detailPhi, 0.5);
    });

    test('every slug in the catalogue is classified or plainly unremarkable',
        () {
      // A new hotspot that matches no rule is fine: it just keeps the camera
      // where it was. What must not happen is a slug that no longer exists,
      // because that is how camera framing quietly stops applying.
      final polar = {'polar_ice_caps', 'white_cirrus_clouds', 'cratered_face'};
      final rings = {'icy_rings'};
      final storm = {'great_red_spot', 'runaway_heat', 'solar_wind'};
      final slugs = PlanetCatalog.planets
          .expand((p) => p.hotspots)
          .map((h) => h.slug)
          .toSet();
      expect(slugs, isNotEmpty);
      // Sanity: the fixtures the other tests use are still catalogue slugs.
      expect(slugs, containsAll([...polar, ...rings, ...storm]));
    });
  });

  group('runExperiment', () {
    test('earth experiment sets the alert without selecting anything', () {
      c.runExperiment('earth');

      expect(c.state.playgroundAlertIcon, '🔥');
      expect(c.state.playgroundAlertTitle.id, AppMessageId.alertEarthTitle);
      expect(c.state.playgroundAlertDescription.id, AppMessageId.alertEarthDescription);
      expect(c.state.selectedPlanetId, isNull);
    });

    test('saturn experiment focuses saturn', () {
      c.runExperiment('saturn');

      expect(c.state.playgroundAlertIcon, '🪐');
      expect(c.state.selectedPlanetId, 'saturn');
    });

    test('jupiter experiment focuses jupiter', () {
      c.runExperiment('jupiter');

      expect(c.state.playgroundAlertIcon, '🌪️');
      expect(c.state.selectedPlanetId, 'jupiter');
    });

    test('sun experiment focuses the sun', () {
      c.runExperiment('sun');

      expect(c.state.playgroundAlertIcon, '☀️');
      expect(c.state.selectedPlanetId, 'sun');
    });

    test('an unknown experiment leaves the alert alone', () {
      c.runExperiment('earth');
      c.runExperiment('pluto');

      expect(c.state.playgroundAlertTitle.id, AppMessageId.alertEarthTitle);
    });

    test('an unknown experiment still returns to the explore tab', () {
      c.setTab(ExplorerTab.playground);
      c.runExperiment('pluto');

      expect(c.state.tab, ExplorerTab.explore);
    });
  });

  group('resetPlayground', () {
    test('restores the sandbox defaults', () {
      c.setSpeed(4);
      c.toggleOrbits();
      c.toggleLabels();
      c.runExperiment('sun');

      c.resetPlayground();

      expect(c.state.speed, 1.0);
      expect(clock.speed, 1.0, reason: 'the simulation clock is reset too');
      expect(c.state.showOrbits, isTrue);
      expect(c.state.showLabels, isTrue);
      expect(c.state.playgroundAlertIcon, '🔥');
      expect(c.state.playgroundAlertTitle.id, AppMessageId.alertSandboxTitle);
    });

    test('confirms the reset with a toast', () {
      c.resetPlayground();

      expect(c.state.toasts.single.message!.id, AppMessageId.toastSandboxReady);
    });
  });

  group('completeFirstPendingFor', () {
    test('completes the first pending mission for that planet', () {
      c.completeFirstPendingFor('earth');

      expect(c.state.missions.first.completed, isTrue);
      expect(c.state.missions.last.completed, isFalse);
    });

    test('celebrates and toasts with the mission title', () {
      c.completeFirstPendingFor('earth');

      expect(c.state.celebrationTitle!.id, AppMessageId.celebrationMissionTitle);
      // The planet id, not its name: the view resolves the name in the active
      // language, and resolved here would hand back the English one.
      expect(c.state.celebrationDescription!.args['planetId'], 'earth');
      expect(c.state.toasts.single.message!.id, AppMessageId.toastMissionVerified);
      expect(c.state.toasts.single.message!.args['title'], 'Find Earth');
    });

    test('does not move the active mission pointer', () {
      c.completeFirstPendingFor('earth');

      // This path is for bodies found outside the mission flow, so the child
      // should still be told about the mission they are actually on.
      expect(c.state.activeMissionId, 1);
    });

    test('ignores a planet with no mission', () {
      c.completeFirstPendingFor('venus');

      expect(c.state.missions.every((m) => !m.completed), isTrue);
      expect(c.state.toasts, isEmpty);
    });

    test('ignores a mission that is already complete', () {
      c.completeFirstPendingFor('earth');
      final toasts = c.state.toasts.length;
      c.completeFirstPendingFor('earth');

      expect(c.state.missions.where((m) => m.completed), hasLength(1));
      expect(c.state.toasts, hasLength(toasts),
          reason: 'a second completion is a no-op, so no new toast');
    });
  });

  group('detail zoom and view', () {
    test('adjustDetailZoom does nothing without a selection', () {
      c.adjustDetailZoom(1);
      expect(c.state.detailZoom, 1.0);
    });

    test('adjustDetailZoom zooms in and out', () {
      c.selectPlanet('mars');
      c.adjustDetailZoom(0.5);
      expect(c.state.detailZoom, 1.5);

      c.adjustDetailZoom(-0.5);
      expect(c.state.detailZoom, 1.0);
    });

    test('adjustDetailZoom clamps at both ends', () {
      c.selectPlanet('mars');
      c.adjustDetailZoom(99);
      expect(c.state.detailZoom, 2.6);

      c.adjustDetailZoom(-99);
      expect(c.state.detailZoom, 0.4);
    });

    test('resetDetailView does nothing without a selection', () {
      c.state = c.state.copyWith(detailZoom: 2.0);
      c.resetDetailView();

      expect(c.state.detailZoom, 2.0);
    });

    test('resetDetailView restores the default framing', () {
      c.selectPlanet('mars');
      c.adjustDetailZoom(1);
      c.updateDetailCamera(theta: 3, phi: 2);

      c.resetDetailView();

      expect(c.state.detailZoom, 1.0);
      expect(c.state.detailTheta, 0.65);
      expect(c.state.detailPhi, 0.28);
    });

    test('toggleDetailCard does nothing without a selection', () {
      c.toggleDetailCard();
      expect(c.state.detailCardVisible, isTrue);
    });

    test('toggleDetailCard flips only with a selection', () {
      c.selectPlanet('mars');
      expect(c.state.detailCardVisible, isFalse,
          reason: 'selecting never opens facts on its own');

      c.toggleDetailCard();
      expect(c.state.detailCardVisible, isTrue);
    });
  });

  group('selection toggle', () {
    test('tapping the focused body again leaves detail mode', () {
      c.selectPlanet('mars');
      c.selectPlanet('mars');

      expect(c.state.selectedPlanetId, isNull);
      expect(c.state.focusedPlanetId, isNull);
    });

    test('selecting a different body keeps detail mode open', () {
      c.selectPlanet('mars');
      c.selectPlanet('venus');

      expect(c.state.selectedPlanetId, 'venus');
    });

    test('selecting clears a stale hotspot override', () {
      c.selectPlanet('saturn');
      c.showHotspot(hotspot('icy_rings').hotspot, planetId: 'saturn');

      c.selectPlanet('mars');

      expect(c.state.detailHotspot, isNull);
    });

    test('selecting shows the spin hint and then dismisses it', () {
      // The timer is created by selectPlanet, so the call has to happen inside
      // the fake clock for elapse to control it.
      fakeAsync((async) {
        c.selectPlanet('mars');
        expect(c.state.spinHintVisible, isTrue);

        async.elapse(const Duration(seconds: 3));
        expect(c.state.spinHintVisible, isTrue);

        async.elapse(const Duration(seconds: 1));
        expect(c.state.spinHintVisible, isFalse);
      });
    });

    test('leaving a tab clears the detail view', () {
      c.selectPlanet('mars');
      c.setTab(ExplorerTab.missions);

      expect(c.state.selectedPlanetId, isNull);
    });
  });

  group('toasts', () {
    test('each toast gets its own key', () {
      c.showToast(TestMessages.named('one'));
      c.showToast(TestMessages.named('two'));

      expect(c.state.toasts.map((t) => t.message!.args['title']), ['one', 'two']);
      expect(c.state.toasts[0].key, isNot(c.state.toasts[1].key));
    });

    // Each toast used to share one timer, so a second toast cancelled the
    // first one's dismissal and left it on screen forever.
    test('a toast clears itself after three seconds', () {
      fakeAsync((async) {
        c.showToast(TestMessages.any);

        async.elapse(const Duration(seconds: 3));
        expect(c.state.toasts, isEmpty);
      });
    });

    test('every toast clears itself once its own timer runs', () {
      fakeAsync((async) {
        c.showToast(TestMessages.any);
        c.showToast(TestMessages.any);

        async.elapse(const Duration(seconds: 3));
        expect(c.state.toasts, isEmpty);
      });
    });

    test('stacked toasts disappear independently', () {
      fakeAsync((async) {
        c.showToast(TestMessages.named('one'));
        async.elapse(const Duration(seconds: 2));
        c.showToast(TestMessages.named('two'));

        // The first toast is due first, so it goes before the second.
        async.elapse(const Duration(seconds: 1));
        expect(c.state.toasts.map((t) => t.message!.args['title']), ['two']);

        async.elapse(const Duration(seconds: 2));
        expect(c.state.toasts, isEmpty);
      });
    });
  });

  group('companion mood', () {
    test('setAvatarMood changes the mood', () {
      c.setAvatarMood(AvatarMood.instruction);
      expect(c.state.avatarMood, AvatarMood.instruction);
    });

    test('setAvatarMood never interrupts a celebration', () {
      // Landing on the mission target is what puts the companion in success.
      c.selectPlanet('earth');
      expect(c.state.avatarMood, AvatarMood.success);

      c.setAvatarMood(AvatarMood.instruction);

      expect(c.state.avatarMood, AvatarMood.success);
    });

    test('a miss puts the companion in the wrong mood', () {
      c.selectPlanet('venus');

      expect(c.state.avatarMood, AvatarMood.wrong);
    });

    test('a miss bumps the key the companion bubble listens to', () {
      final before = c.state.wrongSelectionKey;
      c.selectPlanet('venus');

      expect(c.state.wrongSelectionKey, before + 1);
    });

    test('a miss does not advance the hint level or open a dialog', () {
      c.selectPlanet('venus');

      expect(c.state.missionHintLevel, 0);
      expect(c.state.celebrationTitle, isNull);
    });

    test('retry only applies after a miss', () {
      c.retryMission();
      expect(c.state.avatarMood, AvatarMood.searching,
          reason: 'nothing to retry yet');

      c.selectPlanet('venus');
      c.retryMission();
      expect(c.state.avatarMood, AvatarMood.retry);
    });

    test('retry is a no-op from a calm mood', () {
      c.setAvatarMood(AvatarMood.instruction);
      c.retryMission();

      expect(c.state.avatarMood, AvatarMood.instruction);
    });
  });

  group('closeCelebration', () {
    test('clears the celebration copy', () {
      c.showCelebration(TestMessages.title, TestMessages.description);
      c.closeCelebration();

      expect(c.state.celebrationTitle, isNull);
      expect(c.state.celebrationDescription, isNull);
    });

    test('invites the child into the next mission when one is waiting', () {
      makeController(missions: kMissions);
      c.selectPlanet('earth');
      expect(c.state.avatarMood, AvatarMood.success);

      c.closeCelebration();

      expect(c.state.avatarMood, AvatarMood.instruction);
    });

    test('settles back to calm when every mission is done', () {
      makeController(missions: kMissions);
      c.selectPlanet('earth');
      c.selectPlanet('mars');

      c.closeCelebration();

      expect(c.state.missions.every((m) => m.completed), isTrue);
      expect(c.state.activeMissionId, isNull);
      expect(c.state.avatarMood, AvatarMood.searching);
    });
  });

  group('mission progression', () {
    test('clearing the active mission id stops the checks', () {
      c.state = c.state.copyWith(activeMissionId: null);

      c.selectPlanet('earth');

      expect(c.state.missions.every((m) => !m.completed), isTrue);
      expect(c.state.avatarMood, AvatarMood.searching);
    });

    test('selecting a later planet does not complete an earlier mission', () {
      c.selectPlanet('mars');

      expect(c.state.missions.first.completed, isFalse);
      expect(c.state.missions.last.completed, isFalse);
      expect(c.state.avatarMood, AvatarMood.wrong);
    });
  });
}
