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
      narration: 'Whoa! This is the Sun. It is our closest star, and it is '
          'the brightest thing in our sky. Look at how big and glowing it is. '
          'Deep inside, it is busy squeezing hydrogen together, and that makes '
          'a huge amount of light and heat. That heat is what keeps Earth warm '
          'enough for us to live. Can you see the little flickers on its surface? '
          'Those are sunspots, and they come and go.',
      hotspots: [
        Hotspot(title: 'Nuclear Fusion', description: 'Every second the Sun fuses 600 million tons of hydrogen.', icon: 'zap',
            narration: 'Here is something amazing. Every single second, the Sun '
                'squashes about six hundred million tons of hydrogen together '
                'and turns it into helium. Scientists call this nuclear fusion. '
                'It is the same kind of reaction that powers stars. The Sun has '
                'been doing it for billions of years.'),
        Hotspot(title: 'Solar Wind', description: 'Charged particles race outward and paint polar auroras.', icon: 'waves',
            narration: 'The Sun does not just shine. It blows out little charged '
                'particles, all the way out past Earth. We call that the solar '
                'wind. When those particles meet our sky at the poles, they '
                'paint the shimmering lights you see in the north. They are '
                'called auroras.'),
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
      narration: 'This little planet is Mercury. It is the smallest planet in '
          'our solar system, and it is the closest one to the Sun. Can you see '
          'how rocky and gray it looks? That is because it has almost no air to '
          'cover it. It is also the fastest planet, zooming around the Sun in '
          'just eighty eight days.',
      hotspots: [
        Hotspot(title: 'Speedy Orbit', description: 'One speedy year lasts only 88 Earth days.', icon: 'wind',
            narration: 'Mercury is the speedy little planet. It races all the '
                'way around the Sun in just eighty eight Earth days. That is '
                'less than three months. Because it is so close to the Sun, it '
                'zooms faster than any other planet.'),
        Hotspot(title: 'Cratered Face', description: 'With almost no air, every crash leaves a scar.', icon: 'moon',
            narration: 'Look closely at Mercury and you will see a whole lot of '
                'craters. Those are holes where rocks and comets have crashed '
                'into the surface. On Earth, most craters get worn away by wind '
                'and rain. Mercury has no wind and no rain, so its craters stay '
                'for billions of years.'),
      ],
    ),
    Planet(
      id: 'venus', name: 'Venus', tag: 'Cloudy Golden Twin',
      fact: 'Venus hides under golden clouds that trap heat - the hottest planet of all.',
      radius: 0.9, orbitRadius: 9.4, orbitSpeed: 0.016, startAngle: 2.1,
      colorValue: 0xFFE8C47A, tiltDegrees: 177.4,
      textureAsset: 'assets/textures/venus.jpg',
      diameter: '12,104 km', temperature: '464C', dayLength: '243 Earth days',
      narration: 'Here comes Venus. It is the hottest planet in our whole '
          'solar system, even hotter than Mercury. Can you guess why? Those '
          'thick golden clouds trap the heat inside, like a blanket. Venus is '
          'almost the same size as Earth, and it spins very slowly, backwards. '
          'On Venus, the Sun rises in the west.',
      hotspots: [
        Hotspot(title: 'Runaway Heat', description: 'Its thick sky traps heat hot enough to melt lead.', icon: 'flame',
            narration: 'Venus has a runaway hot spell. Its thick atmosphere '
                'traps heat the way a closed car traps heat on a hot day. The '
                'ground gets hot enough to melt lead. It is about four hundred '
                'and sixty degrees Celsius.'),
        Hotspot(title: 'Backward Spin', description: 'Its Sun rises in the west and sets in the east.', icon: 'refresh',
            narration: 'Here is a strange one. Venus spins backwards compared to '
                'most planets. So on Venus, the Sun rises in the west and sets '
                'in the east. It also spins so slowly that one day there lasts '
                'longer than its whole year.'),
      ],
    ),
    Planet(
      id: 'earth', name: 'Earth', tag: 'Blue Marble Home',
      fact: 'Earth is our blue marble home - the only world with oceans, air, and life.',
      radius: 0.95, orbitRadius: 12.0, orbitSpeed: 0.013, startAngle: 4.0,
      colorValue: 0xFF3B82F6, tiltDegrees: 23.44,
      textureAsset: 'assets/textures/earth.jpg',
      diameter: '12,742 km', temperature: '15C', dayLength: '24 hours',
      narration: 'This one is home. This is Earth. It is the only world we '
          'know of with oceans, fresh air, and life. Look at how blue it is '
          'from space. All that blue is water. And did you know the Earth is '
          'tilted on its side a little? That tilt gives us our seasons. Thank '
          'goodness for Earth.',
      hotspots: [
        Hotspot(title: 'Liquid Oceans', description: 'Oceans cover 71% of the surface - the only known seas.', icon: 'droplet',
            narration: 'Look at all that water. Oceans cover most of our planet. '
                'We have seen oceans on other moons and planets, but only Earth '
                'has oceans with life swimming in them. Pretty amazing, right?'),
        Hotspot(title: 'Protective Shield', description: 'Magnetism and ozone guard every living thing.', icon: 'shield',
            narration: 'Earth wears an invisible shield. Deep inside, spinning '
                'liquid metal makes a magnetic field, and that field deflects '
                'dangerous particles from the Sun. A layer of gas called ozone '
                'also blocks most of the Sun\'s harmful rays. Together they keep '
                'us safe.'),
      ],
    ),
    Planet(
      id: 'mars', name: 'Mars', tag: 'Rusty Red Desert',
      fact: 'Mars is the rusty red desert with the tallest volcano and deepest canyon.',
      radius: 0.7, orbitRadius: 14.3, orbitSpeed: 0.011, startAngle: 1.2,
      colorValue: 0xFFEF4444, tiltDegrees: 25.19,
      textureAsset: 'assets/textures/mars.jpg',
      diameter: '6,779 km', temperature: '-63C', dayLength: '24.6 hours',
      narration: 'Look at Mars. It is the red planet, and it gets its color '
          'from rusty iron in the soil. It has the tallest volcano and the '
          'deepest canyon in our solar system. Mars is cold and dry, and it '
          'looks a lot like a desert. Can you see all that red?',
      hotspots: [
        Hotspot(title: 'Olympus Mons', description: 'A volcano nearly 3x the height of Everest.', icon: 'mountain',
            narration: 'This is Olympus Mons. It is a giant volcano on Mars, and '
                'it is almost three times taller than Mount Everest. It is so '
                'big that you could stand at the base and not even see the top. '
                'It may have a crater at the summit, like a very wide hat.'),
        Hotspot(title: 'Polar Ice Caps', description: 'Frozen water and dry ice glitter at both poles.', icon: 'snow',
            narration: 'Mars has shiny ice caps at both ends, just like Earth. '
                'But most of that ice is frozen carbon dioxide, which we call '
                'dry ice. Earth\'s caps are made mostly of frozen water. Mars\'s '
                'caps grow and shrink as the seasons change.'),
      ],
    ),
    Planet(
      id: 'jupiter', name: 'Jupiter', tag: 'Giant Striped Storm',
      fact: 'Jupiter is the giant of giants - its Great Red Spot storm is wider than Earth.',
      radius: 2.0, orbitRadius: 18.0, orbitSpeed: 0.008, startAngle: 5.3,
      colorValue: 0xFFD9A066, tiltDegrees: 3.13,
      textureAsset: 'assets/textures/jupiter.jpg',
      diameter: '139,820 km', temperature: '-110C', dayLength: '10 hours',
      narration: 'Wow! This is Jupiter. It is huge. Jupiter is the biggest '
          'planet in our solar system. It is so wide that more than a thousand '
          'Earths could fit across it. Look at those stripes. They are bands of '
          'cloud, and some of them spin faster than any other place we know of. '
          'Jupiter has at least ninety five moons.',
      hotspots: [
        Hotspot(title: 'Great Red Spot', description: 'A mega-storm wider than Earth, swirling 300+ years.', icon: 'tornado',
            narration: 'This is the Great Red Spot. It is a giant storm, and it '
                'is bigger than the whole Earth. It has been spinning for '
                'hundreds of years. Scientists watched it shrink for a long '
                'time, and now some think it will eventually disappear.'),
        Hotspot(title: '79+ Moons', description: 'Ganymede, its largest moon, beats planet Mercury!', icon: 'moons',
            narration: 'Did you know Jupiter has a whole family of moons? It '
                'has at least ninety five of them. The biggest is called Ganymede, and '
                'it is so large that it is bigger than the planet Mercury. A few of '
                'Jupiter\'s moons even have oceans under their ice.'),
      ],
    ),
    Planet(
      id: 'saturn', name: 'Saturn', tag: 'Ringed Jewel',
      fact: 'Saturn wears a dazzling crown of icy rings made of glittering snowballs.',
      radius: 1.7, orbitRadius: 21.5, orbitSpeed: 0.006, startAngle: 3.1,
      colorValue: 0xFFE3C98B, tiltDegrees: 26.73,
      textureAsset: 'assets/textures/saturn.jpg',
      diameter: '116,460 km', temperature: '-140C', dayLength: '10.7 hours',
      narration: 'Look at Saturn! It is wearing the most amazing rings in the '
          'whole solar system. Those rings are made of billions of pieces of '
          'ice and rock, and they stretch far out into space. Saturn itself is '
          'a giant made mostly of gas. And here is a fun fact. Saturn is so '
          'light for its size that it would float in a big enough ocean.',
      hotspots: [
        Hotspot(title: 'Icy Rings', description: 'Rings span 280,000 km yet are only meters thin.', icon: 'ring',
            narration: 'Let us look closer at Saturn\'s rings. They stretch an '
                'incredible distance around the planet, but they are '
                'surprisingly thin, only about as thick as a tall building. Each '
                'ring is billions of separate chunks of ice and rock, from tiny '
                'grains to pieces as big as a house.'),
        Hotspot(title: 'Light as Cork', description: 'Saturn would float in a giant enough ocean!', icon: 'beach',
            narration: 'This one always surprises people. Saturn is made mostly '
                'of gas, so it is very light for how big it is. If you could '
                'find an ocean big enough, Saturn would float right on top of '
                'it. It has no solid surface to land on.'),
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
      narration: 'Here is Uranus. It is an ice giant, and it looks like it is '
          'lying down. Uranus is tipped almost all the way over on its side, so '
          'it rolls along its orbit like a beach ball. Its color is a soft, '
          'frosty blue, and it is one of the coldest places in our solar '
          'system.',
      hotspots: [
        Hotspot(title: 'Sideways Roll', description: 'Each pole faces the Sun for 21 years at a time.', icon: 'rotate',
            narration: 'Uranus is the sideways planet. Its axis is tipped about '
                'ninety eight degrees, so it rolls around the Sun instead of '
                'spinning upright. Because it takes so long to go around, each '
                'pole spends about forty two years facing the Sun, and then '
                'forty two years in the dark.'),
        Hotspot(title: 'Methane Sky', description: 'Methane swallows red light, leaving frosty cyan.', icon: 'gem',
            narration: 'Uranus looks blue because of a gas called methane. That '
                'gas soaks up red light and lets the blue light through, so the '
                'planet glows a soft cyan color. Methane is also what makes the '
                'fog on Titan, a moon of Saturn, look orange.'),
      ],
    ),
    Planet(
      id: 'neptune', name: 'Neptune', tag: 'Deep Blue Storm World',
      fact: 'Neptune is deep azure with the fastest supersonic winds ever.',
      radius: 1.2, orbitRadius: 27.0, orbitSpeed: 0.0038, startAngle: 2.8,
      colorValue: 0xFF2563EB, tiltDegrees: 28.32,
      textureAsset: 'assets/textures/neptune.jpg',
      diameter: '49,244 km', temperature: '-200C', dayLength: '16 hours',
      narration: 'And last is Neptune. It is the farthest planet, and one of '
          'the coldest. It looks deep blue, like a very deep swimming pool. '
          'Neptune has the fastest winds in our entire solar system. They blow '
          'faster than the speed of sound, more than two thousand kilometers an '
          'hour. That is one wild place.',
      hotspots: [
        Hotspot(title: 'Supersonic Winds', description: 'Winds scream past at 2,100 km/h - fastest anywhere.', icon: 'gust',
            narration: 'The winds on Neptune are the fastest we have ever '
                'measured anywhere in the solar system. They race along at more '
                'than two thousand kilometers an hour. That is faster than the '
                'speed of sound. Even with all that sunlight, Neptune barely '
                'feels any warmth.'),
        Hotspot(title: 'White Cirrus Clouds', description: 'Bright methane ice streaks race above blue haze.', icon: 'cloud',
            narration: 'Look up at Neptune and you would see bright white clouds '
                'streaking across a deep blue sky. Those white clouds are made '
                'of frozen methane. The blue haze is deeper down. Neptune has the '
                'wildest weather of any planet we know.'),
      ],
    ),
    ...moons,
  ];

  static const List<Planet> moons = [
    Planet(id:'moon',name:'Moon',tag:'Earth\'s Natural Satellite',fact:'Earth\'s Moon helps stabilize our planet and records Solar System history.',radius:.26,orbitRadius:1.65,orbitSpeed:.20,startAngle:.3,colorValue:0xFFC9D0D8,tiltDegrees:6.68,textureAsset:'assets/textures/moon_lroc_2k.jpg',diameter:'3,475 km',temperature:'-20C',dayLength:'27.3 Earth days',parentPlanetId:'earth',isMoon:true,narration:'Meet our Moon! It is Earth\'s only natural satellite. Its gravity helps create ocean tides, and its surface keeps a record of impacts from long ago.',hotspots:[]),
    Planet(id:'phobos',name:'Phobos',tag:'Mars\'s Inner Moon',fact:'Phobos is a tiny, lumpy moon that orbits Mars incredibly close to its surface.',radius:.13,orbitRadius:1.35,orbitSpeed:.34,startAngle:1.1,colorValue:0xFF746B62,tiltDegrees:1.1,textureAsset:'assets/textures/moons/phobos.jpg',diameter:'22 km',temperature:'-40C',dayLength:'7.65 hours',parentPlanetId:'mars',isMoon:true,narration:'This is Phobos, one of Mars\'s two tiny moons. It is lumpy and dark, and it orbits so close to Mars that it races around the planet in less than eight hours.',hotspots:[]),
    Planet(id:'deimos',name:'Deimos',tag:'Mars\'s Outer Moon',fact:'Deimos is a tiny, smooth-looking moon that slowly circles Mars.',radius:.10,orbitRadius:1.85,orbitSpeed:.22,startAngle:4.2,colorValue:0xFF8A8176,tiltDegrees:0,textureAsset:'assets/textures/moons/deimos.jpg',diameter:'12 km',temperature:'-40C',dayLength:'30.3 hours',parentPlanetId:'mars',isMoon:true,narration:'Deimos is the smaller and farther of Mars\'s two moons. It looks like a tiny potato-shaped world drifting around the red planet.',hotspots:[]),
    Planet(id:'io',name:'Io',tag:'Volcanic Moon',fact:'Io is the most volcanically active world in the Solar System.',radius:.30,orbitRadius:2.25,orbitSpeed:.26,startAngle:.6,colorValue:0xFFE7C85B,tiltDegrees:0,textureAsset:'assets/textures/moons/io.jpg',diameter:'3,643 km',temperature:'-143C',dayLength:'1.77 Earth days',parentPlanetId:'jupiter',isMoon:true,narration:'Wow! This is Io, the most volcanically active world in the Solar System. Volcanoes on Io can blast fountains of lava high above its surface.',hotspots:[]),
    Planet(id:'europa',name:'Europa',tag:'Icy Ocean World',fact:'Europa has strong evidence of a salty ocean beneath its icy crust.',radius:.27,orbitRadius:2.75,orbitSpeed:.20,startAngle:2.2,colorValue:0xFFD9C8A4,tiltDegrees:0,textureAsset:'assets/textures/moons/europa.jpg',diameter:'3,122 km',temperature:'-160C',dayLength:'3.55 Earth days',parentPlanetId:'jupiter',isMoon:true,narration:'Europa looks like a cracked ball of ice, but something amazing may hide underneath. Scientists have strong evidence for a salty ocean beneath its frozen crust.',hotspots:[]),
    Planet(id:'ganymede',name:'Ganymede',tag:'The Giant Moon',fact:'Ganymede is the largest moon in the Solar System, even bigger than Mercury.',radius:.42,orbitRadius:3.35,orbitSpeed:.14,startAngle:4.1,colorValue:0xFF9B9387,tiltDegrees:0,textureAsset:'assets/textures/moons/ganymede.jpg',diameter:'5,268 km',temperature:'-160C',dayLength:'7.15 Earth days',parentPlanetId:'jupiter',isMoon:true,narration:'This is Ganymede, the biggest moon in the Solar System. It is even larger than the planet Mercury, and it has its own magnetic field.',hotspots:[]),
    Planet(id:'callisto',name:'Callisto',tag:'Ancient Cratered Moon',fact:'Callisto is one of the most heavily cratered worlds in the Solar System.',radius:.39,orbitRadius:4.05,orbitSpeed:.10,startAngle:5.4,colorValue:0xFF77746E,tiltDegrees:0,textureAsset:'assets/textures/moons/callisto.jpg',diameter:'4,821 km',temperature:'-139C',dayLength:'16.69 Earth days',parentPlanetId:'jupiter',isMoon:true,narration:'Callisto is covered with craters from billions of years of impacts. Deep beneath its icy surface, scientists think there may even be a salty ocean.',hotspots:[]),
    Planet(id:'titan',name:'Titan',tag:'Moon with a Thick Sky',fact:'Titan is the only moon known to have a substantial atmosphere and surface lakes and seas.',radius:.41,orbitRadius:2.95,orbitSpeed:.12,startAngle:.8,colorValue:0xFFD39A4A,tiltDegrees:0,textureAsset:'assets/textures/moons/titan.jpg',diameter:'5,150 km',temperature:'-179C',dayLength:'15.95 Earth days',parentPlanetId:'saturn',isMoon:true,narration:'Titan is a very special moon. It has a thick atmosphere, clouds, rain, rivers, lakes, and seas. But instead of water, its surface liquids are mostly methane and ethane.',hotspots:[]),
    Planet(id:'enceladus',name:'Enceladus',tag:'Icy Geyser Moon',fact:'Enceladus shoots icy plumes into space from an ocean beneath its frozen shell.',radius:.15,orbitRadius:2.45,orbitSpeed:.23,startAngle:2.8,colorValue:0xFFEAF4F7,tiltDegrees:0,textureAsset:'assets/textures/moons/enceladus.jpg',diameter:'504 km',temperature:'-201C',dayLength:'1.37 Earth days',parentPlanetId:'saturn',isMoon:true,narration:'Look at tiny Enceladus! It is an icy moon with a hidden ocean. Geysers near its south pole spray water and ice particles into space.',hotspots:[]),
    Planet(id:'mimas',name:'Mimas',tag:'The Giant Crater Moon',fact:'Mimas has a huge impact crater that makes it look a little like the Death Star.',radius:.12,orbitRadius:2.05,orbitSpeed:.27,startAngle:4.4,colorValue:0xFFB8B6AF,tiltDegrees:0,textureAsset:'assets/textures/moons/mimas.jpg',diameter:'396 km',temperature:'-200C',dayLength:'.94 Earth days',parentPlanetId:'saturn',isMoon:true,narration:'This is Mimas. See that enormous crater? It is so big that it makes Mimas look a little like a famous space station from a movie.',hotspots:[]),
    Planet(id:'tethys',name:'Tethys',tag:'Bright Icy Moon',fact:'Tethys is an icy Saturnian moon with a huge canyon system and a giant crater.',radius:.18,orbitRadius:2.30,orbitSpeed:.25,startAngle:5.1,colorValue:0xFFD9DEE1,tiltDegrees:0,textureAsset:'assets/textures/moons/tethys.jpg',diameter:'1,062 km',temperature:'-187C',dayLength:'1.89 Earth days',parentPlanetId:'saturn',isMoon:true,narration:'Tethys is a bright icy moon of Saturn. It has a giant crater and a huge canyon system that stretches across much of its surface.',hotspots:[]),
    Planet(id:'iapetus',name:'Iapetus',tag:'Two-Tone Moon',fact:'Iapetus has a strange two-tone surface, with one side much darker than the other.',radius:.18,orbitRadius:3.65,orbitSpeed:.09,startAngle:3.5,colorValue:0xFF8F8A82,tiltDegrees:0,textureAsset:'assets/textures/moons/iapetus.jpg',diameter:'1,469 km',temperature:'-143C',dayLength:'79.3 Earth days',parentPlanetId:'saturn',isMoon:true,narration:'Iapetus is one of Saturn\'s strangest moons. One side is much darker than the other, giving the moon a dramatic two-tone look.',hotspots:[]),
    Planet(id:'miranda',name:'Miranda',tag:'Patchwork Moon',fact:'Miranda has a wildly broken-looking surface with huge cliffs, grooves, and strange terrain.',radius:.14,orbitRadius:1.95,orbitSpeed:.19,startAngle:1.7,colorValue:0xFF9AA4A5,tiltDegrees:0,textureAsset:'assets/textures/moons/miranda.jpg',diameter:'472 km',temperature:'-187C',dayLength:'1.41 Earth days',parentPlanetId:'uranus',isMoon:true,narration:'Miranda may be the strangest-looking moon in the Solar System. Its surface looks like a giant patchwork of cliffs, grooves, and broken terrain.',hotspots:[]),
    Planet(id:'ariel',name:'Ariel',tag:'Bright Uranian Moon',fact:'Ariel is one of Uranus\'s major moons, marked by bright icy plains and deep valleys.',radius:.18,orbitRadius:2.25,orbitSpeed:.15,startAngle:3.2,colorValue:0xFFBFC5C4,tiltDegrees:0,textureAsset:'assets/textures/moons/ariel.jpg',diameter:'1,158 km',temperature:'-213C',dayLength:'2.52 Earth days',parentPlanetId:'uranus',isMoon:true,narration:'Ariel is one of Uranus\'s five major moons. Its icy surface is crossed by long valleys and bright regions.',hotspots:[]),
    Planet(id:'umbriel',name:'Umbriel',tag:'Dark Uranian Moon',fact:'Umbriel is the darkest of Uranus\'s five major moons.',radius:.18,orbitRadius:2.55,orbitSpeed:.13,startAngle:4.7,colorValue:0xFF5E6265,tiltDegrees:0,textureAsset:'assets/textures/moons/umbriel.jpg',diameter:'1,169 km',temperature:'-213C',dayLength:'4.14 Earth days',parentPlanetId:'uranus',isMoon:true,narration:'Umbriel is a dark, icy moon of Uranus. Compared with its brighter neighbors, it reflects very little sunlight.',hotspots:[]),
    Planet(id:'titania',name:'Titania',tag:'Largest Uranian Moon',fact:'Titania is the largest moon of Uranus, with giant valleys and fault lines.',radius:.22,orbitRadius:2.95,orbitSpeed:.11,startAngle:.4,colorValue:0xFFA7AFB1,tiltDegrees:0,textureAsset:'assets/textures/moons/titania.jpg',diameter:'1,578 km',temperature:'-203C',dayLength:'8.71 Earth days',parentPlanetId:'uranus',isMoon:true,narration:'Titania is the largest moon of Uranus. Its icy surface is cut by huge valleys and long fault lines.',hotspots:[]),
    Planet(id:'oberon',name:'Oberon',tag:'Cratered Uranian Moon',fact:'Oberon is the outermost and second-largest of Uranus\'s five major moons.',radius:.21,orbitRadius:3.35,orbitSpeed:.09,startAngle:2.1,colorValue:0xFF858B8C,tiltDegrees:0,textureAsset:'assets/textures/moons/oberon.jpg',diameter:'1,523 km',temperature:'-203C',dayLength:'13.46 Earth days',parentPlanetId:'uranus',isMoon:true,narration:'Oberon is a cold, cratered moon far out from Uranus. Bright material around some of its craters makes the old surface easier to spot.',hotspots:[]),
    Planet(id:'triton',name:'Triton',tag:'Neptune\'s Backward Moon',fact:'Triton orbits Neptune backwards and may be a captured Kuiper Belt object.',radius:.31,orbitRadius:2.35,orbitSpeed:-.12,startAngle:5.0,colorValue:0xFFD0C7C2,tiltDegrees:0,textureAsset:'assets/textures/moons/triton.jpg',diameter:'2,707 km',temperature:'-235C',dayLength:'5.88 Earth days',parentPlanetId:'neptune',isMoon:true,narration:'Triton is Neptune\'s largest moon, and it does something unusual. It orbits Neptune backwards compared with the planet\'s rotation. It may have been captured from the distant Kuiper Belt.',hotspots:[]),
  ];
}
