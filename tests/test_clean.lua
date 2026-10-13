-- Opt-in material, independent opacity, and compatibility with existing instances.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local lib = loadLibrary()
local normal = lib:New()
local clean = lib:New({ preset = "clean" })
local smoked = lib:New({ preset = "clean", bodyAlpha = 0.8 })
local function surface(inst, size)
    return inst.Apply(newHost(280, 64), size)
end
local g = surface(clean)
eq(g.size, "thin", "clean default resolves to thin")
eq(g.rim._file, clean.MEDIA .. "rim_thin", "thin asset drawn")
eq(g.shadow._alpha, 0.30, "reduced shadow")
eq(g.grain._alpha, 0, "no grain")
eq(g.tint._color[4], 0.24, "clear by default")
eq(surface(smoked).tint._color[4], 0.8, "independent smoked body")
eq(surface(normal).size, "large", "normal default unchanged")
eq(surface(normal).shadow._alpha, nil, "normal shadow call stream unchanged")
for _, case in ipairs({ { "large", "thin", 4 }, { "small", "thin_small", 2 },
                       { "thin", "thin", 4 }, { "thin_small", "thin_small", 2 } }) do
    eq(surface(clean, case[1]).size, case[2], "clean resolves " .. case[1])
    eq(clean.Inset(case[1]), case[3], "content inset follows " .. case[1])
end
eq(clean.Inset(), 4, "default inset follows preset")
eq(normal.Inset(), 6, "normal inset unchanged")
local disc = clean.Disc(newHost(64, 64), "disc_small")
eq(disc.size, "disc_small", "disc geometry unchanged")
eq(disc.shadow._alpha, 0.30, "disc gets material shadow")
eq(clean.Inset("disc_small"), 4, "disc inset unchanged")
local _, pill = clean.Pill(CreateFrame("Button", nil, UIParent))
eq(pill.size, "thin_small", "pill follows clean geometry")
eq(pill.shadow._alpha, 0, "pill still suppresses shadow")
local bar = clean.Bar(newHost(), 22)
bar:SetStatusBarColor(0.22, 0.72, 0.42)
eq(bar.track._vertex[4], 0, "neutral empty track rendered")
eq(clean.STYLE.gloss, 0.25, "moderate gloss")
eq(bar.glassState.inner._gradient[2].a, 0.15, "moderate shade rendered")
local glossFound = false
for _, w in ipairs(WoW.widgets) do
    if w._parent == bar.overlay and w._file == clean.MEDIA .. "gloss" then
        eq(w._alpha, 0.25, "moderate gloss rendered")
        glossFound = true
    end
end
check(glossFound, "bar gloss exists")
eq(clean.TUNABLES[3].default, 0, "track tunable reflects preset")
clean.SetTrackAlpha(0.2)
eq(bar.track._vertex[4], 0.2, "existing live track override works")
eq(normal.STYLE.trackTop, 0.75, "normal instance isolated")
eq(smoked.STYLE.trackTop, 0, "other clean instance isolated")

local custom = lib:New({ preset = "clean", bodyAlpha = 0.5,
    style = { thinRim = false, shadowAlpha = 0, grain = 0.1, gloss = 0.4,
              trackTop = 0.2, tint = { 0.3, 0.2, 0.1, 0.9 } } })
local c = surface(custom)
eq(c.size, "large", "explicit rim override wins")
eq(c.shadow._alpha, 0, "explicit shadow override wins, including zero")
eq(c.grain._alpha, 0.1, "explicit grain override wins")
eq(c.tint._color[1], 0.3, "custom tint RGB preserved")
eq(c.tint._color[4], 0.5, "bodyAlpha takes precedence over tint alpha")
eq(surface(lib:New({ bodyAlpha = 0 })).tint._color[4], 0, "opacity works without preset, including zero")
clean.SetSurfaceTint(g, 0.2, 0.3, 0.4, 0.8)
clean.SetSurfaceEnabled(g, false)
eq(g.tint._color[4], 0.8, "disabled state preserves tint opacity")
clean.SetSurfaceEnabled(g, true)
clean.SetSurfaceTint(g)
eq(g.tint._color[4], 0.24, "reset returns to built opacity")
eq(smoked.STYLE.tint[4], 0.8, "tint tables isolated")
local count = #lib.instances
for _, opts in ipairs({ { preset = "unknown" }, { bodyAlpha = -1 }, { bodyAlpha = 2 },
                       { bodyAlpha = "0.5" }, { bodyAlpha = 0/0 } }) do
    check(not pcall(lib.New, lib, opts), "bad option refused")
end
eq(#lib.instances, count, "bad options do not register an instance")

-- Every released instance must remain classic after upgrading, including new
-- surfaces built through its old wrapper. Existing regions must not be repainted.
for n = 1, 5 do
    WoW.reset(); WoW.resetLibStub()
    local oldLib = loadCopy(fixtureCopy("LibGlass-r" .. n .. ".lua"), "OldHost")
    local old = oldLib:New()
    local before = surface(old)
    local logs = {}
    for i, w in ipairs(WoW.widgets) do logs[i] = #w._log end
    lib = loadLibrary("NewHost")
    for i, length in ipairs(logs) do eq(#WoW.widgets[i]._log, length, "upgrade does not repaint r" .. n) end
    eq(before.size, "large", "existing size preserved")
    eq(surface(old).size, "large", "old instance still builds classic")
    eq(old.STYLE.shadowAlpha, 1, "old instance receives classic shadow default")
    eq(surface(lib:New({ preset = "clean", bodyAlpha = 0.8 })).size, "thin", "new preset after upgrade")
end
done("test_clean")
