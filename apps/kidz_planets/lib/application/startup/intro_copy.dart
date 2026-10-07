/// The intro screen's constants: milestone badges, rotating facts, task ids.
///
/// Widget-facing copy lives in the app's ARB table (`intro*` keys) and is
/// resolved through `AppLocalizations`, so this file holds only what is not
/// language: the emoji, the fact rotation, and the ids the wiring table and
/// the tests agree on.
abstract final class IntroCopy {
  /// Emoji each milestone card shows; the prototype draws Earth, Moon and
  /// Saturn as emoji badges rather than miniatures of the 3D bodies.
  static const Map<IntroMilestone, String> milestoneEmoji = {
    IntroMilestone.earth: '🌍',
    IntroMilestone.moon: '🌕',
    IntroMilestone.saturn: '🪐',
  };

  /// Rotating cards under the progress bar, in the prototype's order and
  /// wording (`spaceFacts`): one fact every few seconds keeps a small child
  /// reading instead of watching the bar.
  static const List<String> spaceFacts = [
    'Jupiter is the biggest planet in our Solar System! 🪐',
    'Mars is called the Red Planet because of rusty iron soil! 🔴',
    'The Sun is actually a giant glowing star! ☀️',
    'Earth has one natural moon orbiting around it! 🌕',
    'Saturn has beautiful ice and rock rings! 🪐',
    'Neptune has the strongest winds in the solar system! 🔵',
  ];
}

/// A collectible on the intro screen's orbit ring.
///
/// The milestone is progress-driven, not task-driven: Earth pops in when the
/// first band of work completes, the Moon at roughly half, Saturn at roughly
/// two thirds — the reveal points from `prototype/intro.html` (25 / 48 / 68).
enum IntroMilestone { earth, moon, saturn }

/// Stable ids for the tasks the composition root registers.
///
/// Plain strings rather than an enum so feature packages can name their own
/// task without importing the app, while the wiring table and the tests still
/// agree on the spelling. A typo'd id fails loudly at wiring time (the
/// coordinator rejects unknown dependencies) instead of silently dropping a
/// task from the bar.
abstract final class SolarSystemStartupTaskId {
  static const String core = 'core.session';

  /// The Sun, starfield, planets and orbits: the 3D scene `ensureBuilt` owns.
  static const String solarSystem = 'planets.scene';

  /// Moon meshes on the same scene, warmed lazily after Explorer is interactive.
  static const String moons = 'planets.moons';

  /// Companion geometry caches primed on the UI thread.
  static const String companion = 'avatar.scene';

  /// Reading the bundled mission catalogue through the app's use case.
  static const String missions = 'mission.catalog';

  /// The two ambience players the app owns, after the audio session.
  static const String sounds = 'core.sounds';
}
