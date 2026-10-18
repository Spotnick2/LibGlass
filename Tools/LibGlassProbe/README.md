# LibGlassProbe

LibGlass's developer probe: a [ForeverProbe](../../../ForeverProbe/docs/GUIDE.md) module, `/fp lg`.
It replaced `Tools/GlassComparison` (`/lgprobe`) in #50.

- Its lines go to the ForeverProbe console (`/fp`) and to `LibGlassProbeDB.log`, never to chat.
- It is never packaged: the library has no TOC, and players never see it.
- It embeds **this checkout** of LibGlass, but a newer copy in another installed addon would win
  LibStub. `/fp lg report`, and the r7 procedure's first step, log which MINOR is running.

## Deploy

From the repo root:

```powershell
pwsh Tools\LibGlassProbe\deploy.ps1          # -AddOnsPath for another install
```

This deploys ForeverProbe (`..\ForeverProbe`, or `$env:FOREVERPROBE`), then this checkout into
`AddOns\LibGlassProbe\Libs\LibGlass-1.0`, then the module. Then `/reload` in game: that loads a
brand-new addon folder too (ForeverProbe guide, section 7). If `AddOns\GlassComparison` is still
there, delete it: it's the old `/lgprobe`.

## The r7 check (#50): `/fp steps lg r7`

