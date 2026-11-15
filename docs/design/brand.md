# Cornerstone Beacon

Selected direction: **C — Beacon**, 15 November 2026. The tapered cross also reads as a guiding light. Its diamond-shaped centre is transparent, with a slightly wider opening than the initial concept so it survives at small sizes.

The app uses `_BeaconPainter` in `lib/ui/widgets/home/shell_widgets.dart`, coloured with the active theme's primary gold. Keep its path geometry aligned with `web/beacon.svg`, the scalable browser mark. The SVG chooses the same deep gold (`#806016`) or bright gold (`#F0C653`) for the browser's light or dark colour scheme. No white fill or background belongs inside the standalone symbol.

`web/beacon-icon.svg` is the source for the installable icons: bright gold on graphite (`#161915`), with padding that keeps the whole mark inside the maskable safe area. Export it to the registered 192px and 512px PNGs, the 180px Apple touch icon, and the 32px fallback favicon. PNG exports were rendered with Resvg. These are generated brand assets, not additional application dependencies.

The existing wordmark and theme palette remain unchanged. The other marks under `logo-options/` are exploration references, not runtime logo choices.
