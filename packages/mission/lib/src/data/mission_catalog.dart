import 'package:mission/domain.dart';

/// The mission curriculum, in the order a child works through it.
///
/// Missions name their target by [Mission.targetPlanetId] rather than holding
/// a planet reference, so this content stays pure data and the mission feature
/// never has to reach into the planets package to read it.
abstract final class MissionCatalog {
  static const List<Mission> missions = [
    Mission(
      id: 1,
      title: 'Find Planet Earth',
      description: 'Start at the Sun and count outward to our blue home world.',
      targetPlanetId: 'earth',
      startPoint: 'the Sun',
      direction: 'Count outward from the Sun',
      hints: [
        'Look for a blue world with bright oceans and visible land.',
        'Count outward from the Sun: Mercury, Venus, then Earth. It is the third planet.',
        'It is the shiny blue-and-green one, and the only world where we have people.',
      ],
    ),
    Mission(
      id: 2,
      title: 'Find Mars',
      description: 'Look for the small reddish rocky planet.',
      targetPlanetId: 'mars',
      startPoint: 'the Sun',
      direction: 'Count outward',
      hints: [
        'Look for a small reddish rocky world.',
        'Count outward from the Sun and it comes right after Earth.',
        'It is the dusty red planet, with a giant canyon and the tallest volcano we know.',
      ],
    ),
    Mission(
      id: 3,
      title: 'Find Saturn',
      description: 'Find the planet surrounded by a bright ring system.',
      targetPlanetId: 'saturn',
      startPoint: 'the Sun',
      direction: 'Count outward',
      hints: [
        'Look for the planet with a spectacular ring system.',
        'Count outward from the Sun and it is the sixth planet, just past Jupiter.',
        'It is the golden planet, and those bright rings make it easy to spot from far away.',
      ],
    ),
    Mission(
      id: 4,
      title: 'Visit Jupiter',
      description: 'Find the giant planet with a famous storm.',
      targetPlanetId: 'jupiter',
      startPoint: 'the Sun',
      direction: 'Count outward',
      hints: [
        'Look for the largest planet with a giant storm.',
        'Count outward from the Sun and it is the fifth planet, just before Saturn.',
        'It is the biggest planet, and its Great Red Spot is a storm wider than Earth.',
      ],
    ),
  ];
}
