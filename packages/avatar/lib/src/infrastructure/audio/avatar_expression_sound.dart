import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:avatar/state.dart';

import 'avatar_impact_sound.dart';

/// The sound the companion makes when it changes expression.
///
/// One cue per expression, played when the expression *changes* rather than
/// while it lasts. That distinction is the whole design: a reaction runs for
/// 900 ms to 2600 ms, and a cue that fires on a timer through that window
/// stutters, whereas one that fires on the transition plays once, in step with
/// the face, and cannot overlap itself.
///
/// Every [AvatarReaction] is covered by the compiler rather than by a lookup
/// table with a default, so adding a reaction to the enum is a build error here
/// until it has a sound. The reverse is also true: a cue nobody can reach is
/// a file nobody hears, which is why `confused` and the mission-beat cues are
/// wired to real state in `avatar_controller.dart` rather than left orphaned.
class AvatarExpressionSound {
  /// [playerFactory] builds each player, injectable for the same reason as in
  /// `AvatarImpactSound`: a test that substitutes only one still leaves real
  /// players behind it, so it cannot prove the pool is needed.
  AvatarExpressionSound({
    AudioPlayer Function()? playerFactory,
    this.voiceActive = false,
  }) : _players = List.generate(
         _poolSize,
         (_) => (playerFactory ?? AudioPlayer.new)(),
       ) {
    for (final player in _players) {
      unawaited(player.setAndroidAudioAttributes(_sonification));
    }
  }

  /// Two players: the incoming cue and the one fading out under it.
  ///
  /// A reaction that replaces another is a normal event, not an edge case
  /// (tapping the companion twice in a row), and a single player would cut the
  /// first cue off instantly. Two allow the swap to crossfade, which is what
  /// makes a rapid change sound like one expression becoming another.
  static const int _poolSize = 2;

  static const AndroidAudioAttributes _sonification = AndroidAudioAttributes(
    contentType: AndroidAudioContentType.sonification,
    usage: AndroidAudioUsage.assistanceSonification,
  );

  final List<AudioPlayer> _players;

  /// Whether narration is currently playing.
  ///
  /// Set by the owner rather than polled, because a cue cannot be quiet enough
  /// to be safe *and* audible at the same time: narration is the one thing the
  /// child is being asked to listen to, so an expression cue ducks under it
  /// instead of competing. [duckedVolume] is the factor that results.
  bool voiceActive;

  /// How loud a cue plays when narration is running.
  ///
  /// Low, because a companion reacting to a tap should still be felt while
  /// someone is reading a planet aloud, and a full-volume cue is what makes
  /// children reach for the volume button.
  static const double duckedVolume = 0.22;

  /// The volume an ordinary cue plays at.
  ///
  /// Under the narration voice (0.92) and the mission result cues, and above
  /// the ambient bed (0.42): an expression is a direct response to something
  /// the child just did, so it has to cut through the planet music without
  /// being the loudest thing on screen.
  static const double baseVolume = 0.6;

  /// The volume a mission-beat cue plays at, before ducking.
  ///
  /// Lower than [baseVolume] because the long mission success/failure cue is
  /// already sounding: the companion adds a short layer on top of it rather
  /// than competing with it. Priority order is voice (0.92) > mission result
  /// cue (0.65-0.7) > mission avatar cue (0.5) > expression cue (0.6 alone,
  /// ducked under voice) > ambient bed (0.42) > movement.
  static const double missionVolume = 0.5;

  /// The volume the throw whoosh plays at, before ducking.
  ///
  /// An ambient/movement sound, so the quietest of the set: it marks motion
  /// without reading as a reaction.
  static const double throwVolume = 0.35;

  /// Minimum gap between two throw whooshes.
  static const Duration throwCooldown = Duration(milliseconds: 350);

  int _next = 0;
  bool _disposed = false;
  AvatarExpressionCue? _current;
  DateTime _lastThrowAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// The cue currently sounding, exposed for tests and for the dedupe check.
  AvatarExpressionCue? get currentCue => _current;

  /// Plays the cue for [reaction], if [reaction] has one.
  ///
  /// Returns whether anything played. `none` is the resting state, so it stops
  /// the current cue instead of adding a sound for doing nothing.
  Future<bool> play(AvatarReaction reaction) async {
    if (_disposed) return false;

    final cue = AvatarExpressionSoundCatalog.cueFor(reaction);
    return playCue(cue);
  }

