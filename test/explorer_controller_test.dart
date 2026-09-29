import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/controllers/explorer_controller.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/application/state/simulation_clock.dart';
import 'package:kidz_planets/domain/entities/mission.dart';
import 'package:kidz_planets/domain/entities/planet.dart';

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

  Hotspot hotspot(String title) =>
      Hotspot(title: title, description: 'about $title', icon: '🔭');

  setUp(makeController);

  group('showHotspot', () {
    test('overrides the detail copy with the hotspot text', () {
      c.selectPlanet('mars');
      c.showHotspot(hotspot('Polar Ice Caps'));

      expect(c.state.detailTitleOverride, 'Polar Ice Caps');
      expect(c.state.detailDescriptionOverride, 'about Polar Ice Caps');
    });

    test('tilts the camera up for a polar hotspot', () {
      c.selectPlanet('mars');
      c.showHotspot(hotspot('Polar Ice Caps'));

      expect(c.state.detailPhi, 0.95);
    });

    test('recognises an ice hotspot as polar', () {
      c.selectPlanet('mars');
      c.showHotspot(hotspot('Frozen Ice'));

      expect(c.state.detailPhi, 0.95);
    });

    test('pulls back for a ring hotspot', () {
      c.selectPlanet('saturn');
      c.showHotspot(hotspot('Ring System'));

      expect(c.state.detailPhi, 0.65);
      expect(c.state.detailZoom, 0.85);
    });

    test('recognises Cassini and tilt as ring keywords', () {
      for (final title in ['Cassini Division', 'Axial Tilt']) {
        c.selectPlanet('saturn');
        c.showHotspot(hotspot(title));
        expect(c.state.detailZoom, 0.85, reason: title);
      }
    });

    test('toasts for a storm hotspot', () {
      c.selectPlanet('jupiter');
      c.showHotspot(hotspot('The Great Red Spot'));

      expect(c.state.toasts.map((t) => t.text), contains('The Great Red Spot'));
    });

    test('recognises storm and flare keywords', () {
      for (final title in ['Great Storm', 'Solar Flares']) {
        makeController();
        c.selectPlanet('jupiter');
        c.showHotspot(hotspot(title));
        expect(c.state.toasts, isNotEmpty, reason: title);
      }
    });

    test('leaves the camera alone for an ordinary hotspot', () {
      c.selectPlanet('mars');
      c.updateDetailCamera(zoom: 1.4, theta: 0.2, phi: 0.5);
      c.showHotspot(hotspot('Craters and Dust'));

      expect(c.state.detailZoom, 1.4);
      expect(c.state.detailPhi, 0.5);
    });

    test('shows a polar camera angle and a ring zoom when both match', () {
      c.selectPlanet('saturn');
      c.showHotspot(hotspot('Polar Ring'));

      // polar is checked first for the angle, rings first for the zoom.
      expect(c.state.detailPhi, 0.95);
      expect(c.state.detailZoom, 0.85);
    });
  });

  group('runExperiment', () {
    test('earth experiment sets the alert without selecting anything', () {
      c.runExperiment('earth');

      expect(c.state.playgroundAlertIcon, '🔥');
      expect(c.state.playgroundAlertTitle, contains('Earth'));
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

      expect(c.state.playgroundAlertTitle, contains('Earth'));
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
      expect(c.state.playgroundAlertTitle, 'Sandbox Ready!');
    });

    test('confirms the reset with a toast', () {
      c.resetPlayground();

      expect(c.state.toasts.single.text, contains('Sandbox Ready!'));
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

      expect(c.state.celebrationTitle, 'Find Earth');
      expect(c.state.celebrationDescription, contains('Find Earth'));
      expect(c.state.toasts.single.text, contains('Find Earth'));
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
      c.showHotspot(hotspot('Ring System'));

      c.selectPlanet('mars');

      expect(c.state.detailTitleOverride, isNull);
      expect(c.state.detailDescriptionOverride, isNull);
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
      c.showToast('one');
      c.showToast('two');

      expect(c.state.toasts.map((t) => t.text), ['one', 'two']);
      expect(c.state.toasts[0].key, isNot(c.state.toasts[1].key));
    });

    // Each toast used to share one timer, so a second toast cancelled the
    // first one's dismissal and left it on screen forever.
    test('a toast clears itself after three seconds', () {
      fakeAsync((async) {
        c.showToast('one');

        async.elapse(const Duration(seconds: 3));
        expect(c.state.toasts, isEmpty);
      });
    });

    test('every toast clears itself once its own timer runs', () {
      fakeAsync((async) {
        c.showToast('one');
        c.showToast('two');

        async.elapse(const Duration(seconds: 3));
        expect(c.state.toasts, isEmpty);
      });
    });

    test('stacked toasts disappear independently', () {
      fakeAsync((async) {
        c.showToast('one');
        async.elapse(const Duration(seconds: 2));
        c.showToast('two');

        // The first toast is due first, so it goes before the second.
        async.elapse(const Duration(seconds: 1));
        expect(c.state.toasts.map((t) => t.text), ['two']);

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
      c.showCelebration('Nice', 'You found it.');
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
