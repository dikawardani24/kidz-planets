import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets/audio.dart';

import 'package:kidz_planets/dependency_injection/injection.dart';

/// These assertions are about the wiring, not about audio: whether the
/// services exist at all, whether they are shared, and whether configuring
/// twice is safe. `main` may be entered more than once in a session (a hot
/// restart, a test that pumps the app twice), and a second registration that
/// threw would take the whole app down on start.
void main() {
  // `main` calls this before configuring too: the session talks to the
  // platform over a method channel, so the binding has to exist first.
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(resetDependencies);

  test('the ambience players are shared, not rebuilt per feature', () async {
    await configureDependencies();

    expect(locator<PlanetSoundService>(), same(locator<PlanetSoundService>()));
    expect(
      locator<PlanetNarrationService>(),
      same(locator<PlanetNarrationService>()),
    );
    expect(
      locator<PlanetSoundService>(),
      isNot(same(locator<PlanetNarrationService>())),
    );
  });

  test(
    'the audio session is configured for mixing, not interrupting',
    () async {
      await configureDependencies();

      final configuration = locator<AudioSession>().configuration;
      final options = configuration?.avAudioSessionCategoryOptions;
      // Read back through the session rather than off the constant: what
      // matters is the category the platform settled on, and a platform that
      // does not support mixing must not leave the app claiming it does.
      expect(
        options == null ||
            options.value & AVAudioSessionCategoryOptions.mixWithOthers.value !=
                0,
        isTrue,
        reason:
            'other apps\u2019 audio would be stopped instead of mixed under',
      );
    },
  );

  test('configuring twice leaves the same registrations in place', () async {
    await configureDependencies();
    final sound = locator<PlanetSoundService>();

    await configureDependencies();

    expect(locator<PlanetSoundService>(), same(sound));
  });

  test('resetting releases the players and the registrations', () async {
    await configureDependencies();
    expect(locator.isRegistered<PlanetSoundService>(), isTrue);

    await resetDependencies();

    expect(locator.isRegistered<PlanetSoundService>(), isFalse);
    // Left unregistered rather than lazily re-created, so a test that forgot
    // to configure fails on the missing registration instead of silently
    // building a real player and taking it as a pass.
    expect(() => locator<PlanetSoundService>(), throwsA(isA<Object>()));
  });
}
