-- What happens when several addons embed the library: the newest copy loaded
-- wins, and it may not be yours.
--
-- r1 has no released predecessor, so the newer copy here is SYNTHETIC: this
-- checkout with MINOR + 1, a new STYLE key, EDGE key, TUNABLE and function,
-- a changed default, and every lib.impl function wrapped to count its calls.
-- Surfaces, instances, TUNABLES setters and bar hooks made by the current
-- copy must run the newer copy's code afterwards, keep their state and the
-- consumer's own overrides, and never be repainted. From r2 on, the released
-- r1 is frozen as tests/fixtures/LibGlass-r1.lua and loaded under the current
-- copy as well.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local MAJOR = "LibGlass-1.0"
local N = currentMinor()
check(N ~= nil, "LibGlass.lua declares its MINOR")
local function mediaOf(host) return "Interface\\AddOns\\" .. host .. "\\Libs\\LibGlass-1.0\\Media\\" end
local function activeMinor() return select(2, LibStub:GetLibrary(MAJOR)) end

-- The newer copy. MARK[name] counts calls into each of ITS impl functions.
local NEWER = synthetic(N + 1, [[
LIBGLASS_MARK = {}
function lib.impl.Probe(inst) return "probe:" .. tostring(inst.STYLE.probe) end
for name, f in pairs(lib.impl) do
    lib.impl[name] = function(...)
        LIBGLASS_MARK[name] = (LIBGLASS_MARK[name] or 0) + 1
        return f(...)
    end
end]], {
    { "    sheenAlpha = 0.8,\n", "    sheenAlpha = 0.8,\n    probe = 0.5,\n" },
    { "    rimAlpha = 0.7,", "    rimAlpha = 0.33," },
    { "glowh = 4 }", "glowh = 4, probeEdge = 2 }" },
    { '"SetFont" }', '"SetFont", "Probe" }' },
    { "help = \"a fine bright top line and dark bottom line, 0 = off\" },\n",
      "help = \"a fine bright top line and dark bottom line, 0 = off\" },\n"
      .. "    { key = \"probe\", style = \"probe\", fn = \"SetRimAlpha\", min = 0, max = 1, label = \"Probe\", help = \"probe\" },\n" },
})
local function mark(name) return (rawget(_G, "LIBGLASS_MARK") or {})[name] or 0 end

-- Every method call logged so far, per widget: an upgrade must add none.
local function logSizes()
    local t = {}
    for i, w in ipairs(WoW.widgets) do t[i] = #w._log end
    return t
end

