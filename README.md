# LibGlass-1.0

A "liquid glass" UI material for World of Warcraft: Forever (Interface 16001) addons: a
translucent tint, a 9-sliced specular rim, masked rounded bars, gloss and an animated sheen,
faked with layered textures (real backdrop blur isn't available to addons).

Embedded with LibStub; players don't install it separately.

> **Status:** r11 released: `New({ preset = "pearl" })`, the Glass suite's theme (clean with a softer
> upper light and a quieter outline), and bar fills that stay see-through when a painter recolours
> them on every event.

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
Glass.SetWash(b, 0.08)                               -- r7: its wash (g.wash:SetAlpha does nothing)
local pill, p = Glass.Pill(button)                   -- r5: a small glass button behind its symbol
Glass.SetSurfaceRim(b, 0.9, 0.75, 0.3, 0.8)          -- r9: its rim's colour and own alpha
Glass.SetSurfaceAlpha(g, "dark", 0.55)               -- r9: one region's alpha, safe while disabled
local rf  = Glass.Reflect(g, frame, { header = 70 }) -- r9: the reflective shell's lit layers
```

## API

### Clean material (revision 6, opt-in)

```lua
local Glass = LibStub("LibGlass-1.0"):New({
    preset = "clean",
    bodyAlpha = 0.24, -- clear; try 0.50–0.80 for smoked reading surfaces
})
local g = Glass.Apply(frame, "large") -- resolves to thin; small resolves to thin_small
local inset = Glass.Inset("large")   -- 4, matching the resolved rim
```

Clean selects no grain, gloss 0.25, bottom shading 0.15, neutral empty tracks,
shadow strength 0.30 and thin rectangular rims. Discs keep their existing rim
geometry. Pill still hides its shadow. No textures are added or replaced.

`bodyAlpha` is independent of the preset and works with the original material too.
It accepts a plain number in 0..1 and is stored separately as `STYLE.bodyAlpha`.
Each new body uses that opacity with the current tint RGB, even if a consumer
replaces `STYLE.tint` between builds. Set `STYLE.bodyAlpha = nil` to follow the
tint table's alpha again. Precedence is library defaults, preset, `opts.style`,
then the explicit `bodyAlpha` option. Existing surfaces are not repainted.
Omitting both new options retains the original appearance.

Override individual choices through `style`, e.g. `{ trackTop = 0.2, gloss = 0.45,
shadowAlpha = 0.5, thinRim = false }`. The new STYLE fields default to `shadowAlpha = 1`
and `thinRim = false`. They affect subsequently built surfaces. Existing live
setters such as `SetTrackAlpha` and `SetSurfaceTint` remain available; changing
STYLE does not repaint existing surfaces. For one surface's tint/opacity:

```lua
Glass.SetSurfaceTint(g, 0.13, 0.16, 0.22, 0.8)
Glass.SetSurfaceTint(g) -- restore its built tint and opacity
```

### Pearl (revision 11, opt-in)

```lua
local Glass = LibStub("LibGlass-1.0"):New({ preset = "pearl" })
```

Pearl is the Glass suite's theme: clean, with a softer upper light and a quieter outline. The
changes from clean:
- body wash 0.18 → 0.10;
- bar gloss 0.25 → 0.15;
- bar frost 0.10 → 0.06;
- outline (`rimAlpha`) 0.7 → 0.6.

Clean's inner shade (0.15), the rounded `bar_fill` texture and the fill opacity stay, so bars keep
their depth, and the colours are still the caller's (priest white stays white). The body is clear
(0.24). `style` and `bodyAlpha` override it as for any preset.

`preset = "classic"` is the original material, exactly what `New()` builds. The instance records the
preset it was asked for as `inst.preset` ("classic" without one). An instance made by an older copy
has no `inst.preset`: an upgrade never guesses or applies a preset.

Revisions 6 to 10 accept only `"clean"`, so check the active MINOR before asking for `"pearl"` or
`"classic"`.

### Functions

`LibStub("LibGlass-1.0"):New(opts?)` returns an instance (`opts.style`: `STYLE` overrides,
`opts.font`: a `FONTS` key; revision 6 adds `opts.preset = "clean"` and independent
`opts.bodyAlpha`; revision 11 adds the presets `"pearl"` and `"classic"`). Its functions are dot-called:

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
| `SetFillAlpha`, `SetRimAlpha`, `SetTrackAlpha`, `SetFillEnd`, `SetEdgeAlpha`, `SetEdge(g, top, glow, bottom, glowh?)`, `SetFont(key)` | r1 | live setters, this instance's surfaces only (`SetRimAlpha` reaches discs). From r8, `SetFillAlpha` is drawn: through the fill's gradient (until r7 every coloured fill drew opaque, #53) |
| `SetSurfaceTint(g, r, g, b, a)`, `SetSurfaceEnabled(g, enabled)` | r3 | one surface: its own tint (`a` optional; `(g)` = back to its built colour), its disabled look (its regions' alphas scaled by `STYLE.disabledAlpha`, given back on enable; from r7 the wash and edge glow are dimmed through their gradients) |
| `SetWash(g, top)` | r7 | one surface's wash: the peak of its top-down white gradient, 0..1, 0 hides it. **The way to change a wash**: a gradient texture ignores `SetAlpha` on Forever, and `SetSurfaceEnabled` repaints the wash from this value |
| `Pill(button, opts?) → pill, g`, `RelevelPill(pill)` | r5 | the small glass button behind a symbol: the material on a child frame one level under the button, its rims down with it (under the symbol), no grain or shadow, the button's highlight softened to 0.4 (`opts`: `size` a rect size, default `"small"`; `side` px, a centred square; `highlight` alpha or `false`); `RelevelPill` after the button's level changes |
| `SetSurfaceRim(g, r, g, b, a?)`, `SetSurfaceAlpha(g, part, a)` | r9 | one surface's rim colour (vertex RGB) and alpha, and the alpha of its `"rim"`, `"dark"`, `"grain"` or `"shadow"`. A rim given an alpha is the surface's own: `SetRimAlpha` leaves it alone until `SetSurfaceRim(g)`, the built look. On a disabled surface the alpha is the one enabling gives back |
| `Reflect(g, host, opts?) → rf` | r9 | the reflective shell (GlassRaidFrames, PetStable): a lit rim and a 1 px top highlight on `g.top`, and with `opts.header` (px) a header reflection over the wash, all static gradients, kept as `g.reflect = { rim, top, header }`. Once per rect surface; `SetSurfaceEnabled` dims them. The tint, wash, edge, alphas and backing stay the caller's (`docs/GLASS-MATERIAL.md` §4) |

Data: `STYLE`, `EDGE`, `fontKey`, `TUNABLES` (per instance); `MEDIA`, `SIZES` (`large`, `small`,
from r2 `disc`, `disc_small`, from r3 `thin`, `thin_small`), `FONTS`, `TRACK_LEVEL`, `OVERLAY_LEVEL` (shared, read-only).
Region fields: `g.{size,shadow,mask,tint,grain,wash,top,dark,rim,edge}` (from r9, `g.reflect`),
`bar.{glassMask,track,trackClip,overlay,trackColor}`.

`g.size` records the resolved texture-set key: on a clean instance, requesting
`large`/`small` yields `thin`/`thin_small`. This is the geometry Sheen uses.

The full write-up of the material is `docs/GLASS-MATERIAL.md`.

## License

MIT.