A guided procedure: one step at a time in a small panel, each outcome saved. It is what tagging r7
waits on: on Forever a gradient texture ignores `SetAlpha` (#47), so r7 dims the wash and the edge
glow through their gradients and adds `SetWash`.

The board shows each surface with a disabled copy on its right, for classic (`New()`) and clean
(`preset = "clean"`), large and small, over a black backdrop. The steps:
1. Which LibGlass runs (checked: r7 or later).
2. Wash 0.6, then 0, then the default 0.18: is the disabled haze fainter, and does 0 hide it?
3. The edge at 0.45, then a strong custom glow: are the disabled line and glow dimmer?
4. Enable the copies (they should match), then disable them again with a wash set while disabled.
5. The scenery instead of the black backdrop.
6. A strip of four gradients, for the question #47 left open:
   - **A**: a colour texture, `SetAlpha(0.2)` **before** its gradient;
   - **B**: the same with a file texture;
   - **C**: the reference, no `SetAlpha`;
   - **D**: `SetAlpha(0.2)` **after** the gradient (#47 says it's ignored).

   Each `GetAlpha()` is logged, and the owner answers whether A, B and D are as bright as C.

Every run step logs the peak each wash and glow was painted with. After the owner's `/reload`, the
results are read from `WTF\Account\<account>\SavedVariables\`:
- `LibGlassProbe.lua`: the log, `STEP` lines included;
- `ForeverProbe.lua`: `steps.records["LibGlassProbe/r7"]`, every step's outcome and notes.

What was measured goes in `docs/GLASS-MATERIAL.md` (the r7 history row) and in the r7 GitHub
Release. Client facts that apply beyond LibGlass go in the porting guide, §3.

## The track comparison (r6, #41): `/fp lg show`

Probe 4: three clean columns that differ only in the empty-track colour.

| View | Empty-track colour alpha |
|---|---|
| A: Current track | 0.75 (the classic default) |
| B: Reduced track | 0.20 |
| C: Neutral track | 0 (the clean preset's) |

Each column is `New({ preset = "clean", bodyAlpha = ... })` plus `SetTrackAlpha`. Its findings
(2026-10-13) are in `docs/GLASS-MATERIAL.md` §4.

- `/fp lg show all` shows the columns side by side, and `/fp lg rotate` swaps their positions.
- `/fp lg show a|b|c` shows one variant, and `/fp lg next` cycles through them at the same position.
- `/fp lg value 0..100` sets the fake health (it starts at 3).
- `/fp lg smoke 0..1` sets every body's opacity (0.24 by default).
- `/fp lg report` logs the settings, and `/fp lg hide` closes every board.

## Bar fill opacity (#53): `/fp steps lg fill`, `/fp steps lg preview`

The library sets a bar's fill opacity (`STYLE.fillAlpha`, `SetFillAlpha`) with `SetAlpha`, then
paints the fill's horizontal gradient. The r7 run measured that a gradient texture ignores
`SetAlpha`.
- **`fill`:** four bars over black and white stripes, so a see-through fill shows them. Three are
  coloured, at fill 0.2, 0.6 and 1.0; the fourth is 0.2 with no colour yet. The steps colour the
  fourth, move `SetFillAlpha`, pass a colour alpha of 0.3 (into the gradient), and start the
  client's `SetTimerDuration`. Every look is a step screenshot.
- **`preview`:** unit-frame samples, classic and clean, today's opaque fill beside fill 0.6 (passed
  as the colour's alpha, which is what the fix would paint), at 100%, 30% and 5% health. Also
  `/fp lg preview [0..100]`.

What the fill run measured (2026-10-15) is in `docs/GLASS-MATERIAL.md` §6.

## Pearl (#64): `/fp steps lg repaint`, `/fp steps lg pearl`

`Pearl.lua`, on the helpers `LibGlassProbe.lua` shares through the addon namespace.

**`repaint`: the live player bar looked whiter than the probe's sample A.**
- **The hypothesis, not yet measured:** the client's `SetStatusBarColor` drops the fill's gradient, which
  holds its opacity since r8. `OnBarColor` skips an unchanged colour, so the gradient is never painted back.
- **The board:** six bars, each with **its own instance** of baseline A (`New({ preset = "clean" })`), over
  black and white stripes.
  - Each has GlassUnitFrames' quiet track (`trackClip` 0.25) and the same starting colour.
  - Separate instances matter because a setter repaints every bar of its instance, so one bar's repair
    would mend the others.
- **20 rendered frames, a different treatment per bar:**
  1. colour once;
  2. the same colour every frame;
  3. alternating colours, then the original restored;
  4. as 2, then repaired with its instance's `SetFillAlpha`;
  5. values only (eased `SetBar`);
  6. `SetBar`, then the same colour, as GlassUnitFrames' painters do.

  It runs in white, then hunter green.
- **Logged per bar:** the fill's identity against the one built, `GetTexture` (an ID), `GetVertexColor` and
  `trackColor`, each through `Probe.Show`.
  `GetAlpha` proves nothing on a gradient (#53): **the screenshots are the evidence.**
- **The live comparison:** a sample bar under GlassUnitFrames' player bar, read only (getters, and the
  sample anchors to it).
  - Its STYLE is copied from that instance, with the quiet track.
  - It is bound to the player's health and recoloured on every event, as the live bar is.
  - It has its own repair, and the same health-loss and heal overlays.

**`pearl`: refining A.**
- **Two columns:** baseline A, run #186's column A (clean + clear, frozen here), and candidate P, A plus
  lighting deltas.
- **The samples:** a unit frame, four raid cells (priest, hunter, warlock, pet), a cast bar and a small bar.
- **The comparison:** the header's A / P buttons (or `/fp lg pearl next`) show one column at a time at the
  same position.
- **The rounds,** one layer each, kept or reverted on the owner's answer:
  1. wash 0.18 → 0.10;
  2. gloss 0.25 → 0.15;
  3. frost 0.10 → 0.06;
  4. optional: rim 0.7 → 0.6.
- **Unchanged:** the fill keeps `bar_fill`, and the class colours stay the client's (no flat fill, no grey
  priest).
- **The final steps:** 30% and 0%, the columns rotated, then the bars bound to your own health and mana.
- **The record:** every step logs P's full lighting, so the chosen numbers are read from
  `LibGlassProbe.lua` in SavedVariables.

**`r11`: the check r11 is tagged on.**
- The library's `New({ preset = "pearl" })` beside P as chosen in run #192. A check fails the step if
  their lighting differs.
- Then 5% health and live bars.
- Then the repaint program and the live GlassUnitFrames sample again, on r11's `OnBarColor`.

**What the runs found (2026-10-18, 70450):**
- `repaint` (run #190) confirmed that `SetStatusBarColor` replaces the fill's gradient. See
  `docs/GLASS-MATERIAL.md` §6.
- `pearl` (run #192) kept every round. See §4.

Commands:
- `/fp lg repaint [white|hunter] | run | repair | stripes on|off | live | fix | overlays on|off | report`
- `/fp lg pearl | a | p | all | next | rotate | value 0..100 | set wash|gloss|frost|shade|rim 0..1|off |
  reset | live on|off | report`

## Commands

`/fp lg` lists them all. The r7 board also has manual controls: `r7` (built fresh), `wash 0..1`,
`disabled on|off`, `edge 0..1`, `backdrop on|off`. `fill` and `preview` rebuild the #53 boards.
`clear` empties the saved log.

## Tests

`tests/test_probe.lua` loads the host from its checkout (`$env:FOREVERPROBE`, else
`..\ForeverProbe`) and the probe through its TOC. It runs every command and walks each
procedure end to end. Step screenshots are driven like the client's: OnUpdate ticks, then
`SCREENSHOT_SUCCEEDED`. It also checks that every widget method the probe calls is in the API dump.

Probe tests run **locally only** (ForeverProbe guide, section 8). The host is private and lives
on the owner's disk, so a missing checkout is an error here. CI sets `FOREVERPROBE_OPTIONAL=1`, and
there the test prints `SKIPPED`. Run `tests\run.ps1` before any PR that touches the probe.
