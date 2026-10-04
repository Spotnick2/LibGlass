# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

LibGlass-1.0 is the **"liquid glass" material for World of Warcraft: Forever 1.60.1** (Interface
`16001`) addons, written in **Lua 5.1**, as an **embedded LibStub library**. Single owner
(Spotnick). It replaces the hand-copied `Glass.lua` that lived in eight addons: GlassUnitFrames
(the original), GlassChat, Gnomesweeper, GlassRaidFrames, GlassXp (GlassPanel), GlassMiniMapBar,
AltStable and LibGroupBuffs.

Players never install it: each addon embeds a copy under `Libs\LibGlass-1.0\` through `.pkgmeta`
externals, and LibStub runs the newest copy loaded.

**Status (2026-10-04): Phase 1 (r1) implemented on its PR, not tagged.** `docs/PLAN.md` is the
approved plan (adversarially reviewed by Codex, findings reconciled in it). `r1` is tagged only
after the GlassUnitFrames pilot (Phase 2) validates the merged commit.

Work goes through GitHub issues and PRs at `github.com/Spotnick2/LibGlass` (**public**: the
packager clones externals anonymously, so it must stay public). License: MIT.

## Layout (target, per `docs/PLAN.md`)

- **No TOC.** Entry point `LibGlass-1.0.xml`: `LibStub\LibStub.lua`, then `LibGlass.lua`.
- **`LibGlass.lua`**: the one runtime file. `MAJOR, MINOR = "LibGlass-1.0", N`.
- **`Media\`**: exactly the 15 textures the code names (`bar_edge bar_fill bar_mask body_mask
  body_mask_small gloss grain rim5 rim5_small rim_dark5 rim_dark5_small shadow shadow_small
  sheen2 track_fade`). Generated, never hand-edited.
- **`Tools\make_textures.py`**: the texture generator (Pillow + numpy).
  **`Tools\deploy.ps1`**: the helper consumers call to copy this checkout into
  `AddOns\<Addon>\Libs\LibGlass-1.0` (preflight: XML, Lua, all textures, LICENSE).
- **`docs\GLASS-MATERIAL.md`**: the material write-up (moved here from GlassUnitFrames). **Any
  change to `LibGlass.lua`, `Tools/make_textures.py` or the material parameters updates it in
  the same commit.**
- **`tests\`**: see Testing.

## The contract (read before changing anything)

Consumers depend on more than the functions. Within `LibGlass-1.0`, **the API only grows**:
never remove, rename or change the meaning of any of these. A breaking change is `LibGlass-2.0`,
side by side.

- **`LibGlass:New(opts?)`** returns a per-addon **instance**. Opts: `style` (overrides of
  `STYLE`), `font` (a `FONTS` key).
- Instance functions, dot-called (`Glass.Apply(...)`, not `Glass:Apply`): `Apply(host,
  "large"|"small") → g`, `Bar(parent, height)`, `Mask(host, file, margin, inset?, anchor?)`,
  `Font(parent, size, justify?)`, `Sheen(g, host, w, h)`, `SetBar(bar, max, value, snap?)`,
  `Smooth()`, `Inset(size?)`, `ContentLevel(host)`, `SetFillAlpha`, `SetRimAlpha`,
  `SetTrackAlpha`, `SetFillEnd`, `SetEdgeAlpha`, `SetEdge(g, top, glow, bottom, glowh?)`,
  `SetFont(key)`.
- Instance data: `STYLE`, `EDGE`, `fontKey`, `TUNABLES` (own copies); `MEDIA`, `SIZES`, `FONTS`,
  `TRACK_LEVEL`, `OVERLAY_LEVEL` (shared, read-only).
- **Region fields consumers reach into:** `g.{size,shadow,mask,tint,grain,wash,top,dark,rim,edge}`,
  `bar.{glassMask,track,trackClip,overlay,trackColor}`. GlassChat, AltStable, Gnomesweeper and
  LibGroupBuffs retint, re-alpha or hide these directly.
- **Texture file names** in `Media\`: frames built earlier keep the old path. Add, never rename.
- AltStable mutates its instance's `STYLE` before each `Apply`. That must keep working.
- **Isolation:** an instance's setters touch only the surfaces built through that instance.

## Upgrade rules (several addons ship copies; the newest one wins, and it may not be yours)

These follow `C:\Projects\References\PORTING-TBC-TO-FOREVER.md`, "Sharing one library across your
addons". Treat that section as fact.

- **Dispatch at call time.** Instance functions, `TUNABLES[i].set` and **every hook installed on a
  frame** (`SetStatusBarColor`, `SetHeight`, `SetFrameLevel`) call `lib.impl.<name>(...)` when
  they run. Never capture `local impl = lib.impl` or a local implementation function in anything
  that outlives the load: an older copy's closure would run old code forever, and re-hooking
  would run both.
- **Reuse tables in place.** `lib.impl`, `lib.instances` and every public table keep their
  identity across upgrades (`X = X or {}`, fill in place).
- **Narrow migration.** A newer copy fills only *missing* `STYLE`/`EDGE` keys (`== nil`) on older
  instances and appends new `TUNABLES` entries. It never repaints existing regions and never
  rebuilds geometry (consumer overrides must survive; protected frames can't be touched in
  combat). Setters skip regions older code didn't build.
- **Stated limitation:** a builder change doesn't retrofit frames that were already built.
- **Completion marker:** `lib.ready = MINOR` on the **last line** of `LibGlass.lua`; `New` fails
  loudly when `lib.ready` isn't the active MINOR.
- `lib.MEDIA` is the winning copy's folder (`Interface\AddOns\<host>\Libs\LibGlass-1.0\Media\`,
  from the `...` addon name); instances resolve `MEDIA` through it at call time.

## Releasing

- **Raise `MINOR` for every behaviour change**, in the same PR. Tag the merge commit `r<MINOR>`
  (`git tag r2 && git push origin r2`). Never move or reuse a tag.
- **Consumers pin a tag** in `.pkgmeta` (`tag: rN`), not `tag: latest` (the packager picks the
  newest tag by creation date and falls back to branch HEAD). A consumer bumps its pin **only when
  it releases anyway**. Players still get fixes early: the newest copy loaded wins.
- **The library is never packaged on its own**: the packager stops without a TOC. What a consumer's
  zip holds under `Libs/LibGlass-1.0/` is asserted in **GlassUnitFrames' CI** (the pilot).
- Consumers must repeat this repo's non-dot ignores under `Libs/LibGlass-1.0/` in their own
  `.pkgmeta`: **CurseForge's packager does not honour an external's own ignore list** (measured in
  Priestly's published zip, Priestly #53).
- **Before tagging:** run the pilot consumer's tests against this checkout
  (`$env:LIBGLASS`, `pwsh ..\GlassUnitFrames\tests\run.ps1`), and validate in game.
- No CHANGELOG for the library (LibGroupBuffs precedent); the consumers' changelogs carry
  player-facing notes.

## Testing

Plain Lua 5.1 scripts, no dependencies, modelled on GlassUnitFrames' harness:
`tests\wow_stubs.lua` (strict-globals allowlist, `newproxy` secrets that throw, every widget
method recorded and checked against the API dump by `test_methods.lua`), `tests\harness.lua`
(loads the library **through the XML's order**), `tests\run.ps1` (`luac -p` + every
`tests\test_*.lua`).

- **Look parity:** `tests/test_parity.lua` builds the same surfaces with the frozen
  `tests/fixtures/GlassUF-v3.lua` (GUF @ `09b6f0d`) and with the library, and compares every widget
  call. A deliberate look change says so in its PR and adjusts that test (and `docs/GLASS-MATERIAL.md`).
- Must cover: instance isolation; the upgrade path (r1: a synthetic newer copy loaded over the
  current one; from r2: the frozen released `tests\fixtures\LibGlass-r1.lua`), including hooks
  after an upgrade and an older copy loading second being a no-op; `MEDIA` following the winning
  host; the `lib.ready` check; `Media\` holding exactly the textures the code names.
- **Mutation-test new tests**: break the behaviour (capture `local impl` in a hook, share a
  registry) and confirm they go red.
- The stub must model the client's absences: fail on any unstubbed global; confirm a global
  exists in the dump before stubbing it.

## Toolchain and commands

```powershell
& 'C:\Program Files (x86)\Lua\5.1\luac.exe' -p LibGlass.lua         # syntax check; silent on success
pwsh tests\run.ps1                                                   # luac -p + every tests\test_*.lua
python Tools\make_textures.py                                        # regenerate Media\*.tga
```

Use the Lua 5.1 toolchain at `C:\Program Files (x86)\Lua\5.1\`, not a newer Lua on `PATH`.

## References

- `C:\Projects\References\PORTING-TBC-TO-FOREVER.md`: measured client facts, including the library
  section above. Other sessions edit it; addon-agnostic findings go there (Phase 4 of the plan
  moves the library material into `C:\Projects\References\EMBEDDED-LIBRARIES.md`).
- `C:\Projects\References\forever-api-1.60.1.70205.md`: the API dump (widget methods included).
  Presence is not a contract.
- `C:\Projects\LibGroupBuffs`: the precedent embedded library (multi-file MINOR guards, fixtures,
  `test_versions.lua`). Consumed by Priestly, Magely, Wildly.
- `C:\Projects\GlassUnitFrames`: the original `Glass.lua` (v3, with the directional edge) and the
  pilot consumer.

Forever facts that matter here: textures are uncompressed 32-bit TGA, power-of-two; a **new
texture file loads after `/reload`**, only a brand-new addon folder needs a client restart;
`SetGradient` takes colour objects; sliced masks fail on boxes small in both directions (see
`docs/GLASS-MATERIAL.md` §6). Bars take secret values straight into `SetMinMaxValues`/`SetValue`;
the library must never do arithmetic, comparison or string work on a value a consumer passes in
(apart from the plain colour alpha in the `SetStatusBarColor` hook).

## Workflow (sibling conventions)

- Issue → branch off `main` → PR with `Closes #N` → review (owner-launched) → squash-merge (by the
  owner). Never commit to `main` (the bootstrap commit was the one exception: a new repo has no
  `main` to branch from). Commit or push only when asked. Before committing, `luac -p` must be
  clean and the tests green.
- **The owner merges and closes PRs, and launches reviews.** Claude opens the issue, branch and
  PR, runs the tests, and stops there: never `gh pr merge` or close a PR, and never start a Codex
  or Fable review on its own. When the owner posts or points to a review, reconcile it and push
  the fixes to the PR.
- Review policy: use the shared `$wow-addon-review` skill for PR reviews. Adversarial review
  (launched by the owner) runs through `/codex-consult`; always hand it this file and the porting
  guide. Verify its claims before acting; push back when it adds complexity to a single-owner
  library.
- Consumers are separate repos with their own sessions; change them only through their own PRs.

## Conventions

- **Right-size for a single maintainer.** Simplest thing that works; no speculative config.
- **Measured beats reasoned.** If a claim about the client can be checked in game, check it.
- Keep a `_test` seam table at the bottom of `LibGlass.lua` for test-only internals; don't
  promote internals to globals.
