import '../../domain/entities/planet.dart';

/// Kid-scaled planet catalogue ported from prototype/index.html.
abstract final class PlanetCatalog {
  static const List<Planet> planets = [
    Planet(
      id: 'sun',
      name: 'Sun',
      tag: 'Our Blazing Star',
      fact: 'The Sun holds 99.8% of all solar system mass. Its core burns at 15 million C, fusing hydrogen into helium.',
      radius: 4.2, orbitRadius: 0, orbitSpeed: 0, startAngle: 0,
      colorValue: 0xFFFDB813, tiltDegrees: 0,
      textureAsset: 'assets/textures/sun.jpg',
      diameter: '1,392,700 km', temperature: '5,505C', dayLength: '27 Earth days',
      hotspots: [
        Hotspot(title: 'Nuclear Fusion', description: 'Every second the Sun fuses 600 million tons of hydrogen.', icon: 'zap'),
        Hotspot(title: 'Solar Wind', description: 'Charged particles race outward and paint polar auroras.', icon: 'waves'),
      ],
      isSun: true,
    ),
    Planet(
      id: 'mercury', name: 'Mercury', tag: 'Swift Gray Sprinter',
      fact: 'Mercury is the smallest planet, racing around the Sun in just 88 days.',
      radius: 0.55, orbitRadius: 7.2, orbitSpeed: 0.021, startAngle: 0.4,
      colorValue: 0xFF9C8E82, tiltDegrees: 0.03,
      textureAsset: 'assets/textures/mercury.jpg',
      diameter: '4,879 km', temperature: '167C', dayLength: '59 Earth days',
      hotspots: [
        Hotspot(title: 'Speedy Orbit', description: 'One speedy year lasts only 88 Earth days.', icon: 'wind'),
        Hotspot(title: 'Cratered Face', description: 'With almost no air, every crash leaves a scar.', icon: 'moon'),
      ],
    ),
    Planet(
      id: 'venus', name: 'Venus', tag: 'Cloudy Golden Twin',
      fact: 'Venus hides under golden clouds that trap heat - the hottest planet of all.',
      radius: 0.9, orbitRadius: 9.4, orbitSpeed: 0.016, startAngle: 2.1,
      colorValue: 0xFFE8C47A, tiltDegrees: 177.4,
      textureAsset: 'assets/textures/venus.jpg',
      diameter: '12,104 km', temperature: '464C', dayLength: '243 Earth days',
      hotspots: [
        Hotspot(title: 'Runaway Heat', description: 'Its thick sky traps heat hot enough to melt lead.', icon: 'flame'),
        Hotspot(title: 'Backward Spin', description: 'Its Sun rises in the west and sets in the east.', icon: 'refresh'),
      ],
    ),
    Planet(
      id: 'earth', name: 'Earth', tag: 'Blue Marble Home',
      fact: 'Earth is our blue marble home - the only world with oceans, air, and life.',
      radius: 0.95, orbitRadius: 12.0, orbitSpeed: 0.013, startAngle: 4.0,
      colorValue: 0xFF3B82F6, tiltDegrees: 23.44,
      textureAsset: 'assets/textures/earth.jpg',
      diameter: '12,742 km', temperature: '15C', dayLength: '24 hours',
      hotspots: [
        Hotspot(title: 'Liquid Oceans', description: 'Oceans cover 71% of the surface - the only known seas.', icon: 'droplet'),
        Hotspot(title: 'Protective Shield', description: 'Magnetism and ozone guard every living thing.', icon: 'shield'),
      ],
    ),
    Planet(
      id: 'mars', name: 'Mars', tag: 'Rusty Red Desert',
      fact: 'Mars is the rusty red desert with the tallest volcano and deepest canyon.',
      radius: 0.7, orbitRadius: 14.3, orbitSpeed: 0.011, startAngle: 1.2,
      colorValue: 0xFFEF4444, tiltDegrees: 25.19,
      textureAsset: 'assets/textures/mars.jpg',
      diameter: '6,779 km', temperature: '-63C', dayLength: '24.6 hours',
      hotspots: [
        Hotspot(title: 'Olympus Mons', description: 'A volcano nearly 3x the height of Everest.', icon: 'mountain'),
        Hotspot(title: 'Polar Ice Caps', description: 'Frozen water and dry ice glitter at both poles.', icon: 'snow'),
      ],
    ),
    Planet(
      id: 'jupiter', name: 'Jupiter', tag: 'Giant Striped Storm',
      fact: 'Jupiter is the giant of giants - its Great Red Spot storm is wider than Earth.',
      radius: 2.0, orbitRadius: 18.0, orbitSpeed: 0.008, startAngle: 5.3,
      colorValue: 0xFFD9A066, tiltDegrees: 3.13,
      textureAsset: 'assets/textures/jupiter.jpg',
      diameter: '139,820 km', temperature: '-110C', dayLength: '10 hours',
      hotspots: [
        Hotspot(title: 'Great Red Spot', description: 'A mega-storm wider than Earth, swirling 300+ years.', icon: 'tornado'),
        Hotspot(title: '79+ Moons', description: 'Ganymede, its largest moon, beats planet Mercury!', icon: 'moons'),
      ],
    ),
    Planet(
      id: 'saturn', name: 'Saturn', tag: 'Ringed Jewel',
      fact: 'Saturn wears a dazzling crown of icy rings made of glittering snowballs.',
      radius: 1.7, orbitRadius: 21.5, orbitSpeed: 0.006, startAngle: 3.1,
      colorValue: 0xFFE3C98B, tiltDegrees: 26.73,
      textureAsset: 'assets/textures/saturn.jpg',
      diameter: '116,460 km', temperature: '-140C', dayLength: '10.7 hours',
      hotspots: [
        Hotspot(title: 'Icy Rings', description: 'Rings span 280,000 km yet are only meters thin.', icon: 'ring'),
        Hotspot(title: 'Light as Cork', description: 'Saturn would float in a giant enough ocean!', icon: 'beach'),
      ],
      ringTextureAsset: 'assets/textures/saturn_ring.png',
      ringInnerFactor: 1.3, ringOuterFactor: 2.05,
    ),
    Planet(
      id: 'uranus', name: 'Uranus', tag: 'Sideways Ice Giant',
      fact: 'Uranus is tipped on its side, rolling around the Sun like a ball.',
      radius: 1.25, orbitRadius: 24.5, orbitSpeed: 0.0045, startAngle: 0.9,
      colorValue: 0xFF67E8F9, tiltDegrees: 97.77,
      textureAsset: 'assets/textures/uranus.jpg',
      diameter: '50,724 km', temperature: '-195C', dayLength: '17 hours',
      hotspots: [
        Hotspot(title: 'Sideways Roll', description: 'Each pole faces the Sun for 21 years at a time.', icon: 'rotate'),
        Hotspot(title: 'Methane Sky', description: 'Methane swallows red light, leaving frosty cyan.', icon: 'gem'),
      ],
    ),
    Planet(
      id: 'neptune', name: 'Neptune', tag: 'Deep Blue Storm World',
      fact: 'Neptune is deep azure with the fastest supersonic winds ever.',
      radius: 1.2, orbitRadius: 27.0, orbitSpeed: 0.0038, startAngle: 2.8,
      colorValue: 0xFF2563EB, tiltDegrees: 28.32,
      textureAsset: 'assets/textures/neptune.jpg',
      diameter: '49,244 km', temperature: '-200C', dayLength: '16 hours',
      hotspots: [
        Hotspot(title: 'Supersonic Winds', description: 'Winds scream past at 2,100 km/h - fastest anywhere.', icon: 'gust'),
        Hotspot(title: 'White Cirrus Clouds', description: 'Bright methane ice streaks race above blue haze.', icon: 'cloud'),
      ],
    ),
  ];
}
