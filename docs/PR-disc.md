# LibGlass r2: `Glass.Disc`, the glass material on a circle

Branch `feature/disc` (local only; the owner opens the issue and PR). Requested by PortalRoulette's
arcane wheel (its approved, adversarially reviewed plan).

## What

- **`Glass.Disc(host, "disc"|"disc_small") → g`** (new instance function, `MINOR = 2`). Its own
  builder, not `Apply` with a flag. Returns the same fields as `Apply`
  (`size, shadow, mask, tint, grain, wash, top, dark, rim`) with **`g.edge = nil`**.
  - Every layer is unsliced: `SetAllPoints`, or (shadow) a symmetric outset of
    `SIZES[size].shadowOutset` (0.125) × the host's size, so the texture's disc lines up with the
    host at any size.
  - The host must be **square and sized before the call**: `Disc` errors when width ≠ height or
    either is 0. Resize a disc later with `SetScale` (the outset is computed at build time).
  - The rim registers in the instance's rim list: `SetRimAlpha` and `TUNABLES` reach discs, and
    only the instance's own.
  - Draw layers, levels and `STYLE` reads are the same as `Apply`'s.
  - `Apply` refuses a disc size, and `Disc` refuses `"large"`/`"small"`.
- **`Glass.Mask(host, file, nil, ...)`**: a nil margin now means unsliced. This is additive, since
  a nil margin used to fail in `SetTextureSliceMargins`. So `Sheen(g, host, w, h)` works on a disc
  unchanged, and content on a child frame gets its own mask:
  `Glass.Mask(child, "disc_mask", nil, inset, host)`.
- **`SIZES.disc`, `SIZES.disc_small`** (filled in place): `shape = "disc"`, `mask`, `rim`, `dark`,
  `shadow`, `shadowOutset`, `inset` (the bevel at the texture's own size: 6 / 3).
- **8 new textures** (nothing renamed). `Tools/make_textures.py` gains `circle_sdf`, `disc_rim`
  and `disc_shadow`, and the rim lighting is factored into `glass_lighting(d, glints, k, light)`,
  shared by rects and discs:
  - 256px: `disc_mask`, `disc_rim`, `disc_rim_dark`, `disc_shadow`.
  - 64px: the same four with `_small`.
  - Light comes from the top, with glints at 10:30 and 1:30.
  - The 15 r1 textures regenerate **byte-identical**.
- **Upgrade hygiene:** `lib.FUNCTIONS` is now filled in place, with new names appended. r1
  replaced it wholesale, against the public-table identity rule. `"Disc"` is appended, so r1
  instances gain `Disc` on upgrade.

## Tests

`pwsh tests/run.ps1`: `luac -p` ok (2 library + 10 test files), all six files green. Counts by file:

| Test file | Checks |
|---|---|
| isolation | 45 |
| material | 93 |
| media | 206 |
| methods | 153 |
| parity | 4 |
| upgrade | 119 |

What the new tests cover:

- **Frozen r1 fixture:** `tests/fixtures/LibGlass-r1.lua`, from `git show r1:LibGlass.lua`.
  `harness.fixtureCopy` loads it the way the XML would.
- **`test_upgrade`, r1 then r2:**
  - Public tables keep their identity, `FUNCTIONS` included (`Disc` appended once), and
    `SIZES.disc*` are added.
  - No call is made on any existing widget, and overrides and live values are kept.
  - r1 instances gain `Disc`, a held r1 `TUNABLES` setter reaches a new disc, and r1's bar hook
    runs r2's body once.
- **`test_upgrade`, r2 then r1:** r1 loading second is a no-op (`FUNCTIONS`, `SIZES`, impl, MEDIA
  and marker are all kept). The synthetic MINOR+1 test now also asserts `FUNCTIONS` identity.
- **`test_methods`:**
  - Discs at 320, 64 and 40 px: every field present, `g.edge` nil, the right textures, nothing
    sliced, layers masked, a symmetric shadow outset, and the rim registered and reached by
    `SetRimAlpha`.
  - Refusals: a non-square host, an unsized host, a rect size passed to `Disc`, and a disc size
    passed to `Apply`. A nil-margin `Mask` is unsliced.
  - Every new widget method is checked against the API dump (`GetWidth`/`GetHeight`).
- **`test_isolation`:** a disc's rim follows only its own instance's `SetRimAlpha`.
- **`test_media`:** 23 textures, with `Tools/deploy.ps1`'s list matching.
- **`test_parity`:** compares only v3's `large`/`small` sets. The disc sets are new, and the rects
  draw identically.
- **Mutations** (each turns a test red):
  - replacing `FUNCTIONS`;
  - dropping `Disc` from it;
  - not registering the disc rim;
  - registering it in every instance;
  - slicing the nil-margin mask;
  - dropping the square check;
  - a fixed shadow pad;
  - the wrong small mask;
  - repainting rims in migration;
  - letting `Apply` take a disc size.
- **Pilot consumer:** GlassUnitFrames' suite against this checkout (`$env:LIBGLASS`) passes, all
  19 files green.

## Before tagging r2 (owner)

- **In game:** discs at **320, 64 and 40 px** in one screenshot, over bright and dark scenery,
  with `/console scriptErrors 1` and no errors after `/reload`. Check that the rim's top light
  and its 10:30 and 1:30 glints read as on the rects, and that the 40px `disc_small` shows a
  clean circle.
- Then follow the release checklist in `CLAUDE.md`: merge, validate the pilot against that
  commit, tag `r2`, and freeze `tests/fixtures/LibGlass-r2.lua` for r3.

Docs: `docs/GLASS-MATERIAL.md` §3 (disc textures), §4 (disc layer stack), §5, §6 (circles are
never sliced) and §7. `README.md` now has an API table, and `CLAUDE.md` the contract and texture
list.
