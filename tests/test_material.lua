-- The material's behaviour on one instance, ported from GlassUnitFrames'
-- test_edge.lua and the setter cases in test_frames.lua (~336-394): the
-- optional edge, the live setters (fill, rim, track, fade, font), the colour
-- hook, the track clip, NaN and range refusals, and secret bar values.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local LibGlass = loadLibrary("GlassUnitFrames")
local Glass = LibGlass:New()
local MEDIA = "Interface\\AddOns\\GlassUnitFrames\\Libs\\LibGlass-1.0\\Media\\"
eq(Glass.MEDIA, MEDIA, "MEDIA is the embedded copy's folder")
eq(LibGlass.MEDIA, MEDIA, "and the library's")

------------------------------------------------------------------------------
-- The directional edge (#60): off by default and hidden, live-tuned for every
-- surface, and a host can set its own values, which the global tune then
-- leaves alone.
------------------------------------------------------------------------------
local host = newHost(200, 40)
local g = Glass.Apply(host, "large")
check(g.edge and g.edge.top and g.edge.glow and g.edge.bottom, "every glass surface has an edge")
check(not g.edge.top:IsShown() and not g.edge.bottom:IsShown(), "off by default: hidden, so nothing changes for anyone")
eq(Glass.STYLE.edge, 0, "the shipped edge is 0")

check(Glass.SetEdgeAlpha(0.45), "SetEdgeAlpha accepts 0.45")
check(g.edge.top:IsShown(), "SetEdgeAlpha shows it")
eq(g.edge.top._color[4], 0.45, "the top line at the value")
near(g.edge.bottom._color[4], 0.35, "the bottom line in proportion (0.35)")
near(g.edge.glow._gradient[3].a, 0.12, "the glow in proportion (0.12)")
eq(g.edge.glow._height, 4, "over a 4px glow")

local host2 = newHost(120, 24)
local g2 = Glass.Apply(host2, "small")
eq(g2.edge.top._color[4], 0.45, "a surface built later takes the current edge")
Glass.SetEdge(g2, 0.6, 0.2, 0.5, 6)
Glass.SetEdgeAlpha(0.1)
eq(g2.edge.top._color[4], 0.6, "a host's own edge isn't overridden by the global tune")
eq(g2.edge.glow._height, 6, "nor its glow depth")
eq(g.edge.top._color[4], 0.1, "while the others follow it")
check(Glass.SetEdgeAlpha(0), "0 is accepted")
check(not g.edge.top:IsShown(), "0 hides it again")
check(not Glass.SetEdgeAlpha(2), "out of range is refused")
eq(Glass.STYLE.edge, 0, "and leaves the value")

------------------------------------------------------------------------------
-- Bars and setters
------------------------------------------------------------------------------
local bar = Glass.Bar(host, 20)
local bar2 = Glass.Bar(host2, 7)
local fs = Glass.Font(g.top, 14)
eq(fs._font[1], "Fonts\\ARIALN.TTF", "Arial Narrow by default")
eq(fs._font[2], 15, "a point bigger (Arial runs small)")

check(Glass.SetFont("friz"), "font switched")
eq(Glass.fontKey, "friz", "fontKey follows")
eq(fs._font[1], "Fonts\\FRIZQT__.TTF", "font applied to existing text")
eq(fs._font[2], 14, "at its own size")
check(not Glass.SetFont("comic"), "unknown font rejected")
eq(Glass.fontKey, "friz", "and the key kept")

-- Translucent bar fill (r8, #53): on Forever a gradient texture ignores
-- SetAlpha, before or after, so a coloured fill's opacity is drawn in its
-- gradient. Its alpha is still set, for a fill with no colour (no gradient).
eq(bar:GetStatusBarTexture()._alpha, 0.6, "bar fill at the default opacity (owner-picked)")
check(Glass.SetFillAlpha(0.5), "fill accepted")
eq(bar:GetStatusBarTexture()._alpha, 0.5, "fill retuned live, on a fill with no colour yet")
eq(bar2:GetStatusBarTexture()._alpha, 0.5, "on every bar")
check(fs._alpha == nil or fs._alpha == 1, "text stays opaque")
bar:SetStatusBarColor(1, 0, 0)
near(bar:GetStatusBarTexture()._gradient[2].a, 0.5, "coloured: the fill opacity is drawn in the gradient")
eq(bar:GetStatusBarTexture():GetAlpha(), 1, "(GetAlpha reads 1 on a gradient texture, as in game)")
check(Glass.SetFillAlpha(0.8), "fill retuned again")
near(bar:GetStatusBarTexture()._gradient[2].a, 0.8, "SetFillAlpha repaints a coloured fill's gradient")
check(Glass.SetFillAlpha(0.5), "and back")
local vc = bar.track._vertex
eq(bar.track._file, MEDIA .. "track_fade", "missing health: the fading ramp")
check(vc and vc[1] == 1 and vc[2] == 0 and vc[4] == 0.75, "tinted with the bar's own colour")

-- Rim brightness: every glass surface, live.
eq(g.rim._alpha, 0.7, "rim softened by default (owner-picked)")
check(Glass.SetRimAlpha(0.5), "rim accepted")
eq(g.rim._alpha, 0.5, "rim retuned live")
eq(g2.rim._alpha, 0.5, "on every surface")
check(not Glass.SetRimAlpha(0), "out-of-range rim rejected")
eq(Glass.STYLE.rimAlpha, 0.5, "and the value kept")

check(Glass.SetTrackAlpha(0.8), "track accepted")
eq(bar.track._vertex[4], 0.8, "track retuned live")
eq(bar.track._vertex[1], 1, "track keeps the bar colour")
local fg = bar:GetStatusBarTexture()._gradient
check(fg and fg[1] == "HORIZONTAL" and math.abs(fg[2].a - 0.5) < 1e-9 and fg[3].a == fg[2].a and fg[3].r == 1,
      "fill even by default (fade off), in the bar's colour, at the fill opacity")
check(Glass.SetFillEnd(0.5), "fade accepted")
near(bar:GetStatusBarTexture()._gradient[3].a, 0.25, "fade retuned live (the fill opacity times the fade)")

-- The track only shows past the fill: its clip starts at the fill's moving
-- edge, so a full bar stays even and the ramp never sits under the fill.
local tc = bar.trackClip
eq(tc._points[1][2], bar:GetStatusBarTexture(), "track clip starts at the fill's edge")
eq(tc._points[1][3], "TOPRIGHT", "at the fill's right edge")
eq(tc._points[2][2], bar, "and ends with the bar")
check(tc._clips == true, "the track is clipped")
eq(bar.track:GetParent(), tc, "the track lives in the clip")

-- NaN fails every comparison: it must not slip through a range check.
for _, name in ipairs({ "SetFillAlpha", "SetRimAlpha", "SetTrackAlpha", "SetFillEnd", "SetEdgeAlpha" }) do
    check(not Glass[name](0 / 0), "NaN refused by " .. name)
    check(not Glass[name]("0.5"), "a string refused by " .. name)
end
eq(Glass.STYLE.fillAlpha, 0.5, "NaN fill left the value")

-- A client visual reset of the fill's alpha is undone on the next recolour.
local fillTex = bar:GetStatusBarTexture()
fillTex:SetAlpha(1)
bar:SetStatusBarColor(0, 1, 0)
eq(fillTex._alpha, 0.5, "fill opacity re-applied after a reset")
-- A caller's alpha is honoured by the fill gradient.
bar:SetStatusBarColor(0, 1, 0, 0.5)
near(fillTex._gradient[2].a, 0.25, "SetStatusBarColor's alpha kept, times the fill opacity")
-- The same colour again does no work (painters recolour on every event).
fillTex._gradient = nil
bar:SetStatusBarColor(0, 1, 0, 0.5)
eq(fillTex._gradient, nil, "unchanged colour: no re-tint")
check(not Glass.SetFillAlpha(3), "out-of-range fill rejected")

-- The shade keeps 45% of the bar, and the overlay and clip follow the level.
bar:SetHeight(30)
eq(bar.glassState.inner._height, 13, "inner shadow follows a resize (45%)")
bar:SetHeight(2)
eq(bar.glassState.inner._height, 3, "never under 3px")
bar:SetFrameLevel(20)
eq(bar.overlay:GetFrameLevel(), 20 + Glass.OVERLAY_LEVEL, "overlay follows the bar's level")
eq(bar.trackClip:GetFrameLevel(), 20 + Glass.TRACK_LEVEL, "and the track's clip")

------------------------------------------------------------------------------
-- Secret values go straight to the client, eased or not.
------------------------------------------------------------------------------
local maxV, curV = WoW.Secret("max"), WoW.Secret("cur")
Glass.SetBar(bar, maxV, curV)
check(bar._max == maxV and bar._value == curV, "secret values set without Enum interpolation")
eq(Glass.Smooth(), nil, "no easing when the enum is missing")
Enum.StatusBarInterpolation = { ExponentialEaseOut = 2 }
Glass.SetBar(bar, maxV, curV)
eq(bar._interp, 2, "eased when the client has it")
eq(bar._minMaxInterp, 2, "the max eases with the same interpolation")
Glass.SetBar(bar, maxV, curV, true)
eq(bar._interp, nil, "snap: instant")
-- The client refusing the eased call falls back to an instant one.
rawset(bar, "SetValue", function(self, v, interp)
    if interp then error("rejected") end
    self._value, self._interp = v, nil
end)
Glass.SetBar(bar, maxV, curV)
check(bar._value == curV and bar._interp == nil, "a rejected eased call falls back to instant")
Enum.StatusBarInterpolation = nil

------------------------------------------------------------------------------
-- Sheen and helpers
------------------------------------------------------------------------------
local ag = Glass.Sheen(g, host, 200, 40)
check(ag and ag._type == "AnimationGroup", "Sheen returns its AnimationGroup")
eq(Glass.Inset("large"), 6, "large inset")
eq(Glass.Inset("small"), 3, "small inset")
eq(Glass.Inset(), 6, "large by default")
eq(Glass.ContentLevel(host), host:GetFrameLevel() + 2, "content sits two levels up")

------------------------------------------------------------------------------
-- TUNABLES: one definition per knob, its setter bound to the instance.
------------------------------------------------------------------------------
local keys = {}
for _, t in ipairs(Glass.TUNABLES) do keys[#keys + 1] = t.key end
eq(table.concat(keys, ","), "fill,rim,track,fade,edge", "the five tunables, in order")
local rimT = Glass.TUNABLES[2]
eq(rimT.default, 0.7, "default is the shipped value, not the live one")
check(rimT.set(0.9), "a tunable's setter works")
eq(g.rim._alpha, 0.9, "through the instance")

------------------------------------------------------------------------------
-- As in v3, builders look Mask and Smooth up on the instance when they run,
-- so a consumer's override of either is honoured.
------------------------------------------------------------------------------
local masks = 0
local mask = Glass.Mask
Glass.Mask = function(...) masks = masks + 1; return mask(...) end
Glass.Apply(newHost(), "large")
eq(masks, 1, "Apply builds its mask through the instance's Mask")
Glass.Bar(newHost(), 10)
eq(masks, 4, "and Bar its three")
Glass.Mask = mask
Enum.StatusBarInterpolation = { ExponentialEaseOut = 2 }
local smooth = Glass.Smooth
local plain = Glass.Bar(newHost(), 10)
Glass.SetBar(plain, 10, 4)
eq(plain._interp, 2, "eased while the instance's Smooth says so")
Glass.Smooth = function() return nil end
Glass.SetBar(plain, 10, 5)
eq(plain._interp, nil, "SetBar asks the instance's Smooth (overridden: instant)")
Glass.Smooth = smooth
Enum.StatusBarInterpolation = nil

------------------------------------------------------------------------------
-- Per-surface options (r3, #18): one surface's own tint, its disabled look,
-- and the opt-in thin rim. Instance setters leave the per-surface state alone,
-- and a consumer's own alphas on the regions survive a disable and enable.
------------------------------------------------------------------------------
do
    local S = LibGlass:New()
    local hA, hB = newHost(), newHost(120, 24)
    local a, b = S.Apply(hA, "large"), S.Apply(hB, "small")
    local disc = S.Disc(newHost(64, 64), "disc_small")

    -- Tint: an accent on one surface, a near-opaque body on another.
    check(S.SetSurfaceTint(a, 0.2, 0.6, 0.3, 0.9), "SetSurfaceTint accepts a colour")
    local c = a.tint._color
    check(c[1] == 0.2 and c[2] == 0.6 and c[3] == 0.3 and c[4] == 0.9, "and paints that surface's tint")
    eq(b.tint._color[2], 0.16, "the other surface keeps the instance tint")
    check(S.SetSurfaceTint(disc, 0, 0, 0, 0.8), "a disc too")
    check(S.SetSurfaceTint(b, 0.2, 0.6, 0.3), "no alpha: accepted")
    eq(b.tint._color[4], 0.24, "keeping the surface's built translucency")
    check(not S.SetSurfaceTint(a, 0 / 0, 0, 0, 1), "NaN is refused")
    check(not S.SetSurfaceTint(a, 2, 0, 0, 1), "out of range is refused")
    check(not S.SetSurfaceTint(a, 0.2, nil, 0.3, 1), "a missing channel is refused")
    eq(a.tint._color[4], 0.9, "and a refusal leaves the tint")
    S.SetRimAlpha(0.5); S.SetFillAlpha(0.5); S.SetEdgeAlpha(0.3)
    eq(a.tint._color[4], 0.9, "instance setters leave a surface's tint alone")
    S.STYLE.tint = { 0.1, 0.1, 0.1, 0.3 }   -- AltStable changes STYLE between Applies
    check(S.SetSurfaceTint(a), "no colour: back to the built one")
    eq(a.tint._color[4], 0.24, "the colour it was built with, not the current STYLE")
    eq(a.tint._color[2], 0.16, "all of it")
    local later = S.Apply(newHost(), "large")
    S.SetSurfaceTint(later, 1, 1, 1, 1); S.SetSurfaceTint(later)
    eq(later.tint._color[4], 0.3, "a surface built after the change goes back to its own")
    rawset(later.tint, "glassColor", nil)   -- a surface an older copy built
    check(S.SetSurfaceTint(later) and later.tint._color[4] == 0.3, "without a record: the instance's STYLE.tint")
    check(S.SetSurfaceTint({}, 0, 0, 0, 1) == false, "a table that isn't a surface is refused")
    check(S.SetSurfaceTint(nil, 0, 0, 0, 1) == false, "and nil")

    -- Disabled: each region's own alpha scaled, and given back on enable.
    eq(S.STYLE.disabledAlpha, 0.25, "the shipped dim (r4; r3 shipped 0.4)")
    local D = S.STYLE.disabledAlpha
    local GLOW = 0.12 / 0.45                 -- the glow's share of the edge's top line
    a.wash:SetAlpha(0.2)                     -- a consumer's own SetAlpha: in game it doesn't reach the wash (#47)
    a.dark:SetAlpha(0.5)
    check(S.SetSurfaceEnabled(a, false), "SetSurfaceEnabled returns true")
    eq(a.tint._alpha, D, "disabled: tint dimmed")
    -- The wash and the glow are gradients, which ignore SetAlpha (#47): dimmed
    -- through the gradient, their region alpha left alone.
    near(a.wash._gradient[3].a, 0.18 * D, "wash dimmed through its gradient")
    eq(a.wash._gradient[2].a, 0, "still clear at the bottom")
    eq(a.wash._alpha, 0.2, "the wash's region alpha left alone")
    near(a.dark._alpha, 0.5 * D, "dark rim scaled")
    near(a.grain._alpha, 0.45 * D, "grain scaled with the body")
    near(a.rim._alpha, 0.5 * D, "rim scaled")
    check(a.edge.top._alpha == D and a.edge.bottom._alpha == D, "edge lines dimmed")
    near(a.edge.glow._gradient[3].a, 0.3 * GLOW * D, "the glow dimmed through its gradient")
    eq(a.edge.glow._alpha, nil, "and its region alpha left alone")
    eq(a.tint._color[4], 0.24, "the tint's colour untouched")
    eq(a.shadow._alpha, nil, "shadow untouched")
    eq(b.rim._alpha, 0.5, "the other surface stays enabled")
    S.SetSurfaceEnabled(a, false)
    near(a.wash._gradient[3].a, 0.18 * D, "disabling twice doesn't dim twice")
    near(a.edge.glow._gradient[3].a, 0.3 * GLOW * D, "the glow neither")
    S.SetRimAlpha(0.8)
    near(a.rim._alpha, 0.8 * D, "SetRimAlpha keeps a disabled rim dimmed")
    eq(b.rim._alpha, 0.8, "and sets the enabled ones")
    S.SetEdgeAlpha(0.6)
    eq(a.edge.top._alpha, D, "SetEdgeAlpha keeps a disabled edge dimmed")
    eq(a.edge.top._color[4], 0.6, "while setting its colour")
    near(a.edge.glow._gradient[3].a, 0.6 * GLOW * D, "and its glow, at the new peak")
    S.SetSurfaceTint(a, 0.2, 0.6, 0.3, 0.9)
    eq(a.tint._alpha, D, "a tint change keeps the dim")
    check(S.SetSurfaceEnabled(a, true), "enabling returns true")
    check(a.tint._alpha == 1 and a.edge.top._alpha == 1, "enabled again: undimmed")
    near(a.wash._gradient[3].a, 0.18, "the wash given back")
    near(a.edge.glow._gradient[3].a, 0.6 * GLOW, "the glow at the peak SetEdgeAlpha set meanwhile")
    eq(a.dark._alpha, 0.5, "and dark rim")
    eq(a.grain._alpha, 0.45, "and grain")
    eq(a.rim._alpha, 0.8, "the rim at the alpha SetRimAlpha set meanwhile")
    S.SetRimAlpha(0.7)
    eq(a.rim._alpha, 0.7, "re-enabled rims follow SetRimAlpha again")
    S.SetSurfaceEnabled(a, true)
    near(a.wash._gradient[3].a, 0.18, "enabling an enabled surface changes nothing")
    b.rim:SetAlpha(0.3)                      -- a consumer's own rim alpha
    S.SetSurfaceEnabled(b, false)
    near(b.rim._alpha, 0.3 * D, "a consumer's rim alpha is the base")
    S.SetSurfaceEnabled(b, true)
    eq(b.rim._alpha, 0.3, "and comes back")
    S.SetSurfaceEnabled(disc, false)
    near(disc.rim._alpha, 0.7 * D, "a disc dims too (no edge)")
    S.SetSurfaceEnabled(disc, true)
    S.SetSurfaceEnabled(disc, nil)
    near(disc.rim._alpha, 0.7 * D, "nil disables, as the client's SetEnabled")
    check(S.SetSurfaceEnabled({}, false) == false and S.SetSurfaceEnabled(nil, false) == false,
          "a table that isn't a surface, or nil, is refused")
    S.SetSurfaceEnabled(disc, true)

    -- Wash (r7, #47): one surface's wash, the way to change it (SetAlpha doesn't reach it).
    check(S.SetWash(a, 0.1), "SetWash returns true")
    near(a.wash._gradient[3].a, 0.1, "and repaints that surface's gradient")
    eq(a.wash._gradient[2].a, 0, "clear at the bottom")
    near(b.wash._gradient[3].a, 0.18, "the other surface keeps its wash")
    check(S.SetWash(a, 0) and not a.wash:IsShown(), "0 hides it")
    check(S.SetWash(a, 0.3) and a.wash:IsShown(), "and a value shows it again")
    S.SetSurfaceEnabled(a, false)
    near(a.wash._gradient[3].a, 0.3 * D, "a disable dims the wash SetWash set")
    S.SetWash(a, 0.2)
    near(a.wash._gradient[3].a, 0.2 * D, "SetWash keeps a disabled wash dimmed")
    S.SetSurfaceEnabled(a, true)
    near(a.wash._gradient[3].a, 0.2, "and enabling gives back its value")
    check(S.SetWash(disc, 0.05) and math.abs(disc.wash._gradient[3].a - 0.05) < 1e-9, "a disc too")
    for _, v in ipairs({ 0 / 0, -0.1, 1.5, "0.1", true }) do
        check(S.SetWash(a, v) == false, "SetWash refuses " .. tostring(v))
    end
    check(S.SetWash(a) == false, "and a missing value")
    near(a.wash._gradient[3].a, 0.2, "a refusal leaves the wash")
    check(S.SetWash({}, 0.1) == false and S.SetWash(nil, 0.1) == false, "a table that isn't a surface, or nil, is refused")

    -- SetEdge on a disabled surface: the host's own glow, dimmed.
    S.SetSurfaceEnabled(b, false)
    S.SetEdge(b, 0.6, 0.2, 0.5)
    near(b.edge.glow._gradient[3].a, 0.2 * D, "SetEdge keeps a disabled glow dimmed")
    S.SetSurfaceEnabled(b, true)
    near(b.edge.glow._gradient[3].a, 0.2, "and enabling gives back the host's own glow")

    -- Thin rims: a size, opt-in; everything else as large / small.
    local t, ts = S.Apply(newHost(), "thin"), S.Apply(newHost(120, 24), "thin_small")
    eq(t.rim._file, MEDIA .. "rim_thin", "thin: the thin rim")
    eq(t.dark._file, MEDIA .. "rim_dark_thin", "and its dark companion")
    eq(ts.rim._file, MEDIA .. "rim_thin_small", "thin_small: the small thin rim")
    eq(ts.dark._file, MEDIA .. "rim_dark_thin_small", "and its dark companion")
    eq(t.rim._slice[1], 16, "sliced like large")
    eq(ts.rim._slice[1], 8, "and thin_small like small")
    eq(t.mask._file, a.mask._file, "the large body mask")
    eq(a.rim._file, MEDIA .. "rim5", "large keeps rim5")
    eq(t.size, "thin", "g.size names the size")
    eq(S.Inset("thin"), 4, "thin inset")
    eq(S.Inset("thin_small"), 2, "thin_small inset")
    check(t.edge and pcall(S.Sheen, t, newHost(), 200, 40), "edge and sheen work on thin")
    S.SetRimAlpha(0.6)
    eq(t.rim._alpha, 0.6, "SetRimAlpha reaches thin rims")
end

------------------------------------------------------------------------------
-- Pill (r5, #31): the small glass button behind a symbol, as GlassChat's
-- Buttons.Style and AltStable's portrait toggle build it by hand.
------------------------------------------------------------------------------
do
    local P = LibGlass:New()
    local function button(level)
        local b = CreateFrame("Button", nil, UIParent)
        b:SetSize(24, 24)
        b:SetFrameLevel(level)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        return b
    end

    -- AltStable's recipe (AutoCapture.lua), by hand, against Pill's result.
    local hb = button(5)
    local hp = CreateFrame("Frame", nil, hb)
    hp:SetAllPoints()
    hp:SetFrameLevel(math.max(0, hb:GetFrameLevel() - 1))
    local hg = P.Apply(hp, "small")
    hg.grain:SetAlpha(0)
    hg.shadow:SetAlpha(0)
    hg.top:SetFrameLevel(hp:GetFrameLevel())
    hb:GetHighlightTexture():SetAlpha(0.4)

    local b = button(5)
    local pill, g = P.Pill(b)
    eq(pill:GetParent(), b, "the pill is the button's child")
    eq(pill:GetFrameLevel(), 4, "one level under the button")
    eq(g.top:GetFrameLevel(), 4, "its rims down with it, under the symbol")
    eq(pill._points[1][1], "ALL", "covering the button")
    eq(pill._points[1][2], b, "(the button itself)")
    eq(g.size, "small", "the small set by default")
    for _, f in ipairs({ "shadow", "tint", "grain", "wash", "dark", "rim" }) do
        eq(g[f]._alpha, hg[f]._alpha, "g." .. f .. " alpha as the hand recipe")
        eq(g[f]._file, hg[f]._file, "g." .. f .. " texture as the hand recipe")
    end
    eq(g.grain._alpha, 0, "no grain")
    eq(g.shadow._alpha, 0, "no shadow")
    eq(b:GetHighlightTexture()._alpha, 0.4, "the highlight softened, as GlassChat's")
    check(b:GetHighlightTexture()._shown, "not removed")

    -- Options: a centred square, another rect size, the highlight's alpha or none.
    local b2 = button(3)
    local p2, g2 = P.Pill(b2, { side = 20, size = "thin_small", highlight = 0.6 })
    eq(p2._width, 20, "side: a square of that side")
    check(p2._points[1][1] == "CENTER" and p2._points[1][2] == b2, "centred on the button")
    eq(g2.rim._file, P.MEDIA .. "rim_thin_small", "size: any rect set")
    eq(b2:GetHighlightTexture()._alpha, 0.6, "highlight: its alpha")
    local b3 = button(3)
    P.Pill(b3, { highlight = false })
    eq(b3:GetHighlightTexture()._alpha, nil, "highlight = false leaves it alone")
    local bare = CreateFrame("Button", nil, UIParent)
    check(pcall(P.Pill, bare), "a button with no highlight texture")
    local p0 = P.Pill(button(0))
    eq(p0:GetFrameLevel(), 0, "a button at level 0: the pill clamps at 0")
    local okDisc, errDisc = pcall(function() P.Pill(button(3), { size = "disc_small" }) end)
    check(not okDisc and tostring(errDisc):find("test_material%.lua:%d+: LibGlass.*rect size"),
          "a disc size is refused at the call site: " .. tostring(errDisc))
    check(not pcall(P.Pill, button(3), { size = "huge" }), "an unknown size is refused")
    -- Bad arguments are refused at the call site, before anything is built.
    local nRims = #P._rims
    for _, case in ipairs({
        { "a nil button", nil, nil, "button frame" },
        { "a string for opts", button(3), "thin_small", "options table" },
        { "highlight = true", button(3), { highlight = true }, "highlight" },
        { "highlight out of range", button(3), { highlight = 2 }, "highlight" },
    }) do
        local ok, err = pcall(function() P.Pill(case[2], case[3]) end)
        check(not ok and tostring(err):find("test_material%.lua:%d+: LibGlass.*" .. case[4]),
              case[1] .. " is refused at the call site: " .. tostring(err))
    end
    eq(#P._rims, nRims, "and no surface was built for any refused call")

    -- The button's level moves: RelevelPill puts the pill and its rims back under it.
    b:SetFrameLevel(9)
    check(P.RelevelPill(pill), "RelevelPill returns true")
    eq(pill:GetFrameLevel(), 8, "the pill one level under again")
    eq(g.top:GetFrameLevel(), 8, "and its rims")
    check(P.RelevelPill(newHost()) == false and P.RelevelPill(nil) == false, "a frame Pill didn't build is refused")

    -- A pill is an ordinary surface of its instance.
    P.SetRimAlpha(0.5)
    eq(g.rim._alpha, 0.5, "SetRimAlpha reaches a pill")
    P.SetSurfaceEnabled(g, false)
    eq(g.grain._alpha, 0, "disabled: the grain stays off")
    P.SetSurfaceEnabled(g, true)
    eq(g.grain._alpha, 0, "and enabled again")
    eq(g.rim._alpha, 0.5, "the rim given back")
end

------------------------------------------------------------------------------
-- SetSurfaceRim and SetSurfaceAlpha (r9, #40): one surface's rim colour and
-- alpha, and its plain regions' alphas, without fighting SetRimAlpha or the
-- disabled look's bookkeeping (what GlassRaidFrames' shell does by hand).
------------------------------------------------------------------------------
do
    local R = LibGlass:New()
    local D = R.STYLE.disabledAlpha
    local a, b = R.Apply(newHost(), "large"), R.Apply(newHost(), "large")
    local disc = R.Disc(newHost(64, 64), "disc_small")

    -- Colour only: vertex RGB, the alpha left to the instance.
    check(R.SetSurfaceRim(a, 0.2, 0.6, 1), "SetSurfaceRim returns true")
    local v = a.rim._vertex
    check(v and v[1] == 0.2 and v[2] == 0.6 and v[3] == 1 and v[4] == 1, "the rim's vertex colour, opaque")
    eq(a.rim._alpha, 0.7, "a nil alpha keeps the rim's")
    eq(b.rim._vertex, nil, "the other surface's rim untouched")
    R.SetRimAlpha(0.5)
    eq(a.rim._alpha, 0.5, "a colour alone still follows SetRimAlpha")

    -- An alpha: the surface's own, below SetRimAlpha's 0.2 floor too.
    check(R.SetSurfaceRim(a, 0.2, 0.6, 1, 0.12), "an alpha under 0.2 is taken (GlassRaidFrames' shell)")
    eq(a.rim._alpha, 0.12, "and drawn")
    R.SetRimAlpha(0.9)
    eq(a.rim._alpha, 0.12, "SetRimAlpha leaves an own rim alone")
    eq(b.rim._alpha, 0.9, "and sets the others")
    check(R.TUNABLES[2].set(0.8) and a.rim._alpha == 0.12, "the rim tunable too")
    check(R.SetSurfaceRim(a, 1, 0, 0), "a later colour without an alpha")
    eq(a.rim._alpha, 0.12, "keeps the own alpha")
    R.SetRimAlpha(0.6)
    eq(a.rim._alpha, 0.12, "and it stays the surface's own")

    -- Disabled: the alpha becomes the base enabling gives back.
    R.SetSurfaceEnabled(a, false)
    near(a.rim._alpha, 0.12 * D, "disabled: the own rim dimmed")
    R.SetSurfaceRim(a, 1, 0, 0, 0.3)
    near(a.rim._alpha, 0.3 * D, "an alpha set while disabled stays dimmed")
    R.SetSurfaceEnabled(a, true)
    eq(a.rim._alpha, 0.3, "and enabling gives back the new one")

    -- The built look again: white, the instance's alpha, following SetRimAlpha.
    check(R.SetSurfaceRim(a), "SetSurfaceRim(g) returns true")
    v = a.rim._vertex
    check(v[1] == 1 and v[2] == 1 and v[3] == 1 and v[4] == 1, "white again")
    eq(a.rim._alpha, 0.6, "at the instance's rimAlpha")
    R.SetRimAlpha(0.4)
    eq(a.rim._alpha, 0.4, "following SetRimAlpha again")
    R.SetSurfaceEnabled(a, false)
    R.SetSurfaceRim(a)
    near(a.rim._alpha, 0.4 * D, "a reset while disabled stays dimmed")
    R.SetSurfaceEnabled(a, true)
    check(R.SetSurfaceRim(a, nil, nil, nil, 0.5), "no colour with an alpha")
    v = a.rim._vertex
    check(v[1] == 1 and v[2] == 1 and v[3] == 1 and a.rim._alpha == 0.5, "is white at that alpha")
    R.SetSurfaceRim(a)

    -- Refusals change nothing.
    for _, case in ipairs({ { 0 / 0, 1, 1 }, { 1.5, 1, 1 }, { 1, -0.1, 1 }, { 1, 1, "1" }, { 1, 1, 1, 2 },
                            { 1, 1, 1, 0 / 0 }, { 1, 1, 1, true }, { 1, 1 } }) do
        check(R.SetSurfaceRim(a, case[1], case[2], case[3], case[4]) == false,
              "SetSurfaceRim refuses " .. tostring(case[1]) .. ", " .. tostring(case[2]) .. ", "
              .. tostring(case[3]) .. ", " .. tostring(case[4]))
    end
    check(a.rim._vertex[1] == 1 and a.rim._alpha == 0.4, "a refusal leaves the rim")
    check(R.SetSurfaceRim({}, 1, 1, 1) == false and R.SetSurfaceRim(nil, 1, 1, 1) == false,
          "a table that isn't a surface, or nil, is refused")
    check(R.SetSurfaceRim(disc, 0.9, 0.8, 0.2, 0.5) and disc.rim._vertex[3] == 0.2 and disc.rim._alpha == 0.5,
          "a disc's rim too")

    -- SetSurfaceAlpha: each plain region, disabled-aware.
    check(R.SetSurfaceAlpha(b, "dark", 0.55), "SetSurfaceAlpha returns true")
    eq(b.dark._alpha, 0.55, "the dark rim")
    check(R.SetSurfaceAlpha(b, "shadow", 0.18) and b.shadow._alpha == 0.18, "the shadow")
    check(R.SetSurfaceAlpha(b, "grain", 0) and b.grain._alpha == 0, "the grain, 0 included")
    check(R.SetSurfaceAlpha(b, "rim", 0.12) and b.rim._alpha == 0.12, "the rim")
    R.SetRimAlpha(0.7)
    eq(b.rim._alpha, 0.12, "a rim set here is the surface's own")
    R.SetSurfaceRim(b)
    eq(b.rim._alpha, 0.7, "until SetSurfaceRim(g)")
    -- GlassRaidFrames' dance (enable, set, disable again) is no longer needed.
    R.SetSurfaceEnabled(b, false)
    R.SetSurfaceAlpha(b, "dark", 0.35)
    R.SetSurfaceAlpha(b, "grain", 0.2)
    near(b.dark._alpha, 0.35 * D, "set while disabled: the dark rim stays dimmed")
    near(b.grain._alpha, 0.2 * D, "and the grain")
    R.SetSurfaceAlpha(b, "shadow", 0.05)
    eq(b.shadow._alpha, 0.05, "the shadow isn't dimmed by a disable, so it is drawn as given")
    R.SetSurfaceEnabled(b, true)
    eq(b.dark._alpha, 0.35, "enabling gives back the dark rim set meanwhile")
    eq(b.grain._alpha, 0.2, "and the grain")
    eq(b.shadow._alpha, 0.05, "the shadow unchanged")
    for _, part in ipairs({ "tint", "wash", "edge", "top", "mask", "size", 1 }) do
        check(R.SetSurfaceAlpha(b, part, 0.5) == false, "SetSurfaceAlpha refuses the part " .. tostring(part))
    end
    check(R.SetSurfaceAlpha(b, nil, 0.5) == false, "and no part")
    for _, x in ipairs({ 0 / 0, -0.1, 1.5, "0.5", true }) do
        check(R.SetSurfaceAlpha(b, "dark", x) == false, "SetSurfaceAlpha refuses " .. tostring(x))
    end
    check(R.SetSurfaceAlpha(b, "dark") == false, "and a missing alpha")
    eq(b.dark._alpha, 0.35, "a refusal leaves the region")
    check(R.SetSurfaceAlpha({}, "dark", 0.5) == false and R.SetSurfaceAlpha(nil, "dark", 0.5) == false,
          "a table that isn't a surface, or nil, is refused")
    check(R.SetSurfaceAlpha(disc, "dark", 0.3) and disc.dark._alpha == 0.3, "a disc's regions too")
end

------------------------------------------------------------------------------
-- Reflect (r9, #56): the reflective shell's lit layers, as GlassRaidFrames'
-- click-casting editor and PetStable build them by hand.
------------------------------------------------------------------------------
do
    local R = LibGlass:New({ preset = "clean" })
    local D = R.STYLE.disabledAlpha
    local function stops(r)
        local gr = r._gradient
        return { gr[1], gr[2].r, gr[2].g, gr[2].b, gr[2].a, gr[3].r, gr[3].g, gr[3].b, gr[3].a }
    end
    local function sameStops(r, want, dim, msg)
        local got = stops(r)
        eq(got[1], want[1], msg .. ": orientation")
        for i = 2, 9 do
            local w = want[i]
            if i == 5 or i == 9 then w = w * dim end
            near(got[i], w, msg .. ": gradient value " .. (i - 1))
        end
    end
    local RIM = { "VERTICAL", 0.55, 0.65, 0.75, 0.035, 0.84, 0.88, 0.91, 0.52 }
    local TOP = { "HORIZONTAL", 0.88, 0.91, 0.93, 0.58, 0.65, 0.73, 0.8, 0.035 }
    local HEADER = { "VERTICAL", 0.77, 0.81, 0.85, 0, 0.77, 0.81, 0.85, 0.105 }

    local host = newHost(860, 540)
    local g = R.Apply(host, "large")
    local S = R.SIZES[g.size]
    eq(g.size, "thin", "a clean instance: the thin set")
    local rf = R.Reflect(g, host, { header = 70 })
    eq(rf, g.reflect, "Reflect returns g.reflect")

    eq(rf.rim._parent, g.top, "the lit rim on g.top")
    check(rf.rim._layer == "OVERLAY" and rf.rim._sublevel == 6, "at OVERLAY 6, with the rim")
    eq(rf.rim._file, R.MEDIA .. "rim_thin", "the surface's own rim file")
    eq(rf.rim._slice[1], S.rimMargin, "sliced as the rim")
    eq(rf.rim._points[1][2], g.top, "covering the surface")
    sameStops(rf.rim, RIM, 1, "the lit rim")

    eq(rf.top._parent, g.top, "the top highlight on g.top")
    check(rf.top._layer == "OVERLAY" and rf.top._sublevel == 7, "at OVERLAY 7")
    eq(rf.top._height, 1, "1 px")
    local p1, p2 = rf.top._points[1], rf.top._points[2]
    check(p1[1] == "TOPLEFT" and p1[2] == host and p1[4] == S.maskMargin and p1[5] == -1,
          "inset by the mask's margin, 1 px below the top (left)")
    check(p2[1] == "TOPRIGHT" and p2[2] == host and p2[4] == -S.maskMargin and p2[5] == -1, "and right")
    sameStops(rf.top, TOP, 1, "the top highlight")

    eq(rf.header._parent, host, "the header reflection on the host")
    check(rf.header._layer == "BACKGROUND" and rf.header._sublevel == -3, "at BACKGROUND -3, over the wash")
    eq(rf.header._masks[1], g.mask, "masked to the body")
    eq(rf.header._height, 70, "opts.header high")
    check(rf.header._points[1][1] == "TOPLEFT" and rf.header._points[2][1] == "TOPRIGHT", "along the top")
    sameStops(rf.header, HEADER, 1, "the header reflection")
    for _, k in ipairs({ "rim", "top", "header" }) do
        eq(rf[k]._alpha, nil, k .. ": no SetAlpha (it does nothing on a gradient)")
    end

    -- No header without opts.header, or with 0; the large set on a classic instance.
    local C = LibGlass:New()
    local hc = newHost(300, 200)
    local gc = C.Apply(hc, "large")
    local rc = C.Reflect(gc, hc)
    eq(rc.header, nil, "no opts: no header layer")
    eq(rc.rim._file, C.MEDIA .. "rim5", "the classic surface's rim file")
    local h0 = newHost(300, 200)
    eq(C.Reflect(C.Apply(h0, "small"), h0, { header = 0 }).header, nil, "header 0: none")

    -- The disabled look: every layer through its gradient, then given back.
    R.SetSurfaceEnabled(g, false)
    sameStops(rf.rim, RIM, D, "disabled: the lit rim dimmed")
    sameStops(rf.top, TOP, D, "the top highlight")
    sameStops(rf.header, HEADER, D, "the header reflection")
    R.SetSurfaceEnabled(g, false)
    sameStops(rf.rim, RIM, D, "disabling twice doesn't dim twice")
    R.SetSurfaceEnabled(g, true)
    sameStops(rf.rim, RIM, 1, "enabled: the lit rim given back")
    sameStops(rf.top, TOP, 1, "the top highlight")
    sameStops(rf.header, HEADER, 1, "the header reflection")
    -- Enabling an enabled surface leaves a consumer's own gradient (GRF repaints
    -- its layers per mode between SetSurfaceEnabled(g, true) calls).
    rf.top:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.45), CreateColor(1, 1, 1, 0.035))
    R.SetSurfaceEnabled(g, true)
    near(rf.top._gradient[2].a, 0.45, "enabling an enabled surface doesn't repaint")
    rf.top:SetShown(false)
    R.SetSurfaceEnabled(g, false)
    check(not rf.top:IsShown(), "a hidden layer stays hidden")

    -- A surface disabled before the call: its layers start dimmed.
    local hd = newHost(300, 200)
    local gd = R.Apply(hd, "large")
    R.SetSurfaceEnabled(gd, false)
    local rd = R.Reflect(gd, hd, { header = 40 })
    sameStops(rd.rim, RIM, D, "Reflect on a disabled surface: dimmed at once")
    sameStops(rd.header, HEADER, D, "the header too")
    R.SetSurfaceEnabled(gd, true)
    sameStops(rd.top, TOP, 1, "and given back on enable")

    -- The instance's setters leave the layers alone.
    local before = { #rf.rim._log, #rf.top._log, #rf.header._log }
    R.SetRimAlpha(0.5); R.SetEdgeAlpha(0.4); R.SetWash(g, 0.1); R.SetSurfaceRim(g, 1, 0, 0, 0.2)
    check(#rf.rim._log == before[1] and #rf.top._log == before[2] and #rf.header._log == before[3],
          "SetRimAlpha, SetEdgeAlpha, SetWash and SetSurfaceRim don't touch them")

    -- Bad calls are refused at the call site, before anything is built.
    local hb = newHost(300, 200)
    local gb = R.Apply(hb, "large")
    local square = newHost(64, 64)
    local nWidgets = #WoW.widgets
    for _, case in ipairs({
        { "a nil surface", nil, hb, nil, "rect surface" },
        { "a table that isn't a surface", {}, hb, nil, "rect surface" },
        { "a disc", R.Disc(square, "disc_small"), square, nil, "rect surface" },
        { "a nil host", gb, nil, nil, "host frame" },
        { "a string for opts", gb, hb, "70", "options table" },
        { "a negative header", gb, hb, { header = -1 }, "header" },
        { "a NaN header", gb, hb, { header = 0 / 0 }, "header" },
        { "an infinite header", gb, hb, { header = math.huge }, "header" },
        { "a string header", gb, hb, { header = "70" }, "header" },
        { "a second Reflect", g, host, nil, "already" },
    }) do
        nWidgets = #WoW.widgets
        local ok, err = pcall(function() R.Reflect(case[2], case[3], case[4]) end)
        check(not ok and tostring(err):find("test_material%.lua:%d+: LibGlass.*" .. case[5]),
              case[1] .. " is refused at the call site: " .. tostring(err))
        eq(#WoW.widgets, nWidgets, case[1] .. ": nothing built")
    end
    eq(gb.reflect, nil, "and no reflection recorded")
    local hp = CreateFrame("Button", nil, UIParent)
    local pill, pg = R.Pill(hp)
    check(pcall(R.Reflect, pg, pill), "a pill is a rect surface: it takes one")
end

------------------------------------------------------------------------------
-- New: a colon call and a known font, or a loud error.
------------------------------------------------------------------------------
local okDot, errDot = pcall(LibGlass.New, { style = { rimAlpha = 1 } })
check(not okDot and tostring(errDot):find("with a colon", 1, true), "a dot call fails loudly: " .. tostring(errDot))
local okFont, errFont = pcall(LibGlass.New, LibGlass, { font = "comic" })
check(not okFont and tostring(errFont):find("unknown font", 1, true), "an unknown font fails loudly: " .. tostring(errFont))
eq(LibGlass:New({ font = "friz" }).fontKey, "friz", "a known one is taken")

------------------------------------------------------------------------------
-- The track ramp's length (r10): 0, the default, is the ramp across the whole
-- bar as before; a fraction moves it to the fill's moving edge and keeps only
-- its fade, over that fraction of the bar's (plain) width, which a size hook
-- follows. Every bar of the instance, live, both ways.
------------------------------------------------------------------------------
do
    local L = LibGlass:New()
    local h = newHost(300, 60)
    L.Apply(h, "large")
    local b = L.Bar(h, 34)
    local t = b.track
    eq(L.STYLE.trackLength, 0, "whole bar by default")
    eq(t._points[1][1], "ALL", "the ramp across the bar")
    check(not (b._hooks and b._hooks.OnSizeChanged), "no size hook until asked for")

    b:SetWidth(288)
    check(L.SetTrackLength(0.05), "SetTrackLength(0.05) accepted")
    eq(t._points[1][1], "TOPLEFT", "the ramp starts")
    eq(t._points[1][2], b:GetStatusBarTexture(), "at the fill's")
    eq(t._points[1][3], "TOPRIGHT", "moving edge")
    eq(t._points[2][3], "BOTTOMRIGHT", "top to bottom")
    near(t._width, 14.4, "over 5% of the bar")
    eq(t._texCoord[1], 0.30, "only the texture's fade")
    eq(t._texCoord[2], 0.85, "to where it is clear")
    eq(#b._hooks.OnSizeChanged, 1, "a size hook")
    b._hooks.OnSizeChanged[1](b, 400, 34)
    near(t._width, 20, "which follows the bar's width")
    b._hooks.OnSizeChanged[1](b, nil, 34)
    near(t._width, 20, "an unreadable width changes nothing")
    L.SetTrackLength(0.1)
    near(t._width, 28.8, "a new length, at the bar's current width")
    eq(#b._hooks.OnSizeChanged, 1, "never hooked twice")

    local b2 = L.Bar(h, 10)
    eq(b2.track._points[1][1], "TOPLEFT", "a bar built later takes the edge ramp")
    eq(b2.track._texCoord[1], 0.30, "with the fade only")

    check(L.SetTrackLength(0), "0 accepted")
    eq(t._points[1][1], "ALL", "the whole bar again")
    eq(t._points[1][2], b, "across the bar")
    eq(t._texCoord[2], 1, "the whole texture")
    b._hooks.OnSizeChanged[1](b, 500, 34)
    near(t._width, 28.8, "the hook leaves a whole-bar ramp alone")

    for _, v in ipairs({ 0 / 0, "0.05", 0.005, 1.5, -1, false }) do
        check(not L.SetTrackLength(v), "SetTrackLength refuses " .. tostring(v))
    end
    check(not L.SetTrackLength(), "and nothing")
    eq(L.STYLE.trackLength, 0, "a refusal keeps the value")

    -- Isolation: another instance's bars keep their ramp.
    local O = LibGlass:New()
    local ob = O.Bar(newHost(100, 20), 10)
    L.SetTrackLength(0.05)
    eq(ob.track._points[1][1], "ALL", "another instance's bar is untouched")

    -- A construction setting too.
    local C = LibGlass:New({ style = { trackLength = 0.2 } })
    local cb = C.Bar(newHost(100, 20), 10)
    eq(cb.track._points[1][1], "TOPLEFT", "style = { trackLength } builds edge ramps")
end

done("test_material")
