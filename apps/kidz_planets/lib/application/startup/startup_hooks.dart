// ignore_for_file: prefer_initializing_formals

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:avatar/scene.dart';
import 'package:core/startup.dart';
import 'package:mission/domain.dart';
import 'package:planets/audio.dart';
import 'package:planets/scene.dart';
import 'package:planets/state.dart';

import '../../dependency_injection/injection.dart';
import 'solar_system_startup_tasks.dart';

/// Real startup work: the composition root's calls into feature-owned APIs.
///
/// Extends the no-op [SolarSystemStartupHooks] from the wiring table with the
/// real calls. The [startupRef] is read-only and never watched: startup runs
/// once, and a rebuild subscription on any of these providers would re-run the
/// universe.
class RealSolarSystemStartupHooks extends SolarSystemStartupHooks {
  const RealSolarSystemStartupHooks({Ref? startupRef}) : _ref = startupRef;

  final Ref? _ref;

  /// Configures the shared audio session (moved out of `main`).
  ///
  /// The session is a process-wide platform object, not reactive state, so it
  /// lives in GetIt exactly as before — only the timing moved: after the
  /// first intro frame instead of before `runApp`.
  @override
  Future<void> configureSession(StartupTaskContext context) async {
    reportStage(context, 0.2);
    await configureDependencies();
    reportStage(context, 1.0, message: StartupMessage.preparing);
  }

  /// Builds the Sun, starfield, planets and orbits behind the intro.
  ///
  /// The same `ensureBuilt` the scene view calls, so the Explorer's first
  /// frame finds a finished scene instead of decoding it. Idempotent through
  /// the controller's memoized future: a retry after a later failure joins
  /// the finished build instead of decoding eight megabytes twice.
  @override
  Future<void> buildSolarSystem(StartupTaskContext context) async {
    final ref = _requireRef('planets.scene');
    final controller = ref.read(solarSystemSceneControllerProvider);
    final planets = ref.read(planetsProvider);
    reportStage(context, 0.05, message: StartupMessage.solarSystem);
    await controller.ensureBuilt(
      planets: planets,
      onProgress: (fraction, label) {
        reportStage(
          context,
          0.05 + 0.95 * fraction,
          message: _messageForSceneLabel(label),
        );
      },
    );
    await yieldToIntro();
    reportStage(context, 1.0, message: StartupMessage.planets);
  }

  /// Reads the bundled mission catalogue through the app's use case.
  ///
  /// Microseconds of const data, but the coordinator's contract is that
  /// progress reflects real work — so the read really happens here, once, and
  /// its (tiny) weight moves the bar.
  @override
  Future<void> loadMissions(StartupTaskContext context) async {
    reportStage(context, 0.3);
    const GetMissionsUseCase().call();
    await yieldToIntro();
    reportStage(context, 1.0, message: StartupMessage.missions);
  }

  /// Primes the companion's geometry caches on the UI thread.
  ///
  /// The meshes the rocket toy is built from are value-keyed caches; filling
  /// them now (a few milliseconds of arithmetic, no GPU upload) means the
  /// first Explorer frame does not hitch constructing them mid-gesture.
  @override
  Future<void> primeCompanion(StartupTaskContext context) async {
    final geometries = AvatarGeometryFactory();
    reportStage(context, 0.3);
    geometries
      ..rocketBody()
      ..noseCone()
      ..porthole()
      ..fin()
      ..engineNozzle()
      ..target();
    await yieldToIntro();
    reportStage(context, 1.0, message: StartupMessage.companion);
  }

  /// Creates the two shared ambience players after the audio session.
  ///
  /// Lazy singletons, so reading them here builds each player exactly once;
  /// the `main` overrides then hand the same instances to every feature.
  @override
  Future<void> prepareSounds(StartupTaskContext context) async {
    reportStage(context, 0.3);
    locator<PlanetSoundService>();
    locator<PlanetNarrationService>();
    await yieldToIntro();
    reportStage(context, 1.0, message: StartupMessage.sounds);
  }

  /// Paints the moons onto the already-built scene.
  ///
  /// Depends on the solar-system task and runs after it: eighteen small
  /// textures a child cannot see until they zoom into a planet. Kept required
  /// (rather than lazy) so the bar cannot hit 100% while moons are still
  /// missing — the prototype's Saturn milestone pops at ~68%, and the real
  /// ringed planet must be on screen to earn it.
  @override
  Future<void> buildMoons(StartupTaskContext context) async {
    final ref = _requireRef('planets.moons');
    final controller = ref.read(solarSystemSceneControllerProvider);
    final moons = ref
        .read(planetsProvider)
        .where((planet) => planet.isMoon)
        .toList(growable: false);
    reportStage(context, 0.05, message: StartupMessage.moons);
    await controller.ensureMoonsBuilt(
      moons: moons,
      onProgress: (fraction, _) {
        reportStage(
          context,
          0.05 + 0.95 * fraction,
          message: StartupMessage.moons,
        );
      },
    );
    await yieldToIntro();
    reportStage(context, 1.0, message: StartupMessage.moons);
  }

  Ref _requireRef(String taskId) {
    final ref = _ref;
    if (ref == null) {
      throw StateError(
        'Startup task "$taskId" needs the app container; '
        'tests must pass explicit hooks instead.',
      );
    }
    return ref;
  }

  /// Maps the builder's English stage labels onto typed progress messages.
  ///
  /// The builder reports labels like `Painting Saturn…`; the intro resolves
  /// copy through the typed enum instead, so this translates the free text
  /// into the phase the bar is actually in.
  StartupMessage _messageForSceneLabel(String label) {
    if (label.startsWith('Painting stars')) return StartupMessage.solarSystem;
    if (label.startsWith('Painting Sun')) return StartupMessage.sun;
    if (label.startsWith('Painting')) return StartupMessage.planets;
    return StartupMessage.solarSystem;
  }
}