------------------------------------------------------------------------------
-- The same version twice: the second load changes nothing.
------------------------------------------------------------------------------
do
    WoW.reset(); WoW.resetLibStub()
    local lib = loadLibrary("GlassUnitFrames")
    local A = lib:New()
    local apply, implApply, impl = A.Apply, lib.impl.Apply, lib.impl
    loadLibrary("GlassChat")
    eq(LibStub(MAJOR), lib, "equal-after-equal keeps the library table")
    eq(lib.impl, impl, "and lib.impl")
    eq(lib.impl.Apply, implApply, "and its functions")
    eq(A.Apply, apply, "and the instance's")
    eq(lib.MEDIA, mediaOf("GlassUnitFrames"), "MEDIA stays with the first copy")
    eq(#lib.instances, 1, "no instance added or lost")
    check(pcall(lib.New, lib), "New still works")
end

------------------------------------------------------------------------------
-- A newer copy over this one.
------------------------------------------------------------------------------
do
    WoW.reset(); WoW.resetLibStub()
    rawset(_G, "LIBGLASS_MARK", nil)
    local lib = loadLibrary("GlassUnitFrames")
    local A = lib:New({ style = { rimAlpha = 1 } })
    local B = lib:New()
    local host = newHost(200, 40)
    local g = A.Apply(host, "large")
    local bar = A.Bar(host, 20)
    bar:SetStatusBarColor(1, 0, 0)
    local gB = B.Apply(newHost(), "small")
    -- A consumer's direct overrides (GlassChat retints and re-alphas regions).
    g.rim:SetAlpha(0.1)
    g.tint:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    A.SetFillAlpha(0.5)
    -- What consumers hold on to.
    local held = {
        lib = lib, impl = lib.impl, instances = lib.instances, SIZES = lib.SIZES, small = lib.SIZES.small,
        FONTS = lib.FONTS, apply = A.Apply, setRim = A.TUNABLES[2].set, tunables = A.TUNABLES,
        firstTunable = A.TUNABLES[1], style = A.STYLE, edge = A.EDGE,
    }
    local before = logSizes()

    loadCopy(NEWER, "GlassChat")

    eq(activeMinor(), N + 1, "the newer copy is active")
    eq(lib.ready, N + 1, "and finished loading")
    eq(LibStub(MAJOR), held.lib, "the same library table")
    eq(lib.impl, held.impl, "lib.impl keeps its identity")
    eq(lib.instances, held.instances, "lib.instances too")
    eq(#lib.instances, 2, "with both instances")
    check(lib.SIZES == held.SIZES and lib.SIZES.small == held.small and lib.FONTS == held.FONTS,
          "public tables filled in place")

    -- Never repaints, never rebuilds.
    local after = logSizes()
    local touched = 0
    for i, n in ipairs(before) do if after[i] ~= n then touched = touched + 1 end end
    eq(touched, 0, "the upgrade made no call on any existing widget")
    eq(#after, #before, "and created none")
    eq(g.rim._alpha, 0.1, "a consumer's direct rim override survives")
    eq(g.tint._color[1], 0.5, "and its retint")

    -- Narrow migration: missing keys only.
    eq(A.STYLE, held.style, "STYLE keeps its identity")
    eq(A.EDGE, held.edge, "EDGE too")
    eq(A.STYLE.probe, 0.5, "a missing STYLE key is filled")
    eq(B.STYLE.probe, 0.5, "on every instance")
    eq(A.EDGE.probeEdge, 2, "a missing EDGE key is filled")
    eq(A.STYLE.rimAlpha, 1, "an addon's override is kept")
    eq(B.STYLE.rimAlpha, 0.7, "an older default is kept, not replaced by the new one")
    eq(A.STYLE.fillAlpha, 0.5, "a live-tuned value is kept")
    eq(A.TUNABLES, held.tunables, "TUNABLES keeps its identity")
    eq(#A.TUNABLES, 6, "a new tunable is appended")
    eq(A.TUNABLES[1], held.firstTunable, "existing entries untouched")
    eq(A.TUNABLES[2].default, 1, "with their captured defaults")
    eq(A.TUNABLES[6].key, "probe", "the new one last")
    eq(A.TUNABLES[6].default, 0.5, "its default from the instance's STYLE")
    local okProbe, probe = pcall(A.Probe)
    check(okProbe and probe == "probe:0.5", "a new function reaches old instances: " .. tostring(probe))
    local C = lib:New()
    eq(C.STYLE.rimAlpha, 0.33, "a new instance takes the new defaults")

    -- Old closures run the new code.
    eq(A.Apply, held.apply, "an instance function keeps its identity")
    local n0 = mark("Apply")
    local g2 = A.Apply(newHost(), "large")
    eq(mark("Apply"), n0 + 1, "an old instance's Apply runs the newer copy")
    eq(g2.rim._file, mediaOf("GlassChat") .. "rim5", "with the winning copy's media")
    eq(g2.rim._alpha, 1, "and the instance's STYLE")
    n0 = mark("SetRimAlpha")
    check(held.setRim(0.6), "a TUNABLES setter held from before the upgrade")
    eq(mark("SetRimAlpha"), n0 + 1, "runs the newer copy")
    eq(g.rim._alpha, 0.6, "on the surfaces built before it")
    eq(gB.rim._alpha, 0.7, "and only its own instance's")

    -- Hooks installed by the older copy dispatch to the newer one, once.
    n0 = mark("OnBarColor")
    bar:SetStatusBarColor(0, 1, 0)
    eq(mark("OnBarColor"), n0 + 1, "a recolour after the upgrade runs the newer hook body, once")
    eq(bar:GetStatusBarTexture()._alpha, 0.5, "and paints with the instance's STYLE")
    bar:SetStatusBarColor(0, 1, 0)
    eq(mark("OnBarColor"), n0 + 2, "an unchanged colour reaches it too (and returns early)")
    n0 = mark("OnBarHeight")
    bar:SetHeight(30)
    eq(mark("OnBarHeight"), n0 + 1, "a resize runs the newer hook body, once")
    eq(bar.glassState.inner._height, 13, "and keeps the shade at 45%")
    n0 = mark("OnBarLevel")
    bar:SetFrameLevel(12)
    eq(mark("OnBarLevel"), n0 + 1, "a relevel runs the newer hook body, once")
    eq(bar.overlay:GetFrameLevel(), 12 + lib.OVERLAY_LEVEL, "and moves the overlay")
    eq(bar.trackClip:GetFrameLevel(), 12 + lib.TRACK_LEVEL, "and the track's clip")
    local newBar = A.Bar(host, 10)
    n0 = mark("OnBarColor")
    newBar:SetStatusBarColor(0, 0, 1)
    eq(mark("OnBarColor"), n0 + 1, "a bar built after the upgrade is hooked once")

    -- MEDIA follows the winning copy; frames built earlier keep their path.
    eq(lib.MEDIA, mediaOf("GlassChat"), "MEDIA is the winning copy's folder")
    eq(A.MEDIA, mediaOf("GlassChat"), "and an old instance resolves to it")
    eq(rawget(A, "MEDIA"), nil, "through the library, not a copy")
    eq(bar:GetStatusBarTexture()._file, mediaOf("GlassUnitFrames") .. "bar_fill", "a bar built earlier keeps its path")
    eq(newBar:GetStatusBarTexture()._file, mediaOf("GlassChat") .. "bar_fill", "a new bar takes the winner's")
end

------------------------------------------------------------------------------
-- An older copy loading second is a no-op.
------------------------------------------------------------------------------
do
    WoW.reset(); WoW.resetLibStub()
    local lib = loadCopy(NEWER, "GlassChat")
    local A = lib:New()
    local fns = {}
    for k, v in pairs(lib.impl) do fns[k] = v end
    local defaults = lib.defaults.STYLE
    loadLibrary("GlassUnitFrames")
    eq(activeMinor(), N + 1, "the newer copy stays active")
    eq(lib.ready, N + 1, "and its marker")
    eq(lib.MEDIA, mediaOf("GlassChat"), "and its media")
    eq(lib.defaults.STYLE, defaults, "and its defaults")
    local same = true
    for k, v in pairs(fns) do if lib.impl[k] ~= v then same = false end end
    for k in pairs(lib.impl) do if fns[k] == nil then same = false end end
    check(same, "and every impl function")
    eq(A.STYLE.rimAlpha, 0.33, "its instance untouched")
    eq(#lib.instances, 1, "no instance added")
    check(pcall(lib.New, lib), "New still works")
end

------------------------------------------------------------------------------
-- A newer copy that throws partway: New refuses the half-loaded library.
------------------------------------------------------------------------------
do
    WoW.reset(); WoW.resetLibStub()
    local lib = loadLibrary("GlassUnitFrames")
    local A = lib:New()
    local BROKEN = synthetic(N + 1, nil, {
        { "lib.shared = lib.shared or {}", "error(\"synthetic failure mid-load\")\nlib.shared = lib.shared or {}" },
    })
    local ok, err = pcall(loadCopy, BROKEN, "GlassChat")
    check(not ok and tostring(err):find("synthetic failure mid-load", 1, true), "the broken copy threw")
    eq(activeMinor(), N + 1, "LibStub already counts it as active")
    eq(lib.ready, N, "but the marker is still the older copy's")
    local okNew, errNew = pcall(lib.New, lib)
    check(not okNew, "New fails loudly")
    check(tostring(errNew):find("did not finish loading", 1, true), "saying why: " .. tostring(errNew))
    check(pcall(A.Apply, newHost(), "large"), "an instance made earlier still draws")
end

------------------------------------------------------------------------------
-- MEDIA without a host name (a bare load, as in some tools).
------------------------------------------------------------------------------
do
    WoW.reset(); WoW.resetLibStub()
    local lib = loadCopy(copyOf(), nil)
    eq(lib.MEDIA, "Interface\\AddOns\\LibGlass-1.0\\Media\\", "no host: the standalone folder")
end

------------------------------------------------------------------------------
-- The completion marker is the last line.
------------------------------------------------------------------------------
local src = readFile("LibGlass.lua")
check(src:match("\nlib%.ready = MINOR%s*$"), "lib.ready = MINOR is the last line of LibGlass.lua")

done("test_upgrade")
