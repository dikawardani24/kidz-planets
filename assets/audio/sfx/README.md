# Planetary sound effects

Kidz Planets uses subtle, stylized sound-design beds on the detail screen.

These are **not literal sounds traveling through space**. Sound waves cannot propagate
through the vacuum of space. NASA also creates sonifications by translating space
data into audible forms. The app uses the same educational idea: each world gets a
distinct audio identity that reinforces the visual experience.

Generate the local WAV assets with Python's standard library:

```bash
python3 tool/generate_planet_sfx.py
```

Test one body:

```bash
python3 tool/generate_planet_sfx.py --only earth
python3 tool/generate_planet_sfx.py --only sun --force
```

The generated files are:

```text
assets/audio/sfx/planets/<body-id>.wav
```

The Flutter app loops the selected body's ambience while its detail view is open.
The `Sound` control in the detail sheet replays that ambience.

The sound design is intentionally subtle:
- Earth: gentle rotational/atmospheric hum
- Sun: warm low solar rumble with shimmer
- Jupiter: deep giant-world rumble
- Saturn: soft resonant/ring-like shimmer
- Io: more turbulent volcanic texture
- Europa/Enceladus: icy, high shimmering tones
- Triton: cold, distant low ambience

Do not describe these assets as recordings of sound in the vacuum of space.
