import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:get_it/get_it.dart';

import 'package:planets/audio.dart';

/// The composition root's service locator.
///
/// GetIt is used for exactly one job here: owning the objects that must exist
/// once per app run and that are not reactive state. Riverpod owns state, and
/// nothing here is watched, rebuilt or invalidated. The distinction matters —
/// the moment a service is registered as reactive state it gets two lifetimes,
/// and the app then has to answer which one a widget is holding.
final GetIt locator = GetIt.instance;

/// Registers the singletons the feature packages share.
///
/// Called once from `main`, before `runApp`, because the audio session has to
/// be configured before the first sound plays and awaiting a platform channel
/// from a Riverpod provider is not possible.
///
/// The two players are registered rather than built inside the features because
/// they are shared across feature boundaries. The narration voice belongs to
/// the planets package and the mission celebration cue is started by the app
/// shell, but both are the same ambience: two players would crossfade against
/// each other and the child would hear the mission jingle underneath a planet
/// that is still talking. GetIt is the one place in the workspace allowed to
/// know that.
Future<void> configureDependencies() async {
  if (locator.isRegistered<PlanetSoundService>()) return;

  final session = await AudioSession.instance;

  await session.configure(_mixWithOthersSpeech);

  locator
    ..registerSingleton<AudioSession>(session)
    ..registerLazySingleton<PlanetSoundService>(
      PlanetSoundService.new,
      dispose: (service) => unawaited(service.dispose()),
    )
    ..registerLazySingleton<PlanetNarrationService>(
      PlanetNarrationService.new,
      dispose: (service) => unawaited(service.dispose()),
    );
}

/// Narration that plays over whatever the child already has on.
///
/// A young explorer usually arrives with music or a story playing in another
/// app. `mixWithOthers` keeps that audio alive and mixes this app's sound on
/// top instead of stopping their audio the moment the solar system opens, and
/// the speech attributes keep a planet description intelligible over a
/// background track rather than competing with it as music would.
const AudioSessionConfiguration _mixWithOthersSpeech =
    AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.assistanceSonification,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    );

/// Releases everything [configureDependencies] created.
///
/// Only used by tests, which run several app lifecycles in one process and
/// would otherwise leak players into the next case.
Future<void> resetDependencies() async {
  if (!locator.isRegistered<PlanetSoundService>()) return;
  await locator.reset();
}
