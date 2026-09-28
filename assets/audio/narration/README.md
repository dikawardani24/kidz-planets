# Neural narration audio

Place pre-generated neural TTS files in this directory using the naming convention
implemented by `NarrationAudioCatalog`.

## Planet narration

- `planets/sun.mp3`
- `planets/mercury.mp3`
- `planets/venus.mp3`
- `planets/earth.mp3`
- `planets/mars.mp3`
- `planets/jupiter.mp3`
- `planets/saturn.mp3`
- `planets/uranus.mp3`
- `planets/neptune.mp3`

## Hotspot narration

Use the slug of the hotspot title:

- `hotspots/nuclear_fusion.mp3`
- `hotspots/solar_wind.mp3`
- `hotspots/speedy_orbit.mp3`
- `hotspots/cratered_face.mp3`
- `hotspots/runaway_heat.mp3`
- `hotspots/backward_spin.mp3`
- `hotspots/liquid_oceans.mp3`
- `hotspots/protective_shield.mp3`
- `hotspots/olympus_mons.mp3`
- `hotspots/polar_ice_caps.mp3`
- `hotspots/great_red_spot.mp3`
- `hotspots/79_moons.mp3`
- `hotspots/icy_rings.mp3`
- `hotspots/light_as_cork.mp3`
- `hotspots/sideways_roll.mp3`
- `hotspots/methane_sky.mp3`
- `hotspots/supersonic_winds.mp3`
- `hotspots/white_cirrus_clouds.mp3`

The app first attempts the bundled neural recording. If the file is not present
or cannot be loaded, it falls back to the existing device TTS service.
