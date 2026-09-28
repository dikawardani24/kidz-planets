# NASA-inspired moon surface textures

All 18 moons in the catalog now have a surface texture instead of a flat
color. Earth's Moon uses the real NASA LRO map
(`../moon_lroc_2k.jpg`, from the CGI Moon Kit). The other 17 are
kid-friendly stylized interpretations of NASA-reported features,
generated locally with Pillow:

```bash
/usr/bin/python3 tool/generate_moon_textures.py
/usr/bin/python3 tool/generate_moon_textures.py --only io --only europa
```

Output: `assets/textures/moons/<moon-id>.jpg` (1024x512 equirectangular).

What each texture depicts (per NASA mission imagery):

- phobos/deimos — dark, heavily cratered rubble piles (MRO/HiRISE gray-brown)
- io — yellow sulfur plains, dark volcanic dots with frost rings (Galileo)
- europa — bright ice crossed by reddish lineae cracks (Galileo/Juno)
- ganymede — dark cratered patches + light grooved bands (Galileo/Juno)
- callisto — densest cratering in the system, dark ancient ice (Galileo)
- titan — opaque orange haze bands + dark polar seas (Cassini/Huygens)
- enceladus — clean white ice + blue tiger-stripe fractures (Cassini)
- mimas — Herschel giant basin on a cratered face (Cassini)
- tethys — Odysseus basin + Ithaca Chasma canyon (Cassini)
- iapetus — two-tone: dark Cassini Regio / bright trailing side (Cassini)
- miranda — patchwork coronae ovoids + fault scarps (Voyager 2)
- ariel — bright plains + long graben valleys (Voyager 2)
- umbriel — darkest Uranian moon, muted craters (Voyager 2)
- titania/oberon — gray cratered ice, bright ray ejecta (Voyager 2)
- triton — cantaloupe terrain, pink nitrogen cap, geyser streaks (Voyager 2)

These are stylized educational textures, not photo mosaics. If real NASA
global maps become available for a moon, drop the JPG in this folder and
point the catalog entry at it.
