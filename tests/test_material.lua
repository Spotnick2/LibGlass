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

-- Translucent bar fill: texture alpha on every glass bar, text untouched.
eq(bar:GetStatusBarTexture()._alpha, 0.6, "bar fill at the default opacity (owner-picked)")
check(Glass.SetFillAlpha(0.5), "fill accepted")
eq(bar:GetStatusBarTexture()._alpha, 0.5, "fill retuned live")
eq(bar2:GetStatusBarTexture()._alpha, 0.5, "on every bar")
check(fs._alpha == nil or fs._alpha == 1, "text stays opaque")
bar:SetStatusBarColor(1, 0, 0)
eq(bar:GetStatusBarTexture()._alpha, 0.5, "recolouring keeps the fill opacity")
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
check(fg and fg[1] == "HORIZONTAL" and fg[2].a == 1 and fg[3].a == 1 and fg[3].r == 1,
      "fill even by default (fade off), in the bar's colour")
check(Glass.SetFillEnd(0.5), "fade accepted")
eq(bar:GetStatusBarTexture()._gradient[3].a, 0.5, "fade retuned live")

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
eq(fillTex._gradient[2].a, 0.5, "SetStatusBarColor's alpha kept")
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
-- and the opt-in thin rim. Instance setters leave the per-surface state alone.
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
    check(not S.SetSurfaceTint(a, 0.2, 0.6, 0.3), "a missing alpha is refused")
    check(not S.SetSurfaceTint(a, 0 / 0, 0, 0, 1), "NaN is refused")
    check(not S.SetSurfaceTint(a, 2, 0, 0, 1), "out of range is refused")
    eq(a.tint._color[4], 0.9, "and a refusal leaves the tint")
    S.SetRimAlpha(0.5); S.SetFillAlpha(0.5); S.SetEdgeAlpha(0.3)
    eq(a.tint._color[4], 0.9, "instance setters leave a surface's tint alone")
    S.STYLE.tint = { 0.1, 0.1, 0.1, 0.3 }
    check(S.SetSurfaceTint(a), "no colour: back to the instance's")
    eq(a.tint._color[4], 0.3, "its current STYLE.tint")
    check(S.SetSurfaceTint({}, 0, 0, 0, 1) == false, "a table that isn't a surface is refused")

    -- Disabled: tint, wash, dark rim, rim and edge dimmed; text is the caller's.
    eq(S.STYLE.disabledAlpha, 0.4, "the shipped dim")
    S.SetSurfaceEnabled(a, false)
    eq(a.tint._alpha, 0.4, "disabled: tint dimmed")
    eq(a.wash._alpha, 0.4, "wash dimmed")
    eq(a.dark._alpha, 0.4, "dark rim dimmed")
    near(a.rim._alpha, 0.5 * 0.4, "rim dimmed from the instance's rim alpha")
    check(a.edge.top._alpha == 0.4 and a.edge.glow._alpha == 0.4 and a.edge.bottom._alpha == 0.4, "edge dimmed")
    eq(a.tint._color[4], 0.3, "the tint's colour untouched")
    check(a.grain._alpha == S.STYLE.grain and a.shadow._alpha == nil, "grain and shadow untouched")
    eq(b.rim._alpha, 0.5, "the other surface stays enabled")
    S.SetRimAlpha(0.8)
    near(a.rim._alpha, 0.8 * 0.4, "SetRimAlpha keeps a disabled rim dimmed")
    eq(b.rim._alpha, 0.8, "and sets the enabled ones")
    S.SetEdgeAlpha(0.6)
    eq(a.edge.top._alpha, 0.4, "SetEdgeAlpha keeps a disabled edge dimmed")
    eq(a.edge.top._color[4], 0.6, "while setting its colour")
    S.SetSurfaceTint(a, 0.2, 0.6, 0.3, 0.9)
    eq(a.tint._alpha, 0.4, "a tint change keeps the dim")
    S.SetSurfaceEnabled(a, true)
    check(a.tint._alpha == 1 and a.wash._alpha == 1 and a.dark._alpha == 1 and a.edge.top._alpha == 1, "enabled again: undimmed")
    eq(a.rim._alpha, 0.8, "and the rim at the instance's alpha")
    S.SetRimAlpha(0.7)
    eq(a.rim._alpha, 0.7, "re-enabled rims follow SetRimAlpha again")
    S.SetSurfaceEnabled(disc, false)
    near(disc.rim._alpha, 0.7 * 0.4, "a disc dims too (no edge)")
    S.SetSurfaceEnabled(disc, nil)
    near(disc.rim._alpha, 0.7 * 0.4, "nil disables, as the client's SetEnabled")

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
-- New: a colon call and a known font, or a loud error.
------------------------------------------------------------------------------
local okDot, errDot = pcall(LibGlass.New, { style = { rimAlpha = 1 } })
check(not okDot and tostring(errDot):find("with a colon", 1, true), "a dot call fails loudly: " .. tostring(errDot))
local okFont, errFont = pcall(LibGlass.New, LibGlass, { font = "comic" })
check(not okFont and tostring(errFont):find("unknown font", 1, true), "an unknown font fails loudly: " .. tostring(errFont))
eq(LibGlass:New({ font = "friz" }).fontKey, "friz", "a known one is taken")

done("test_material")
