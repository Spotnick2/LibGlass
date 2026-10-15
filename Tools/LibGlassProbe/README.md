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
- `/fp lg report` logs the settings, and `/fp lg hide` closes both boards.

## Commands

`/fp lg` lists them all. The r7 board also has manual controls: `r7` (built fresh), `wash 0..1`,
`disabled on|off`, `edge 0..1`, `backdrop on|off`. `clear` empties the saved log.

## Tests

`tests/test_probe.lua` loads the host from its checkout (`$env:FOREVERPROBE`, else
`..\ForeverProbe`) and the probe through its TOC. It then runs every command and walks the r7
procedure end to end, and checks that every widget method the probe calls is in the API dump.
Without a host checkout it skips. CI fetches the host only when the `FOREVERPROBE_TOKEN` secret
is set, since the host's repo is private. `forever-probe.pin` names the host tag to test against.
