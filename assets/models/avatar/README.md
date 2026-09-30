# Avatar Rocket GLB

The companion now prefers a bundled GLB rocket at:

`assets/models/avatar/rocket.glb`

The loader is deliberately fault-tolerant: if the GLB is unavailable or cannot be parsed, the existing procedural rocket remains visible.

## Intended asset

Use a low-poly, kid-friendly rocket with a clear rocket silhouette, fins, nose cone and engine.

The previously evaluated **7 Rockets** pack by Marina_sunny_girl is CC0 1.0 and includes GLB files, but its itch.io download requires going through the site's download flow.

A directly accessible CC0 source is Kenney's **Space Kit**, which includes modular rocket GLB parts. The public mirror used for asset inspection is:

https://github.com/0xrise/cc0-assets-nft

Source license: CC0 1.0.

## Integration requirements

- Keep the final file named `rocket.glb`.
- Keep it low-poly and mobile-friendly.
- Keep the rocket centered around its local origin.
- Keep +Y as the rocket's longitudinal axis.
- The existing `avatarRoot` controls rotation, squash and reaction transforms.
- The existing exhaust and Flutter face overlay remain separate from the imported model.

Do not remove the procedural fallback until the bundled GLB has been verified on Android and iOS.