  /// Plays the cue for a mission beat, if [mood] has one.
  ///
  /// Separate entry point (rather than folding mission cues into [play])
  /// because mission beats are a different vocabulary from reactions: the same
  /// laugh can arrive as a celebration or as a tap, and the cue that belongs
  /// with it depends on what the *mission* is doing, not on the pose.
  /// Mission cues duck harder ([missionVolume]) because they always play
  /// alongside the long mission result cue.
  Future<bool> playMission(AvatarMood mood) async {
    if (_disposed) return false;
    return playCue(
      AvatarExpressionSoundCatalog.missionCueFor(mood),
      volume: missionVolume,
    );
  }

  /// Plays an idle-pose cue (thinking / heart), used for poses that live in
  /// [AvatarIdleAction] rather than in [AvatarReaction].
  Future<bool> playIdle(AvatarExpressionCue? cue) => playCue(cue);

  /// Plays the throw whoosh for a flick. Rate-limited by [cooldown]: a throw
  /// reports one launch but the gesture can re-fire from pointer echoes, and
  /// two whooshes on one flick read as a stutter.
  ///
  /// Bypasses the transition dedupe on purpose: the whoosh is a one-shot
  /// movement sound rather than an expression state, so two flicks in a row
  /// must both be heard. The cooldown is the only limiter.
  Future<bool> playThrowWhoosh({DateTime? now}) async {
    if (_disposed) return false;
    final at = (now ?? DateTime.now()).toUtc();
    if (at.difference(_lastThrowAt) < throwCooldown) return false;
    _lastThrowAt = at;
    if (_current == AvatarExpressionSoundCatalog.throwWhoosh) {
      _current = null;
    }
    return playCue(
      AvatarExpressionSoundCatalog.throwWhoosh,
      volume: throwVolume,
    );
  }

  /// Plays [cue], fading the outgoing cue underneath it.
  ///
  /// `null` stops the current cue instead of adding a sound for doing
  /// nothing. Returns whether anything played.
  Future<bool> playCue(AvatarExpressionCue? cue, {double? volume}) async {
    if (_disposed) return false;

    if (cue == null) {
      await stop();
      return false;
    }

    // The transition guard. The state is only rewritten when a reaction really
    // changes, but `react()` is called from gesture handlers, mission beats and
    // timers, and the same reaction can arrive from two of them at once. Keying
    // on the cue rather than on a timestamp means an identical cue cannot
    // double-trigger even when it is asked for twice inside a frame.
    if (cue == _current) return false;
    _current = cue;

    final player = _players[_next];
    final outgoing = _players[1 - _next];
    _next = 1 - _next;

    final target = volume ?? baseVolume;
    final level = target * (voiceActive ? duckedVolume : 1.0);
    try {
      // Fade the outgoing cue rather than stopping it, so replacing an
      // expression does not click.
      unawaited(_fadeOut(outgoing));
      await player.stop();
      await player.setVolume(level);
      await player.setAsset(cue.asset);
      unawaited(player.play().catchError((Object _) {}));
      return true;
    } catch (error) {
      debugPrint('Avatar expression sound unavailable ($error)');
      return false;
    }
  }

  /// Fades and stops the sounding cue, and resets the dedupe key.
  ///
  /// Called when the expression returns to `none` so that a later reaction to
  /// the same value plays again: the child taps the companion, it goes back to
  /// rest, and a second tap must be heard as a second tap.
  Future<void> stop() async {
    if (_disposed) return;
    _current = null;
    for (final player in _players) {
      await _fadeOut(player);
    }
  }

  Future<void> _fadeOut(AudioPlayer player) async {
    const duration = Duration(milliseconds: 90);
    const steps = 5;
    try {
      for (var step = 1; step <= steps; step++) {
        await Future<void>.delayed(duration ~/ steps);
        await player.setVolume(0);
      }
      await player.stop();
    } catch (_) {
      // A player that has already gone is not a reason to fail a stop.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _current = null;
    for (final player in _players) {
      try {
        await player.stop();
      } catch (_) {}
      await player.dispose();
    }
  }
}

/// One expression sound: the asset and the expression it belongs to.
class AvatarExpressionCue {
  const AvatarExpressionCue({
    required this.reaction,
    required this.asset,
    required this.description,
  });

  final AvatarReaction reaction;
  final String asset;

