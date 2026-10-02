/// Audio abstractions shared across features.
///
/// Features depend on these ports rather than on `just_audio` directly, so a
/// controller can be tested with a silent fake and no audio hardware.
library;

export 'src/audio/audio_playback.dart';
export 'src/audio/narration_asset_resolver.dart';
