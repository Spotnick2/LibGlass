# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

LibGlass-1.0 is the **"liquid glass" material for World of Warcraft: Forever 1.60.1** (Interface
`16001`) addons, written in **Lua 5.1**, as an **embedded LibStub library**. Single owner
(Spotnick). It replaces the hand-copied `Glass.lua` that lived in eight addons: GlassUnitFrames
(the original), GlassChat, Gnomesweeper, GlassRaidFrames, GlassPanel, GlassMiniMapBar,
AltStable and LibGroupBuffs.

Players never install it: each addon embeds a copy under `Libs\LibGlass-1.0\` through `.pkgmeta`
externals, and LibStub runs the newest copy loaded.

**Status (2026-10-09): `r5` merged, not yet tagged** (`efa8b40`: `Glass.Pill`, #31; the tag
waits for its in-game check). `r4` is `330ef47` (the disabled look's default 0.4 → 0.25, #24).
`r3` is `87b3c04` (per-surface tint, disabled look and thin rims, for Time Is Money; checked in
game 2026-10-07). `r2` is `ed57e53` (`Glass.Disc`, for PortalRoulette, which pins `tag: r2`);
`r1` is `562da7b`. GlassUnitFrames is the pilot consumer (Phase 2 done, pinned to `tag: r1`).
Phase 3, the other Glass addons, is tracked in #3, with the per-addon guide at
`C:\Projects\References\LIBGLASS-MIGRATION.md`. Phase 4 (#4) is the embedded-libraries guide.
`docs/PLAN.md` is the approved plan (adversarially reviewed by Codex, findings reconciled in it).

Work goes through GitHub issues and PRs at `github.com/Spotnick2/LibGlass` (**public**: the
packager clones externals anonymously, so it must stay public). License: MIT.

## Layout (target, per `docs/PLAN.md`)

- **No TOC.** Entry point `LibGlass-1.0.xml`: `LibStub\LibStub.lua`, then `LibGlass.lua`.
- **`LibGlass.lua`**: the one runtime file. `MAJOR, MINOR = "LibGlass-1.0", N`.
- **`Media\`**: exactly the 27 textures the code names (r1: `bar_edge bar_fill bar_mask body_mask
  body_mask_small gloss grain rim5 rim5_small rim_dark5 rim_dark5_small shadow shadow_small
  sheen2 track_fade`; r2: `disc_mask disc_rim disc_rim_dark disc_shadow` and their `_small`
  versions; r3: `rim_thin rim_dark_thin` and their `_small` versions). Generated, never hand-edited.
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
  "large"|"small"|"thin"|"thin_small") → g` (thin sizes r3), `Disc(host, "disc"|"disc_small")
  → g` (r2; square host, `g.edge` nil), `Bar(parent, height)`, `Mask(host, file, margin,
  inset?, anchor?)` (`margin` nil = unsliced, r2), `Font(parent, size, justify?)`, `Sheen(g, host, w, h)`, `SetBar(bar, max, value, snap?)`,
  `Smooth()`, `Inset(size?)`, `ContentLevel(host)`, `SetFillAlpha`, `SetRimAlpha`,
  `SetTrackAlpha`, `SetFillEnd`, `SetEdgeAlpha`, `SetEdge(g, top, glow, bottom, glowh?)`,
  `SetFont(key)`, `SetSurfaceTint(g, r, g, b, a?)` and `SetSurfaceEnabled(g, enabled)` (r3,
  per surface; disabling scales each region's own alpha and enabling gives it back, via
  `glassBase`/`glassDim` on the region; `SetRimAlpha` keeps a disabled rim dimmed),
  `Pill(button, opts?) → pill, g` and `RelevelPill(pill)` (r5: the small glass button behind a
  symbol; `opts.size`/`side`/`highlight`; the surface is kept on the pill as `pill.glassPill`).
- Instance data: `STYLE`, `EDGE`, `fontKey`, `TUNABLES` (own copies); `MEDIA`, `SIZES`, `FONTS`,
  `TRACK_LEVEL`, `OVERLAY_LEVEL` (shared, read-only).
