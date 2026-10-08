# LibGlass-1.0

A "liquid glass" UI material for World of Warcraft: Forever (Interface 16001) addons: a
translucent tint, a 9-sliced specular rim, masked rounded bars, gloss and an animated sheen,
faked with layered textures (real backdrop blur isn't available to addons).

Embedded with LibStub; players don't install it separately.

> **Status:** `r1` released (GlassUnitFrames' `Glass.lua` v3, unchanged look; pilot:
> GlassUnitFrames). r2 adds `Glass.Disc` (round glass); untagged until its in-game check.
> See `docs/PLAN.md`.

## Embedding

`.pkgmeta`:

```yaml
externals:
  Libs/LibGlass-1.0:
    url: https://github.com/Spotnick2/LibGlass
    tag: r1

ignore:
  # CurseForge's packager doesn't apply an external's own ignore list.
  - Libs/LibGlass-1.0/tests
  - Libs/LibGlass-1.0/docs
  - Libs/LibGlass-1.0/Tools
  - Libs/LibGlass-1.0/AGENTS.md
  - Libs/LibGlass-1.0/CLAUDE.md
  - Libs/LibGlass-1.0/README.md
```

TOC, before your own files:

```
Libs\LibGlass-1.0\LibGlass-1.0.xml
```

## Usage

```lua
local Glass = LibStub("LibGlass-1.0"):New()          -- one instance per addon
local g   = Glass.Apply(frame, "large")              -- "small" under ~40px tall
local bar = Glass.Bar(frame, 20)
bar:SetPoint("TOPLEFT", frame, "TOPLEFT", Glass.Inset("large"), -Glass.Inset("large"))
bar:SetFrameLevel(Glass.ContentLevel(frame))
local fs  = Glass.Font(g.top, 14, "LEFT")
Glass.SetRimAlpha(0.5)                                -- affects only this instance's surfaces
local d   = Glass.Disc(square, "disc")               -- r2: round glass on a square, sized host
local b   = Glass.Apply(button, "thin_small")        -- r3: the thin rim, opt-in
Glass.SetSurfaceTint(b, 0.18, 0.42, 0.22, 0.35)      -- r3: one surface's own tint
Glass.SetSurfaceEnabled(b, false)                    -- r3: its disabled look
```

## API

`LibStub("LibGlass-1.0"):New(opts?)` returns an instance (`opts.style`: `STYLE` overrides,
`opts.font`: a `FONTS` key). Its functions are dot-called:

| Function | Since | |
|---|---|---|
| `Apply(host, "large"\|"small") → g` | r1 | the material on a rectangle (9-sliced); r3 adds `"thin"`\|`"thin_small"`, the same with a thinner, subtler rim |
| `Disc(host, "disc"\|"disc_small") → g` | r2 | the material on a circle, unsliced; `host` square and sized first; `g.edge` is `nil`; `"disc_small"` under ~96px |
| `Bar(parent, height) → bar` | r1 | a glass StatusBar |
| `Mask(host, file, margin, inset?, anchor?)` | r1 | a rounded mask; `margin == nil` (r2) = unsliced |
| `Font(parent, size, justify?)` | r1 | a FontString in the instance's font |
| `Sheen(g, host, w, h) → AnimationGroup` | r1 | a sweep; works on discs too |
| `SetBar(bar, max, value, snap?)`, `Smooth()` | r1 | eased bar values (secrets welcome) |
| `Inset(size?)`, `ContentLevel(host)` | r1 | content inset (px) and frame level; for `disc`/`disc_small` the inset is in texture px (256 / 64): scale it by host size ÷ texture size |
| `SetFillAlpha`, `SetRimAlpha`, `SetTrackAlpha`, `SetFillEnd`, `SetEdgeAlpha`, `SetEdge(g, top, glow, bottom, glowh?)`, `SetFont(key)` | r1 | live setters, this instance's surfaces only (`SetRimAlpha` reaches discs) |
| `SetSurfaceTint(g, r, g, b, a)`, `SetSurfaceEnabled(g, enabled)` | r3 | one surface: its own tint (`a` optional; `(g)` = back to its built colour), its disabled look (its regions' alphas scaled by `STYLE.disabledAlpha`, given back on enable) |

Data: `STYLE`, `EDGE`, `fontKey`, `TUNABLES` (per instance); `MEDIA`, `SIZES` (`large`, `small`,
from r2 `disc`, `disc_small`, from r3 `thin`, `thin_small`), `FONTS`, `TRACK_LEVEL`, `OVERLAY_LEVEL` (shared, read-only).
Region fields: `g.{size,shadow,mask,tint,grain,wash,top,dark,rim,edge}`,
`bar.{glassMask,track,trackClip,overlay,trackColor}`.

The full write-up of the material is `docs/GLASS-MATERIAL.md`.

## License

MIT.
