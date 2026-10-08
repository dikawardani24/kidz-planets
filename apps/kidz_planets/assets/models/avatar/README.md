# Avatar GLB Bodies

The companion wears one bundled GLB body at a time, chosen on the Avatar page:

- `assets/models/avatar/rocket.glb` — the rocket (default, always available)
- `assets/models/avatar/astronot.glb` — the astronaut

The loader is deliberately fault-tolerant: if a GLB is unavailable or cannot be parsed, the previously shown body stays visible.

To add another avatar, drop its GLB here, add an `AvatarType` value with the
bundle key, and follow the integration requirements below. Rocket-only
attachments (exhaust plume, painted face) stay off for non-rocket bodies
automatically.

## Intended asset

Use a low-poly, kid-friendly rocket with a clear rocket silhouette, fins, nose cone and engine.

The previously evaluated **7 Rockets** pack by Marina_sunny_girl is CC0 1.0 and includes GLB files, but its itch.io download requires going through the site's download flow.

A directly accessible CC0 source is Kenney's **Space Kit**, which includes modular rocket GLB parts. The public mirror used for asset inspection is:

https://github.com/0xrise/cc0-assets-nft

Source license: CC0 1.0.

## Integration requirements

- Keep the final files named `rocket.glb` / `astronot.glb` (the ids are
  persisted, so a rename strands saved choices back on the rocket).
- Keep it low-poly and mobile-friendly.
- Keep the body centered around its local origin, about one unit tall, so the
  shared companion camera frames every avatar the same way.
- Keep +Y as the body's longitudinal axis.
- The existing `avatarRoot` controls rotation, squash and reaction transforms.
- The existing exhaust and Flutter face overlay remain separate from the imported model.
- Textures must be core glTF images (PNG or JPEG). Exporters such as trimesh
  emit `EXT_texture_webp`, which the importer cannot parse, and the build hook
  then fails with `glTF requires unsupported extension(s): EXT_texture_webp`.
  Run `tool/convert_glb_webp_textures.py --in-place <file>.glb` after any export
  that produces WebP; it transcodes the images and leaves the geometry alone.

Do not remove the procedural fallback until the bundled GLB has been verified on Android and iOS.
