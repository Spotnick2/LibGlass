# LibGlass-1.0

A "liquid glass" UI material for World of Warcraft: Forever (Interface 16001) addons: a
translucent tint, a 9-sliced specular rim, masked rounded bars, gloss and an animated sheen,
faked with layered textures (real backdrop blur isn't available to addons).

Embedded with LibStub; players don't install it separately.

> **Status:** r1 implemented (GlassUnitFrames' `Glass.lua` v3, unchanged look). Not tagged yet:
> `r1` waits for the GlassUnitFrames pilot. See `docs/PLAN.md`.

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
```

The full write-up of the material is `docs/GLASS-MATERIAL.md`.

## License

MIT.