  /// What this cue is for, in words.
  ///
  /// Written into the code rather than left implicit because a cue whose
  /// meaning is only in its filename is a cue nobody can review: the asset
  /// tests can check that every reaction has a file, and only a human reading
  /// this can check that the file is the *right* file.
  final String description;

  @override
  bool operator ==(Object other) =>
      other is AvatarExpressionCue &&
      other.reaction == reaction &&
      other.asset == asset;

  @override
  int get hashCode => Object.hash(reaction, asset);

  @override
  String toString() => 'AvatarExpressionCue(${reaction.name})';
}

abstract final class AvatarExpressionSoundCatalog {
  /// MP3, matching the bounce, the mission cues and the narration, which are
  /// the only audio paths confirmed to play on every target.
  /// All avatar expression SFX live under `assets/audio/sfx/avatar/`.

  /// The cue for [reaction], or `null` for the resting state.
  ///
  /// An exhaustive switch with no default, deliberately. A `null` default would
  /// let a new [AvatarReaction] compile and then play nothing, which is exactly
  /// the silent-expression failure this exists to prevent; here the build fails
  /// instead, which is findable.
  static AvatarExpressionCue? cueFor(AvatarReaction reaction) {
    return switch (reaction) {
      // Resting. No sound: the companion going quiet is the correct reading of
      // `none`, and a cue here would fire every time a reaction timed out.
      AvatarReaction.none => null,
      AvatarReaction.happy => const AvatarExpressionCue(
        reaction: AvatarReaction.happy,
        asset: 'assets/audio/sfx/avatar/avatar_happy.mp3',
        description: 'A short rising two-note lift.',
      ),
      AvatarReaction.surprised => const AvatarExpressionCue(
        reaction: AvatarReaction.surprised,
        asset: 'assets/audio/sfx/avatar/avatar_surprised.mp3',
        description: 'A quick upward leap and a held top.',
      ),
      AvatarReaction.sad => const AvatarExpressionCue(
        reaction: AvatarReaction.sad,
        asset: 'assets/audio/sfx/avatar/avatar_sad.mp3',
        description: 'A falling pair, softened at the end.',
      ),
      AvatarReaction.dizzy => const AvatarExpressionCue(
        reaction: AvatarReaction.dizzy,
        asset: 'assets/audio/sfx/avatar/avatar_dizzy.mp3',
        description: 'Two detuned tones beating against each other.',
      ),
      AvatarReaction.excited => const AvatarExpressionCue(
        reaction: AvatarReaction.excited,
        asset: 'assets/audio/sfx/avatar/avatar_excited.mp3',
        description: 'A fast high run, clearly quicker than happy.',
      ),
      AvatarReaction.sleepy => const AvatarExpressionCue(
        reaction: AvatarReaction.sleepy,
        asset: 'assets/audio/sfx/avatar/avatar_sleepy.mp3',
        description: 'A long quiet falling sigh.',
      ),
      AvatarReaction.laughing => const AvatarExpressionCue(
        reaction: AvatarReaction.laughing,
        asset: 'assets/audio/sfx/avatar/avatar_laughing.mp3',
        description: 'Three rising unvoiced puffs.',
      ),
      AvatarReaction.talking => const AvatarExpressionCue(
        reaction: AvatarReaction.talking,
        asset: 'assets/audio/sfx/avatar/avatar_talking.mp3',
        description: 'One soft blip marking the start of speech.',
      ),
      AvatarReaction.confused => const AvatarExpressionCue(
        reaction: AvatarReaction.confused,
        asset: 'assets/audio/sfx/avatar/avatar_confused.mp3',
        description: 'A rising wobble that stalls and falls back.',
      ),
    };
  }

  /// The cue for a mission beat, chosen by what the mission is doing.
  ///
  /// Separate from [cueFor] because these are not reactions: the mission
  /// already plays a long success or failure cue, and this is the short one the
  /// companion adds on top of it. Mapping them by mood rather than by reaction
  /// keeps "success" and "failure" addressable even though both arrive at the
  /// companion as a laugh or a droop.
  static AvatarExpressionCue? missionCueFor(AvatarMood mood) {
    return switch (mood) {
      AvatarMood.success => const AvatarExpressionCue(
        reaction: AvatarReaction.laughing,
        asset: 'assets/audio/sfx/avatar/avatar_success.mp3',
        description: 'A clipped major triad, mixed under the mission cue.',
      ),
      AvatarMood.wrong => const AvatarExpressionCue(
        reaction: AvatarReaction.sad,
        asset: 'assets/audio/sfx/avatar/avatar_failure.mp3',
        description: 'Two low notes that turn back up to invite a retry.',
      ),
      AvatarMood.instruction => const AvatarExpressionCue(
        reaction: AvatarReaction.talking,
        asset: 'assets/audio/sfx/avatar/avatar_find_object.mp3',
        description: 'A two-note attention-getting call before a clue.',
      ),
      AvatarMood.searching || AvatarMood.retry => null,
    };
  }

