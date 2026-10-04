# LibGlass-1.0: extract the liquid-glass material into one embedded library

## Context

`Glass.lua` (the liquid-glass material) is hand-copied into **8 addons**: GlassUnitFrames (the
owner/canonical copy), GlassChat, Gnomesweeper, GlassRaidFrames, GlassXp (GlassPanel),
GlassMiniMapBar, AltStable, LibGroupBuffs. Survey results (2026-10-04):

- **No copy is a behavioural fork.** Every difference is namespace/media-path plumbing or an
  older generation never updated:
  - v3 (current, with the directional edge #60): GlassUnitFrames, GlassChat, Gnomesweeper.
  - v2 (no edge; MiniMapBar also lacks `TUNABLES`): GlassRaidFrames, GlassXp, GlassMiniMapBar.
    Their `test_toc.lua` drift tests (compare to `GlassUnitFrames main:Glass.lua`) should
    already be failing.
  - v1 (no fill/rim/track setters, opaque fill, rim at alpha 1.0, older font shadow, bar bg
    0.35): AltStable (trimmed: ships 9 textures, no Bar/Sheen art, under `Media\Glass\`) and
    LibGroupBuffs (wrapped in LibStub MINOR guards).
- Every same-named `.tga` is byte-identical everywhere; `Tools/make_textures.py` is identical in
  all six copies that have it (AltStable has its own `make_glass_textures.py` → `Media/Glass`).
- So today fixes don't propagate, the docs (`GlassUnitFrames/docs/GLASS-MATERIAL.md`) describe
  only one copy, and LibGroupBuffs shows the opposite pain: a pinned-tag embedded lib where
  every release costs a MINOR bump in 6 files + fixtures + a tag + 3 consumer PRs.

**Goal:** one public, embedded LibStub library, `LibGlass-1.0` (repo `Spotnick2/LibGlass`, MIT),
pulled into each addon by `.pkgmeta` externals so players install nothing extra, with an API
shaped so that a consumer's migration is ~one line and a library fix reaches players through
whichever Glass addon updates first. Then a reference guide on embedded libraries for the
Priestly/Magely/Wildly sessions to rework LibGroupBuffs the same way.

Owner decisions so far: embedded (never a separate install), name `LibGlass-1.0`, MIT, public
repo (required: the packager clones externals anonymously).

## How consumers use the material today (the de-facto contract)

The API surface is the GlassUnitFrames copy, plus internals consumers reach into. All of it must
keep working:

- Calls: `Apply(host, "large"|"small") → g`, `Bar(parent, h)`, `Mask(host, file, margin,
  inset?, anchor?)`, `Font(parent, size, justify?)`, `Sheen(g, host, w, h)`, `SetBar`,
  `Smooth`, `Inset`, `ContentLevel`, setters `SetFillAlpha|SetRimAlpha|SetTrackAlpha|
  SetFillEnd|SetEdgeAlpha|SetEdge|SetFont`.
- Data: `MEDIA`, `SIZES`, `STYLE`, `EDGE`, `FONTS`, `fontKey`, `TUNABLES`, `TRACK_LEVEL`,
  `OVERLAY_LEVEL`.
- Region fields: `g.{size,shadow,mask,tint,grain,wash,top,dark,rim,edge}`,
  `bar.{glassMask,track,trackClip,overlay,trackColor}`. GlassChat, AltStable, LibGroupBuffs,
  Gnomesweeper retint/realpha/hide these directly (e.g. `g.tint:SetColorTexture`,
  `g.rim:SetVertexColor`, `g.top:SetFrameLevel`).
- **AltStable mutates `Glass.STYLE` before each `Apply`** (skin presets: grain/wash/tint).
- **`Glass.MEDIA` doubles as the addon's own media path** in Gnomesweeper (all its game art,
  `Skin.lua:20-60`, `Assets.lua:37`) and GlassMiniMapBar (`orb_*` textures in `Orb.lua`); GUF,
  GRF, GlassXp and LibGroupBuffs build their own textures from `MEDIA.."bar_fill"|"bar_mask"|
  "bar_edge"|"gloss"` and `SIZES.small.rim`.
- Saved tweaks: GUF saves `fill|rim|track|fade|edge|font` via `TUNABLES`; GlassChat saves
  per-region values and `SetEdge`; GlassXp saves `font`; AltStable a skin preset.
- Live setters reach frames through module-level lists (`rims`, `edges`, `bars`, `fontStrings`),
  so each copy's setters only touch that addon's frames. **A single shared copy would break
  that** (GUF's `/glass rim` would dim GlassChat) — hence instances below.

## Library design

### Packaging
- Repo `C:\Projects\LibGlass` → `github.com/Spotnick2/LibGlass` (public, MIT). No TOC (like
  LibGroupBuffs): entry point `LibGlass-1.0.xml` loading `LibStub\LibStub.lua` then
  `LibGlass.lua`, plus `Media\` with **only the 15 textures the code uses** (`bar_edge bar_fill
  bar_mask body_mask body_mask_small gloss grain rim5 rim5_small rim_dark5 rim_dark5_small
  shadow shadow_small sheen2 track_fade`). The 12 legacy probe textures (`rim`..`rim4`,
  `sheen`, `late`, …) stay with GUF's `Tools/GlassProbe` (or are dropped).
- `.pkgmeta`: `package-as: LibGlass-1.0`, `enable-nolib-creation: no`, ignore `tests docs Tools
  .github .claude AGENTS.md CLAUDE.md README.md`; LICENSE ships.
- Consumers: `.pkgmeta` `externals: Libs/LibGlass-1.0: { url: https://github.com/Spotnick2/LibGlass, tag: r<N> }  (pinned; see below)`
  and repeat the library's non-dot ignores (`Libs/LibGlass-1.0/tests`, `…/docs`, `…/Tools`,
  `…/CLAUDE.md`, `…/README.md`): **CurseForge's packager does not honour an external's own
  ignore list** (Priestly #53, measured in a published zip). TOC loads
  `Libs\LibGlass-1.0\LibGlass-1.0.xml` first; `Libs/` gitignored; dev copy lives at
  `..\LibGlass`.
- **Pinned tag, bumped lazily** (Codex review: BigWigs' `tag: latest` picks the newest tag *by
  creation date* in a shallow clone and falls back to branch HEAD, and CI wouldn't test what gets
  packaged — `release.sh` ~L1962). A consumer bumps its pin **only when it releases anyway** (one
  line in that release PR), never as a fan-out of PRs. Players still get fixes early, because the
  newest copy loaded wins at runtime.
- **The library is never packaged on its own**: BigWigs' packager exits without a TOC
  (`release.sh` ~L1345). Library CI = `luac -p` + tests only; the packaged subtree is asserted in
  the **pilot consumer's** CI (GUF), which checks out the pin.

### Versioning
- `MAJOR, MINOR = "LibGlass-1.0", N`; tag `rN` == MINOR (LibGroupBuffs convention). One runtime
  file (`LibGlass.lua`) so a MINOR bump is one line, not six.
- **Additive-only API**: never remove or change the meaning of a function, field, region field,
  default or `TUNABLES` key within `-1.0`. A breaking change means `LibGlass-2.0` (side by side).
- No consumer "needs MINOR" check: a consumer always ships its own copy, and LibStub only ever
  upgrades, so the active MINOR is ≥ what the consumer was built against.

### API: per-addon instances that keep the dot-call shape
```lua
local LibGlass = LibStub("LibGlass-1.0")
GlassUF.Glass = LibGlass:New()                        -- or New({ style = { rimAlpha = 1 } })
-- every existing call site keeps working unchanged:
local g = GlassUF.Glass.Apply(frame, "large")
GlassUF.Glass.SetRimAlpha(0.5)                        -- touches only this addon's surfaces
```
- `LibGlass:New(opts?)` returns an **instance** with its own `STYLE` (deep copy of the library
  defaults, then `opts.style` overrides), `EDGE` copy, `fontKey` (`opts.font`), `TUNABLES`
  (setters bound to the instance, `default` = the instance's STYLE after overrides), and its own
  `rims/edges/bars/fontStrings` registries. AltStable's "mutate STYLE then Apply" keeps working
  because STYLE is its own.
- Shared, read-only by contract: `SIZES`, `FONTS`, `TRACK_LEVEL`, `OVERLAY_LEVEL`, `MEDIA`.
- **Upgrade-safe dispatch (porting guide §"Sharing one library", ~L390):** `New` gives the
  instance plain closures `function(...) return lib.impl.Apply(inst, ...) end` — they look up
  `lib.impl` **at call time** and never capture `local impl`. A newer copy fills `lib.impl` in
  place, so older instances (and `TUNABLES[i].set` closures consumers hold) run the newest code.
  No cache, no invalidation. A small `__index` only for `MEDIA` → `lib.MEDIA` (the winning copy's
  folder).
- **Hooks dispatch too.** The `SetStatusBarColor` / `SetHeight` / `SetFrameLevel` hooks (GUF
  `Glass.lua:288,316,329`) become thin callbacks `function(self, ...) lib.impl.OnBarColor(inst,
  self, ...) end`, with bar state stored on the bar (`bar.glass = { inst, inner, over, clip }`),
  so an upgrade never leaves an old `tintTrack` running and never adds a second hook.
- **Upgrade migration, narrow:** `lib.instances` survives upgrades; a newer copy fills **only
  missing** STYLE/EDGE keys (`== nil`), appends new `TUNABLES` entries (existing entries and
  captured defaults untouched), and never repaints existing regions (GlassChat's direct
  overrides, `Skin.lua:86`, must survive). Public tables keep their identity (fill in place).
  Setters skip regions older code didn't build (`bar.track`, `g.edge`). **Stated limitation:** a
  builder change doesn't retrofit frames already built; nothing rebuilds geometry.
- **Completion marker:** `LibGlass.lua` sets `lib.ready = MINOR` on its last line; `New` errors
  clearly if `lib.ready ~= active MINOR` (a newer copy threw mid-load). One runtime file still
  needs it: `NewLibrary` claims the MINOR before the body runs.
- **Media names are part of the contract** (frames built earlier keep the old path): never
  rename or repurpose a texture in `-1.0`; add new files instead.
- `lib.MEDIA = "Interface\\AddOns\\" .. host .. "\\Libs\\LibGlass-1.0\\Media\\"` from the `...`
  addon name the client passes the embedded file; fallback `Interface\AddOns\LibGlass-1.0\Media\`
  when nil (tests).
- Consumers that used `Glass.MEDIA` for **their own** art (Gnomesweeper, MiniMapBar orbs) switch
  those to their own `"Interface\\AddOns\\<Addon>\\Media\\"` constant during their migration.

### Code
`LibGlass.lua` = GUF's `Glass.lua` v3 behaviour (`C:\Projects\GlassUnitFrames\Glass.lua`),
restructured into `impl` functions taking the instance first, plus `New`, the `__index`
dispatch, `Migrate`, and the LibStub guard. No look change for v3 consumers; v1/v2 consumers get
v3 behaviour with the edge off by default (v2: no visible change; v1 AltStable: rim alpha
1.0 → 0.7 unless it passes `style = { rimAlpha = 1 }`; LibGroupBuffs is out of scope).

### Tests (in the library repo)
- `tests/wow_stubs.lua` + `harness.lua` lifted from GUF (strict globals, dump-validated widget
  methods, `newproxy` secrets) trimmed to what the material uses; `run.ps1` (`luac -p` +
  `test_*.lua`, Lua 5.1 at `C:\Program Files (x86)\Lua\5.1\`).
- Port GUF's material tests (`test_edge.lua`, the fill/rim/track/fade/NaN cases in
  `test_frames.lua:336-394`) to instances.
- New: **instance isolation** (A's `SetRimAlpha` doesn't touch B's rims); **upgrade**: for r1 a
  *synthetic* newer copy (the current file with MINOR+1 and a marker in one impl function) loaded
  over r1 — old instances, `TUNABLES` setters and **bar hooks** (recolour incl. unchanged colour,
  resize, relevel *after* the upgrade) run the new impl, missing STYLE keys filled, overridden
  ones kept; an equal or older copy loading second is a no-op. From r2, freeze the released r1
  as `tests/fixtures/LibGlass-r1.lua`. `MEDIA` follows the winning host; `lib.ready` mismatch
  makes `New` fail loudly; `test_methods.lua` against the dump; manifest test that `Media\`
  holds exactly the textures the code names. Tests load through the XML order.
- CI `.github/workflows/check.yml`: luac + tests (no packager step: no TOC).

## Adversarial review (Codex, 2026-10-04) — reconciled
Accepted (verified against the porting guide ~L390 and the packager source it cited): pin tags
instead of `tag: latest`; no standalone packaging (no TOC); hooks must dispatch at call time;
drop the bound-function cache; narrow migration that never repaints; completion marker; synthetic
upgrade test for r1; pilot validated against the exact commit later tagged; CI clones the pinned
ref; documented bootstrap commit on main; Phase 4 replaces the porting guide's library section.
No Forever client-model conflicts found.

## Phases (each its own issue → branch → PR in the right repo; owner merges and launches reviews)

**Phase 0 — bootstrap the repo (run in this GlassUnitFrames session after plan approval).**
Create `C:\Projects\LibGlass` with: this plan as `docs/PLAN.md`, a `CLAUDE.md` (what it is,
the contract and additive rule above, versioning/release, testing, workflow rules copied from
GUF's CLAUDE.md: issue→PR, owner merges/launches reviews, `$wow-addon-review`, Forever facts
relevant to textures), `.gitignore`/`.gitattributes` (GUF's), `LICENSE` (MIT, Spotnick2 2026),
`README.md`, `.claude/skills/codex-consult/` copied from GUF, `git init -b main`, initial commit
(the one documented exception to "never commit to main": a new repo has no main yet);
then `gh repo create Spotnick2/LibGlass --public` and push **only after the owner confirms**
(outward-facing). Seed GitHub issues for Phases 1, 2, 4 there. Then the owner opens a session in
`C:\Projects\LibGlass`.

**Phase 1 — LibGlass r1 (LibGlass repo).** Move `make_textures.py` and the 15 textures (git
history not preserved; note the source commit), move `docs/GLASS-MATERIAL.md` (rewrite §5 "Reusing
it" for embedding + `New`), write `LibGlass.lua`, tests, CI, `.pkgmeta`, and a `Tools/deploy.ps1`
helper consumers call to copy `..\LibGlass` into `AddOns\<Addon>\Libs\LibGlass-1.0`
(preflight: XML, Lua, all 15 textures and LICENSE present; print the library's commit).
**Release order:** merge → GUF pilot validated against that exact public commit (pin by commit
or candidate tag `r1-rc`… simplest: pin the commit SHA in the GUF PR) → tag that same commit
`r1` → switch GUF's pin to `r1` → rerun GUF CI (packaged subtree check) before GUF releases.

**Phase 2 — GlassUnitFrames as the pilot consumer (GUF repo).** Replace `Glass.lua` with the
embed (TOC line + `GlassUF.Glass = LibStub("LibGlass-1.0"):New()` in `Compat.lua` or a 1-line
`Glass.lua`), add `.pkgmeta` externals + ignores (GUF has no `.pkgmeta`/CI today — add both from
GRF's template), gitignore `Libs/`, deploy copies `..\LibGlass`, tests load `..\LibGlass`
(`$env:LIBGLASS` override). CI clones the public LibGlass at the **pinned ref** read from
`.pkgmeta`, sets `LIBGLASS`, runs tests, then packager `-d` and asserts `Libs/LibGlass-1.0/`
holds exactly the library files (no tests/docs/Tools). Keep GUF's material integration tests
(`test_edge`, the setter cases in `test_frames`) as consumer tests. Move the 12 probe textures under `Tools/GlassProbe`. Update CLAUDE.md
(Glass.lua section → LibGlass). In-game check: frames look identical, `/glass rim|fill|edge`
still live, options sliders work, no errors after `/reload`.

**Phase 3 — the other consumers, one PR per repo, each in its own session** (not executed from
here; the LibGlass repo keeps a checklist issue): GlassChat, Gnomesweeper (its own `MEDIA` for
game art), GlassRaidFrames, GlassXp/GlassPanel (+ plugins reaching `GlassPanel.Glass` keep
working), GlassMiniMapBar (orbs keep own path; reads `Glass.STYLE` at build time — fine),
AltStable (drop `Media\Glass`, decide `rimAlpha = 1` to keep the look). Each deletes its
`test_toc.lua` drift comparison and the copy rule in its CLAUDE.md.

**Phase 4 — `C:\Projects\References\EMBEDDED-LIBRARIES.md`.** Addon-agnostic guide written from
what LibGlass proved; it **absorbs and replaces** the porting guide's existing "Sharing one
library across your addons" section (~L390, leave a pointer there), since other sessions edit
that file. Covers: externals + the CurseForge ignore gotcha, no-TOC libraries can't be packaged
alone (test packaging in a consumer), LibStub MAJOR/MINOR and upgrade-in-place (call-time
`lib.impl` dispatch incl. hooks, instance registries, narrow migration, tolerate old regions,
completion marker), lazy pin bumps vs `tag: latest` (why not) and the additive-API rule,
per-addon instances vs shared state,
dev layout (`..\Lib` sibling, gitignored `Libs/`, deploy copy, env override in tests), fixture-
based upgrade tests, one runtime file vs many, public repo requirement, nested externals
(LibGroupBuffs embedding LibGlass — verify the packager fetches an external's own externals
before recommending it). Plus a short section mapping it onto LibGroupBuffs for the
Priestly/Magely/Wildly sessions. Not a LibGroupBuffs rewrite.

## Verification
- Library: `pwsh tests\run.ps1` green; mutation-test the isolation, hook-dispatch and upgrade
  tests (capture `local impl` in a closure or hook → red).
- Pilot: GUF `pwsh tests\run.ps1` green against `..\LibGlass`; GUF CI dry run shows
  `Libs/LibGlass-1.0/` with exactly `LibGlass-1.0.xml`, `LibGlass.lua`, `LibStub/LibStub.lua`,
  `LICENSE`, 15 `Media/*.tga`, fetched at the pinned ref.
- In game (owner): `pwsh Tools\deploy.ps1`, `/console scriptErrors 1`, `/reload`; GUF frames
  identical to before; `/glass rim 0.4` changes GUF only (with a second migrated addon loaded,
  e.g. GlassChat, its rims unchanged); load with two consumers on different MINORs (deploy one
  with r1 fixture) → no errors, both draw.
