-- Two addons, two instances: each one's setters, STYLE, font and TUNABLES
-- touch only the surfaces built through it (GlassUnitFrames' /glass rim must
-- not dim GlassChat), while the shared data is one table.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local LibGlass = loadLibrary("GlassUnitFrames")
local A = LibGlass:New()
local B = LibGlass:New({ style = { rimAlpha = 1, tint = { 0, 0, 0, 0.5 } }, font = "friz" })

local function build(Glass)
    local host = newHost(200, 40)
    local s = { g = Glass.Apply(host, "large"), bar = Glass.Bar(host, 20), fs = Glass.Font(host, 12) }
    s.bar:SetStatusBarColor(1, 0, 0)
    return s
end
local a, b = build(A), build(B)

check(A.STYLE ~= B.STYLE and A.EDGE ~= B.EDGE and A.TUNABLES ~= B.TUNABLES, "each has its own STYLE, EDGE and TUNABLES")
check(A.STYLE.tint ~= B.STYLE.tint and A.STYLE.tint ~= LibGlass.defaults.STYLE.tint, "nested STYLE tables copied too")
check(A.Apply ~= B.Apply, "and its own functions")
check(A.SIZES == B.SIZES and A.FONTS == B.FONTS and A.SIZES == LibGlass.SIZES, "SIZES and FONTS are shared")
eq(A.MEDIA, B.MEDIA, "MEDIA is shared")

-- Options are per instance.
eq(B.STYLE.rimAlpha, 1, "opts.style overrides")
eq(b.g.rim._alpha, 1, "and draws with them")
eq(a.g.rim._alpha, 0.7, "the other instance keeps the default")
eq(b.g.tint._color[4], 0.5, "a nested override (tint)")
eq(a.g.tint._color[4], 0.24, "not shared")
eq(B.STYLE.grain, 0.45, "keys not overridden keep the default")
eq(B.fontKey, "friz", "opts.font")
eq(b.fs._font[1], "Fonts\\FRIZQT__.TTF", "and draws with it")
eq(A.fontKey, "arial", "the other instance keeps Arial")
eq(B.TUNABLES[2].default, 1, "a tunable's default is the instance's own value")
eq(A.TUNABLES[2].default, 0.7, "per instance")

-- Every setter touches its own instance only.
A.SetRimAlpha(0.4)
eq(a.g.rim._alpha, 0.4, "A's rim retuned")
eq(b.g.rim._alpha, 1, "B's rim untouched")
eq(B.STYLE.rimAlpha, 1, "B's STYLE untouched")
A.SetFillAlpha(0.3)
eq(a.bar:GetStatusBarTexture()._alpha, 0.3, "A's fill retuned")
eq(b.bar:GetStatusBarTexture()._alpha, 0.6, "B's fill untouched")
A.SetTrackAlpha(0.2)
eq(a.bar.track._vertex[4], 0.2, "A's track retuned")
eq(b.bar.track._vertex[4], 0.75, "B's track untouched")
A.SetFillEnd(0.5)
eq(a.bar:GetStatusBarTexture()._gradient[3].a, 0.5, "A's fade retuned")
eq(b.bar:GetStatusBarTexture()._gradient[3].a, 1, "B's fade untouched")
A.SetEdgeAlpha(0.45)
check(a.g.edge.top:IsShown(), "A's edge shown")
check(not b.g.edge.top:IsShown(), "B's edge still off")
A.SetFont("friz")
B.SetFont("arial")
eq(a.fs._font[1], "Fonts\\FRIZQT__.TTF", "A's font switched")
eq(b.fs._font[1], "Fonts\\ARIALN.TTF", "B's switched separately")
A.TUNABLES[2].set(0.9)
eq(a.g.rim._alpha, 0.9, "A's tunable reaches A")
eq(b.g.rim._alpha, 1, "and not B")

-- A disc's rim follows only its own instance's SetRimAlpha.
local dA, dB = A.Disc(newHost(64, 64), "disc_small"), B.Disc(newHost(256, 256), "disc")
eq(dA.rim._alpha, 0.9, "A's disc takes A's rim alpha")
eq(dB.rim._alpha, 1, "B's disc takes B's")
A.SetRimAlpha(0.3)
eq(dA.rim._alpha, 0.3, "A's disc retuned")
eq(dB.rim._alpha, 1, "B's disc untouched")
B.SetRimAlpha(0.8)
eq(dB.rim._alpha, 0.8, "B's disc follows B")
eq(dA.rim._alpha, 0.3, "and A's doesn't")
eq(a.g.rim._alpha, 0.3, "A's rect rim with it")
eq(b.g.rim._alpha, 0.8, "B's rect rim with B")
A.SetRimAlpha(0.9); B.SetRimAlpha(1)

-- A bar's hook paints with its own instance's STYLE.
b.bar:SetStatusBarColor(0, 0, 1)
eq(b.bar:GetStatusBarTexture()._alpha, 0.6, "B's recolour keeps B's fill opacity, not A's")
eq(b.bar.track._vertex[4], 0.75, "and B's track alpha")
a.bar:SetStatusBarColor(0, 1, 0)
eq(a.bar:GetStatusBarTexture()._alpha, 0.3, "A's recolour keeps A's")

-- AltStable mutates its instance's STYLE before each Apply.
B.STYLE.grain = 0.1
local g3 = B.Apply(newHost(), "small")
eq(g3.grain._alpha, 0.1, "a STYLE change shows on the next Apply")
eq(A.STYLE.grain, 0.45, "and stays in that instance")

eq(#LibGlass.instances, 2, "the library knows both instances")

done("test_isolation")
