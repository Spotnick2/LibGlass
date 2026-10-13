# Glass comparison probe: round 4

A standalone Forever (Interface 16001) addon comparing empty-track colour at
low health. Only the amount of colour beyond the actual fill differs.

| View | Empty-track colour alpha |
|---|---|
| A: Current track | 0.75 (existing library default) |
| B: Reduced track | 0.20 |
| C: Neutral track | 0 (no coloured empty track) |

All variants use the candidate clean treatment: no grain, thin rims, shadow at
30% region alpha, bar gloss 0.25 and bottom shading 0.15. Body opacity starts at
0.24 and is adjustable equally across all variants. Each variant uses its own
instance and the existing SetTrackAlpha API. Actual fill opacity, colour,
lighting, geometry and values match. C keeps the bar background, frost, gloss
and edge; only the coloured empty-track overlay disappears.

The probe now constructs these surfaces through revision 6's
`New({ preset = "clean", bodyAlpha = ... })`, rather than manually applying the
recipe. Redeploy to validate the integrated library API; `/lgprobe report` must
show library r6 or later. Variant C is the clean preset without track overrides;
A and B explicitly override its neutral track through SetTrackAlpha.

Initial fake health is **3/100**, where the earlier probes' strong coloured
track made the bar appear much fuller. Panels and small controls intentionally
match; judge the bar's fill boundary and apparent remaining health.

No library defaults, runtime source, shipped textures or consumers change.
No real unit queries, saved settings, hover effects or continuous updates.

## Update

From the repository root:

```powershell
pwsh Tools/GlassComparison/deploy.ps1
```

Redeploy, `/reload`, then `/lgprobe`. The header should say **Glass probe 4**.
A newly installed addon folder needs a client restart. The script also accepts
`-AddOnsPath` for another installation. A newer embedded LibGlass may win
LibStub selection; enable only this addon for an exact checkout baseline.

## Compare

1. `/lgprobe all` shows three columns; `/lgprobe rotate` swaps their positions.
2. `/lgprobe a`, `b` or `c` shows one variant; `/lgprobe next` cycles them at
   the same position. Keep the camera still for the initial comparison.
3. Compare `/lgprobe value 3`, then `50`, then `100`. At full health all three
   should look the same because there is no empty track. Also try `value 0`:
   the colour in A/B is the empty track, not remaining health.
4. `/lgprobe smoke 0.50` or `0.80` changes all body opacities equally;
   `smoke 0.24` restores the clear view. Judge against detailed scenery and
   during camera movement, at the normal UI scale (especially 0.64).
5. `/lgprobe report` prints revision, scale, view, opacity, fill and track
   settings. `/lgprobe hide` or X closes it; `/reload` resets settings.

Record which variant communicates remaining health most immediately at 3% and
50%, while retaining enough definition to see the empty bar. No candidate is
promoted into the library by this experiment.
