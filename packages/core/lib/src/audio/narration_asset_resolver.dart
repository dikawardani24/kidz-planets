/// Chooses the locale-appropriate narration file for an asset id, and reports
/// whether one exists.
///
/// Narration is recorded per language into a parallel folder tree, and a
/// language is routinely only partially recorded: English ships first, and the
/// Indonesian folders start empty. Deciding "English exists, use English" is a
/// policy decision, so it lives behind this port and is implemented where the
/// asset tree is actually known, rather than being open-coded at every call
/// site where the two could disagree.
abstract interface class NarrationAssetResolver {
  /// The asset path to read [id] from in [languageCode], falling back to
  /// English when that language has no recording.
  String pathFor(String id, String languageCode);

  /// Whether any recording of [id] exists at all, so callers can stay silent
  /// rather than pointing the player at a missing file.
  bool exists(String id, String languageCode);
}