- **Region fields consumers reach into:** `g.{size,shadow,mask,tint,grain,wash,top,dark,rim,edge}`,
  `bar.{glassMask,track,trackClip,overlay,trackColor}`. GlassChat, AltStable, Gnomesweeper and
  LibGroupBuffs retint, re-alpha or hide these directly.
- **Texture file names** in `Media\`: frames built earlier keep the old path. Add, never rename.
- AltStable mutates its instance's `STYLE` before each `Apply`. That must keep working.
- **Isolation:** an instance's setters touch only the surfaces built through that instance.

## Upgrade rules (several addons ship copies; the newest one wins, and it may not be yours)

These follow `C:\Projects\References\EMBEDDED-LIBRARIES.md` §5 (it replaced the porting guide's
"Sharing one library across your addons" section). Treat it as fact.

- **Dispatch at call time.** Instance functions, `TUNABLES[i].set` and **every hook installed on a
  frame** (`SetStatusBarColor`, `SetHeight`, `SetFrameLevel`) call `lib.impl.<name>(...)` when
  they run. Never capture `local impl = lib.impl` or a local implementation function in anything
  that outlives the load: an older copy's closure would run old code forever, and re-hooking
  would run both.
- **Reuse tables in place.** `lib.impl`, `lib.instances` and every public table keep their
  identity across upgrades (`X = X or {}`, fill in place). That includes `lib.FUNCTIONS`: from r2
  new names are appended to it (r1 replaced it wholesale).
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
- **After pushing tag `rN`, in order** (`EMBEDDED-LIBRARIES.md` §9):
  1. **A GitHub Release** (#30): `gh release create rN --verify-tag --title "rN: <what it adds>"
     --notes-file <notes>`. `--verify-tag` aborts if the tag isn't on the remote; without it gh
     creates the tag on `main`'s HEAD, which may not be the merge commit. The notes are written by
     hand, not `--generate-notes` (PR titles don't say what a consumer must do): what changed (API
     added, defaults changed, new `Media\` files), **what a consumer must do** (bump the pin, or
     nothing; any `.pkgmeta` ignore change), and what the in-game check showed. (r4 was tagged
     before its check, against the rule below; its release says so.)
  2. **Freeze the fixture** (see Testing), in its own PR.
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
- No CHANGELOG file for the library (LibGroupBuffs precedent): the **GitHub Releases are its
  history**, and consumers read them before bumping a pin. The consumers' changelogs carry
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
  current one; from r2: every frozen release `tests\fixtures\LibGlass-rN.lua`, listed in
  `test_upgrade.lua`'s `RELEASES`), including hooks after an upgrade and an older copy loading
  second being a no-op. The fixture of the current MINOR must equal `LibGlass.lua`, so a code change
  after a release fails until MINOR is raised. Only the Lua is compared: a `Media\`, XML or
  LibStub change after a release needs the same bump, by hand. After pushing tag `rN`, freeze
  `git show rN:LibGlass.lua` as its fixture and add it to `RELEASES`; `MEDIA` following the winning
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

- `C:\Projects\References\EMBEDDED-LIBRARIES.md`: the embedded-library guide (Phase 4), written
  from what this library and LibGroupBuffs measured. Packaging, pinning, upgrade rules and tests
  that apply beyond LibGlass go there.
- `C:\Projects\References\PORTING-TBC-TO-FOREVER.md`: measured client facts. Other sessions edit
  both files, so re-read before editing, and keep your edits to the section you mean to change.
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
the library must never do arithmetic, comparison, truth tests or string work on a value a consumer
passes in, with one exception. **Colours passed to a glass bar's `SetStatusBarColor` must be
plain**: its hook compares RGB and alpha with the last colour (`==`), defaults the alpha
(`a or 1`) and multiplies the alpha by `fillEnd` (v3 behaviour, kept for parity). Comparing or
truth-testing a secret throws (porting guide §4, measured), so a secret colour would throw there.
Supporting secret colours would mean reworking all three, not just the comparison. The tuning
and per-surface setters (`SetRimAlpha`…, `SetSurfaceTint`, `SetSurfaceEnabled`) range-check or
truth-test their arguments, so they take plain values too: secrets belong in bar values only.

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