  /// The cue for a pose that is a state in its own right.
  ///
  /// `thinking` and `sendingHeart` are [AvatarIdleAction]s rather than
  /// reactions, so they cannot be reached through [cueFor]. They are not
  /// folded into the reaction enum: they are already in the state system, and
  /// inventing a parallel "expression" field to hold them would be the
  /// duplicate vocabulary this design is trying to avoid.
  static const thinking = AvatarExpressionCue(
    reaction: AvatarReaction.none,
    asset: 'assets/audio/sfx/avatar/avatar_thinking.mp3',
    description: 'Two leaning mid tones that never resolve.',
  );

  static const love = AvatarExpressionCue(
    reaction: AvatarReaction.happy,
    asset: 'assets/audio/sfx/avatar/avatar_love.mp3',
    description: 'A bright high sparkle, for the heart pose.',
  );

  /// The whoosh for a fast drag / throw launch.
  static const throwWhoosh = AvatarExpressionCue(
    reaction: AvatarReaction.none,
    asset: 'assets/audio/sfx/avatar/avatar_throw_whoosh.mp3',
    description: 'A fast airy sweep marking a flick.',
  );

  /// The cue for an idle pose that is a state in its own right.
  ///
  /// `thinking` and `sendingHeart` are [AvatarIdleAction]s rather than
  /// reactions. `dancing` shares the love sparkle: it is the only other
  /// celebratory pose and a dedicated cue would read as a second reward
  /// fanfare. `sitting` and `flying` are locomotion rather than
  /// expressions, so they stay silent: a cue every time the companion parked
  /// itself would be a metronome, not a reaction.
  static AvatarExpressionCue? idleCueFor(AvatarIdleAction idle) {
    return switch (idle) {
      AvatarIdleAction.thinking => thinking,
      AvatarIdleAction.sendingHeart => love,
      AvatarIdleAction.dancing => love,
      AvatarIdleAction.none ||
      AvatarIdleAction.sitting ||
      AvatarIdleAction.flying => null,
    };
  }

  /// Every asset the catalog can reach, for the asset test.
  ///
  /// Derived from the catalog rather than listed by hand, so a cue added above
  /// is covered by the asset test without anyone remembering to update a second
  /// list. De-duplicated: the love cue backs both `sendingHeart` and
  /// `dancing`, so a set is what keeps the asset test from counting it twice.
  static Iterable<String> get allAssets sync* {
    final seen = <String>{};

    for (final reaction in AvatarReaction.values) {
      final cue = cueFor(reaction);
      if (cue != null && seen.add(cue.asset)) yield cue.asset;
    }
    for (final mood in AvatarMood.values) {
      final cue = missionCueFor(mood);
      if (cue != null && seen.add(cue.asset)) yield cue.asset;
    }
    for (final idle in AvatarIdleAction.values) {
      final cue = idleCueFor(idle);
      if (cue != null && seen.add(cue.asset)) yield cue.asset;
    }
    if (seen.add(throwWhoosh.asset)) yield throwWhoosh.asset;
  }

  /// Every expression the avatar system can currently show, paired with the
  /// asset that must sound with it. Used by the coverage test: adding an
  /// expression without a cue fails the test instead of shipping silent.
  static Iterable<(String expression, String asset)>
  get expressionCoverage sync* {
    for (final reaction in AvatarReaction.values) {
      if (reaction == AvatarReaction.none) continue;
      final cue = cueFor(reaction);
      yield (reaction.name, cue?.asset ?? '<missing>');
    }
    for (final mood in AvatarMood.values) {
      final cue = missionCueFor(mood);
      if (cue != null) yield ('mood:${mood.name}', cue.asset);
    }
    for (final idle in AvatarIdleAction.values) {
      final cue = idleCueFor(idle);
      if (cue != null) yield ('idle:${idle.name}', cue.asset);
    }
    yield ('throw', throwWhoosh.asset);
    yield ('bounce', AvatarImpactSoundCatalog.bounce);
  }
}
