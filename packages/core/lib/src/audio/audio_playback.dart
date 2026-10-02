/// Playback of a single audio asset.
///
/// The narrowest useful audio contract in the app. A feature asks for a sound
/// by asset path and does not learn whether just_audio, a platform channel or a
/// silent stub answered it, which is what lets domain and controller code be
/// tested with no audio hardware present.
abstract interface class AudioPlayback {
  /// Plays [assetPath] once, honouring [volume] in the range 0..1.
  Future<void> playOnce(String assetPath, {double volume = 1.0});

  /// Starts looping [assetPath] and returns. Any sound already looping through
  /// this same player is crossfaded out.
  Future<void> playLooping(String assetPath, {double volume = 1.0});

  /// Fades out whatever is playing and stops it.
  Future<void> stop();

  /// Releases the underlying resources. Safe to call more than once.
  Future<void> dispose();
}

/// Narration read aloud for a catalogue entry.
///
/// Split from [AudioPlayback] because narration is content-addressed (it has a
/// per-language asset tree and a fallback) while effects are not. Keeping the
/// two apart stops a narration lookup from being reused as an effect path.
abstract interface class NarrationPlayback {
  /// Reads [assetPath] aloud, or does nothing if the file is absent.
  Future<void> speak(String assetPath);

  Future<void> stop();

  Future<void> dispose();
}
