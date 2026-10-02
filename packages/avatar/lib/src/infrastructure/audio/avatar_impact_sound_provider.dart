import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:avatar/state.dart';

import 'avatar_expression_sound.dart';
import 'avatar_impact_sound.dart';

/// The companion's expression SFX, shared by every companion on screen.
///
/// Owned by the provider (rather than built per widget) for the same reason
/// as the impact sound: a throw and its reaction can outlive the widget that
/// started them, and the dedupe key (`_current` cue) must survive rebuilds or
/// the same expression would replay on every frame the widget rebuilds.
final avatarExpressionSoundProvider = Provider<AvatarExpressionSound>((ref) {
  final sound = AvatarExpressionSound();
  ref.onDispose(sound.dispose);
  return sound;
});

/// Resolves the single SFX cue for the companion's full expressive state.
///
/// Central rule — `AvatarExpression → Expression Animation + Expression SFX`:
/// exactly one cue plays per expression change. Reactions win over idle
/// poses (a laugh mid-dance is a laugh, not a dance), mission beats win over
/// plain reactions (a celebration laugh layers the short success cue under
/// the long mission cue rather than playing both the laugh and the success
/// cue), and heart visibility wins over everything while it shows.
///
/// Adding a new expression later is `expression + animation + SFX asset`:
/// extend this resolver, add the asset to the catalog, done — no widget
/// changes needed.
AvatarExpressionCue? avatarCueFor({
  required AvatarMood mood,
  required AvatarReaction reaction,
  required AvatarIdleAction idle,
  required bool heartVisible,
}) {
  final mission = AvatarExpressionSoundCatalog.missionCueFor(mood);
  if (mission != null) return mission;
  if (heartVisible) return AvatarExpressionSoundCatalog.love;
  if (reaction != AvatarReaction.none) {
    return AvatarExpressionSoundCatalog.cueFor(reaction);
  }
  return AvatarExpressionSoundCatalog.idleCueFor(idle);
}

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
