import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'avatar_impact_sound.dart';

/// The companion's bounce sound, shared by every companion on screen.
///
/// A throw can outlive the widget that started it, and creating a player per
/// impact would mean creating one per frame of a fast throw, so the players
/// are pooled and owned here for the life of the provider.
final avatarImpactSoundProvider = Provider<AvatarImpactSound>((ref) {
  final sound = AvatarImpactSound();
  ref.onDispose(sound.dispose);
  return sound;
});
