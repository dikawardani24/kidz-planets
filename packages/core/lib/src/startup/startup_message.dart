/// The copy a loading screen shows while startup runs.
///
/// An enum rather than a string so the app's translation table can be switched
/// over exhaustively: adding a phase here makes the compiler point at the one
/// place that has to decide what a child reads while it happens. A string id
/// would instead fail silently, in the language the developer happens to speak.
enum StartupMessage {
  /// Nothing specific yet. The honest generic line, used before the first task
  /// reports and for work that cannot say more.
  preparing,

  /// Opening the solar system itself: lighting, starfield, transform root.
  solarSystem,

  /// Painting the Sun.
  sun,

  /// Painting planets, their rings and their orbits.
  planets,

  /// Painting moons. Lazy by design, so this line is seen late, not first.
  moons,

  /// Building the mission companion.
  companion,

  /// Reading the curriculum and checking it against the catalogue.
  missions,

  /// Getting the audio players ready to play.
  sounds,

  /// Everything required finished.
  ready,
}