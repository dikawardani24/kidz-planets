/// Which 3D body the companion wears.
///
/// The avatar system is model-agnostic: idle motion, reactions, physics and
/// sound all animate the *pose*, never a particular mesh. The type only decides
/// which GLB is loaded, how it is framed, and which rocket-only attachments
/// (exhaust plume, painted face) are shown. Adding a third avatar is a new
/// value here plus its asset row — no widget changes needed.
enum AvatarType {
  /// The bundled Kenney rocket. Always available, even offline: it is the
  /// fallback every other type degrades to when its own asset cannot load.
  rocket('rocket', 'assets/models/avatar/rocket.glb'),

  /// The bundled astronaut. Same loader and animation rig as the rocket;
  /// the exhaust plume and painted face stay off because neither belongs to
  /// a spacesuit.
  astronaut('astronaut', 'assets/models/avatar/astronot.glb');

  const AvatarType(this.id, this.assetPath);

  /// Stable persistence id. Stored in preferences, so rename with care: a
  /// rename strands every child back on the rocket.
  final String id;

  /// Bundle key of the model's GLB, resolved exactly like the rocket's.
  final String assetPath;

  /// Parses a persisted [id]. Unknown or missing ids fall back to the rocket,
  /// so a corrupt preference can never leave the child avatar-less.
  static AvatarType fromId(String? id) => AvatarType.values.firstWhere(
    (type) => type.id == id,
    orElse: () => AvatarType.rocket,
  );
}
