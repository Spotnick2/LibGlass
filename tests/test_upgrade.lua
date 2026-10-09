-- What happens when several addons embed the library: the newest copy loaded
-- wins, and it may not be yours.
--
-- Two kinds of older/newer copy:
-- - SYNTHETIC newer: this checkout with MINOR + 1, a new STYLE key, EDGE key,
--   TUNABLE and function, a changed default, and every lib.impl function
--   wrapped to count its calls. Surfaces, instances, TUNABLES setters and bar
--   hooks made by the current copy must run the newer copy's code afterwards,
--   keep their state and the consumer's own overrides, and never be repainted.
-- - RELEASED older: each released copy frozen as tests/fixtures/LibGlass-rN.lua
--   (rN = `git show rN:LibGlass.lua`), loaded under the current copy (the
--   current one upgrades it) and after it (a no-op). The fixture of the
--   current MINOR must be this LibGlass.lua: a code change after a release
--   raises MINOR. (Only the Lua is compared: a Media\, XML or LibStub change
--   needs the same bump by hand.)
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
    { '"Pill", "RelevelPill" }', '"Pill", "RelevelPill", "Probe" }' },
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
    -- A consumer's own entry in its TUNABLES (an options-UI separator): an
    -- upgrade must not trip over it, or the newer copy never finishes loading
    -- and New fails for every addon after it.
    table.insert(B.TUNABLES, { label = "---" })
    -- What consumers hold on to.
    local held = {
        lib = lib, impl = lib.impl, instances = lib.instances, SIZES = lib.SIZES, small = lib.SIZES.small,
        FONTS = lib.FONTS, functions = lib.FUNCTIONS, apply = A.Apply, setRim = A.TUNABLES[2].set, tunables = A.TUNABLES,
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
    eq(lib.FUNCTIONS, held.functions, "FUNCTIONS keeps its identity")
    eq(lib.FUNCTIONS[#lib.FUNCTIONS], "Probe", "with the new function appended")

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
-- Surfaces from older code may lack regions this copy builds: the setters
-- and hooks skip what isn't there. (r1 has no older copy, so the regions are
-- removed by hand: no track, a bar state without its frames, no state at all,
-- no edge.)
------------------------------------------------------------------------------
do
    WoW.reset(); WoW.resetLibStub()
    local lib = loadLibrary("GlassUnitFrames")
    local O = lib:New()
    local host = newHost()
    local g = O.Apply(host, "large")
    local noTrack, bare, stateless = O.Bar(host, 20), O.Bar(host, 20), O.Bar(host, 20)
    rawset(noTrack, "track", nil)
    rawset(bare, "glassState", { inst = O })
    rawset(stateless, "glassState", nil)
    g.edge = nil
    loadCopy(NEWER, "GlassChat")
    local ok, err = pcall(function()
        noTrack:SetStatusBarColor(1, 0, 0)
        O.SetTrackAlpha(0.3); O.SetFillEnd(0.5)
        bare:SetHeight(30); bare:SetFrameLevel(8); bare:SetStatusBarColor(0, 1, 0)
        stateless:SetStatusBarColor(0, 0, 1); stateless:SetHeight(30); stateless:SetFrameLevel(8)
        O.SetEdge(g, 0.5, 0.1, 0.3)
    end)
    check(ok, "setters and hooks skip regions older code didn't build: " .. tostring(err))
    eq(noTrack:GetStatusBarTexture()._alpha, 0.6, "and still paint what is there")
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
-- The released r1 (frozen fixture) upgraded by this copy.
------------------------------------------------------------------------------
local R1 = fixtureCopy("LibGlass-r1.lua")
check(R1[#R1].src:match('local MAJOR, MINOR = "LibGlass%-1%.0", 1%s'), "the r1 fixture is MINOR 1")
check(N > 1, "this copy is newer than r1")
do
    WoW.reset(); WoW.resetLibStub()
    local lib = loadCopy(R1, "GlassUnitFrames")
    eq(activeMinor(), 1, "r1 is active")
    local A = lib:New({ style = { rimAlpha = 1 } })
    local B = lib:New()
    local host = newHost(200, 40)
    local g = A.Apply(host, "large")
    local bar = A.Bar(host, 20)
    bar:SetStatusBarColor(1, 0, 0)
    local gB = B.Apply(newHost(), "small")
    g.rim:SetAlpha(0.1)                      -- a consumer's direct override
    A.SetFillAlpha(0.5)                      -- a live-tuned value
    table.insert(B.TUNABLES, { label = "---" })
    check(rawget(A, "Disc") == nil and lib.SIZES.disc == nil, "r1 has no Disc")
    local held = {
        impl = lib.impl, instances = lib.instances, SIZES = lib.SIZES, large = lib.SIZES.large,
        FONTS = lib.FONTS, functions = lib.FUNCTIONS, apply = A.Apply, setRim = A.TUNABLES[2].set,
        tunables = A.TUNABLES, style = A.STYLE, edge = A.EDGE,
    }
    local nFunctions = #lib.FUNCTIONS
    local before = logSizes()

    loadLibrary("GlassChat")

    eq(activeMinor(), N, "this copy is active")
    eq(lib.ready, N, "and finished loading")
    eq(LibStub(MAJOR), lib, "the same library table")
    check(lib.impl == held.impl and lib.instances == held.instances, "lib.impl and lib.instances keep their identity")
    check(lib.SIZES == held.SIZES and lib.SIZES.large == held.large and lib.FONTS == held.FONTS,
          "SIZES and FONTS filled in place")
    eq(lib.FUNCTIONS, held.functions, "FUNCTIONS keeps r1's table")
    eq(#lib.FUNCTIONS, nFunctions + 5, "with r2's, r3's and r5's names appended")
    eq(table.concat(lib.FUNCTIONS, ",", nFunctions + 1), "Disc,SetSurfaceTint,SetSurfaceEnabled,Pill,RelevelPill", "in order")
    check(lib.SIZES.disc and lib.SIZES.disc_small, "SIZES gains the disc sets")

    local after = logSizes()
    local touched = 0
    for i, n in ipairs(before) do if after[i] ~= n then touched = touched + 1 end end
    eq(touched, 0, "the upgrade made no call on any existing widget")
    eq(#after, #before, "and created none")
    eq(g.rim._alpha, 0.1, "a consumer's direct override survives")
    eq(A.STYLE, held.style, "STYLE keeps its identity")
    eq(A.EDGE, held.edge, "EDGE too")
    eq(A.STYLE.rimAlpha, 1, "an addon's override is kept")
    eq(A.STYLE.fillAlpha, 0.5, "a live-tuned value is kept")
    eq(A.TUNABLES, held.tunables, "TUNABLES keeps its identity")
    eq(#A.TUNABLES, 5, "with the same five knobs")
    eq(#B.TUNABLES, 6, "and a consumer's own entry tolerated")

    check(type(rawget(A, "Disc")) == "function", "an r1 instance gains Disc")
    local d = A.Disc(newHost(64, 64), "disc_small")
    eq(d.rim._file, mediaOf("GlassChat") .. "disc_rim_small", "drawn from the winning copy's folder")
    eq(d.rim._alpha, 1, "with the instance's STYLE")
    check(held.setRim(0.6), "a TUNABLES setter held from r1")
    eq(d.rim._alpha, 0.6, "reaches the disc")
    eq(g.rim._alpha, 0.6, "and the r1-built surface")
    eq(gB.rim._alpha, 0.7, "and not the other instance's")
    eq(A.Apply, held.apply, "an instance function keeps its identity")

    -- r1's hooks dispatch to this copy's bodies.
    local calls, orig = 0, lib.impl.OnBarColor
    lib.impl.OnBarColor = function(...) calls = calls + 1; return orig(...) end
    bar:SetStatusBarColor(0, 1, 0)
    lib.impl.OnBarColor = orig
    eq(calls, 1, "an r1 bar's colour hook runs this copy's body, once")
    eq(bar:GetStatusBarTexture()._alpha, 0.5, "and paints with the instance's STYLE")
    check(pcall(A.Mask, host, "disc_mask", nil), "an r1 instance's Mask takes a nil margin now")
end

------------------------------------------------------------------------------
-- The released r1 loading after this copy: a no-op.
------------------------------------------------------------------------------
do
    WoW.reset(); WoW.resetLibStub()
    local lib = loadLibrary("GlassChat")
    local A = lib:New()
    local fns = {}
    for k, v in pairs(lib.impl) do fns[k] = v end
    local functions, nFunctions, disc = lib.FUNCTIONS, #lib.FUNCTIONS, lib.SIZES.disc
    loadCopy(R1, "GlassUnitFrames")
    eq(activeMinor(), N, "this copy stays active")
    eq(lib.ready, N, "and its marker")
    eq(lib.MEDIA, mediaOf("GlassChat"), "and its media")
    check(lib.FUNCTIONS == functions and #lib.FUNCTIONS == nFunctions, "r1 doesn't replace FUNCTIONS")
    eq(lib.SIZES.disc, disc, "nor SIZES")
    local same = true
    for k, v in pairs(fns) do if lib.impl[k] ~= v then same = false end end
    for k in pairs(lib.impl) do if fns[k] == nil then same = false end end
    check(same, "nor any impl function")
    check(pcall(A.Disc, newHost(128, 128)), "Disc still works")
    eq(#lib.instances, 1, "no instance added")
end

------------------------------------------------------------------------------
-- Every released copy (frozen fixture, added here when its tag is pushed).
-- The release with this MINOR must be this LibGlass.lua, byte for byte (two
-- builds sharing a MINOR would let either one win; Media\, the XML and LibStub
-- are not compared). Every older release is upgraded
-- in place by this copy and is a no-op loading after it. r1's specifics are
-- tested above; this part is generic, so rN joins by its file name.
------------------------------------------------------------------------------
local RELEASES = { "LibGlass-r1.lua", "LibGlass-r2.lua", "LibGlass-r3.lua", "LibGlass-r4.lua",
                   "LibGlass-r5.lua" }
for _, file in ipairs(RELEASES) do
    local copy = fixtureCopy(file)
    local src = copy[#copy].src
    local K = tonumber(src:match('local MAJOR, MINOR = "LibGlass%-1%.0", (%d+)%s'))
    local r = "r" .. tostring(K)
    check(K and K <= N, file .. " declares a MINOR no newer than this copy")
    check(src:match("\nlib%.ready = MINOR%s*$"), file .. " ends with its completion marker")
    if K == N then
        check(src == (readFile("LibGlass.lua"):gsub("\r\n", "\n")),
              "LibGlass.lua is " .. r .. " as released: raise MINOR for any code change")
    elseif K then
        WoW.reset(); WoW.resetLibStub()
        local lib = loadCopy(copy, "GlassUnitFrames")
        eq(activeMinor(), K, r .. " is active")
        local A, B = lib:New({ style = { rimAlpha = 1 } }), lib:New()
        local host = newHost(200, 40)
        local g = A.Apply(host, "large")
        local bar = A.Bar(host, 20)
        bar:SetStatusBarColor(1, 0, 0)
        local d = rawget(A, "Disc") and A.Disc(newHost(64, 64), "disc_small")
        local gB = B.Apply(newHost(), "small")
        local held = { impl = lib.impl, instances = lib.instances, functions = lib.FUNCTIONS,
                       SIZES = lib.SIZES, STYLE = A.STYLE, setRim = A.TUNABLES[2].set }
        local names = {}
        for i, n in ipairs(lib.FUNCTIONS) do names[i] = n end
        local dimBefore = A.STYLE.disabledAlpha   -- nil before r3
        local before = logSizes()

        loadLibrary("GlassChat")

        eq(activeMinor(), N, r .. " upgraded: this copy is active")
        eq(lib.ready, N, r .. " upgraded: and finished loading")
        check(lib.impl == held.impl and lib.instances == held.instances and lib.FUNCTIONS == held.functions
              and lib.SIZES == held.SIZES and A.STYLE == held.STYLE, r .. " upgraded: public tables keep their identity")
        local kept = true
        for i, n in ipairs(names) do if lib.FUNCTIONS[i] ~= n then kept = false end end
        check(kept, r .. " upgraded: FUNCTIONS keeps " .. r .. "'s names in place")
        for _, n in ipairs(lib.FUNCTIONS) do
            check(type(rawget(A, n)) == "function", r .. " upgraded: its instance has " .. n)
        end
        local after = logSizes()
        local touched = 0
        for i, n in ipairs(before) do if after[i] ~= n then touched = touched + 1 end end
        eq(touched, 0, r .. " upgraded: no call on any existing widget")
        eq(#after, #before, r .. " upgraded: and none created")
        eq(A.STYLE.rimAlpha, 1, r .. " upgraded: an addon's override is kept")
        check(held.setRim(0.6), r .. " upgraded: a TUNABLES setter held from " .. r)
        eq(g.rim._alpha, 0.6, r .. " upgraded: reaches the " .. r .. "-built rect")
        if d then eq(d.rim._alpha, 0.6, r .. " upgraded: and disc") end
        eq(gB.rim._alpha, 0.7, r .. " upgraded: and not the other instance's")
        local calls, orig = 0, lib.impl.OnBarColor
        lib.impl.OnBarColor = function(...) calls = calls + 1; return orig(...) end
        bar:SetStatusBarColor(0, 1, 0)
        lib.impl.OnBarColor = orig
        eq(calls, 1, r .. " upgraded: its bar hook runs this copy's body, once")
        -- r3's per-surface setters reach surfaces an older copy built.
        -- An upgrade keeps an instance's disabledAlpha and fills it only where missing.
        eq(A.STYLE.disabledAlpha, dimBefore or lib.defaults.STYLE.disabledAlpha,
           r .. " upgraded: disabledAlpha kept, or filled with this copy's default")
        check(A.SetSurfaceTint(g, 0.2, 0.5, 0.3, 0.4), r .. " upgraded: SetSurfaceTint on an " .. r .. "-built rect")
        eq(g.tint._color[2], 0.5, r .. " upgraded: and paints it")
        A.SetSurfaceEnabled(g, false)
        near(g.rim._alpha, 0.6 * A.STYLE.disabledAlpha, r .. " upgraded: SetSurfaceEnabled dims its rim")
        eq(g.wash._alpha, A.STYLE.disabledAlpha, r .. " upgraded: and its wash")
        if d then
            A.SetSurfaceEnabled(d, false)
            near(d.rim._alpha, 0.6 * A.STYLE.disabledAlpha, r .. " upgraded: and an " .. r .. "-built disc")
        end
        -- r5's Pill on an instance an older copy made.
        local pb = CreateFrame("Button", nil, UIParent)
        pb:SetFrameLevel(5)
        local pill, pg = A.Pill(pb)
        eq(pg.top:GetFrameLevel(), 4, r .. " upgraded: Pill on an " .. r .. " instance")
        A.SetRimAlpha(0.5)
        eq(pg.rim._alpha, 0.5, r .. " upgraded: and its rim follows that instance")
        pb:SetFrameLevel(9)
        check(A.RelevelPill(pill), r .. " upgraded: RelevelPill too")
        check(pill:GetFrameLevel() == 8 and pg.top:GetFrameLevel() == 8, r .. " upgraded: and it moves the pill and its rims")

        WoW.reset(); WoW.resetLibStub()
        local cur = loadLibrary("GlassChat")
        local C = cur:New()
        local fns = {}
        for k, v in pairs(cur.impl) do fns[k] = v end
        local functions, nFunctions = cur.FUNCTIONS, #cur.FUNCTIONS
        loadCopy(copy, "GlassUnitFrames")
        eq(activeMinor(), N, r .. " second: this copy stays active")
        eq(cur.ready, N, r .. " second: and its marker")
        eq(cur.MEDIA, mediaOf("GlassChat"), r .. " second: and its media")
        check(cur.FUNCTIONS == functions and #cur.FUNCTIONS == nFunctions, r .. " second: FUNCTIONS untouched")
        local same = true
        for k, v in pairs(fns) do if cur.impl[k] ~= v then same = false end end
        for k in pairs(cur.impl) do if fns[k] == nil then same = false end end
        check(same, r .. " second: no impl function replaced")
        check(pcall(C.Disc, newHost(128, 128)), r .. " second: Disc still works")
        eq(#cur.instances, 1, r .. " second: no instance added")
    end
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
