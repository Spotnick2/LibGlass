-- The presets (r11, #64): "classic" as the defaults alone, "pearl" as clean
-- with a softer upper light, inst.preset, and what an upgrade does to
-- instances that older copies made (it never names their preset).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local lib = loadLibrary()
local function surface(inst, size) return inst.Apply(newHost(280, 64), size) end

------------------------------------------------------------------------------
-- Resolution and inst.preset
------------------------------------------------------------------------------
local normal, classic = lib:New(), lib:New({ preset = "classic" })
local clean, pearl = lib:New({ preset = "clean" }), lib:New({ preset = "pearl" })
eq(normal.preset, "classic", "no preset is classic")
eq(classic.preset, "classic", "classic named")
eq(clean.preset, "clean", "clean named")
eq(pearl.preset, "pearl", "pearl named")
for k, v in pairs(lib.defaults.STYLE) do
    if type(v) ~= "table" then eq(classic.STYLE[k], v, "classic is the defaults: " .. k) end
end
-- Pearl: clean, with the softer upper light.
local PEARL = { wash = 0.10, gloss = 0.15, frost = 0.06 }
for k, v in pairs(clean.STYLE) do
    if type(v) ~= "table" then eq(pearl.STYLE[k], PEARL[k] or v, "pearl is clean but its light: " .. k) end
end
eq(pearl.STYLE.innerShadow, 0.15, "pearl keeps clean's inner shade (the depth)")
eq(pearl.STYLE.fillAlpha, 0.60, "and the fill opacity")
eq(pearl.STYLE.thinRim, true, "and the thin rims")
eq(clean.STYLE.wash, 0.18, "clean itself is unchanged")
eq(clean.STYLE.gloss, 0.25, "clean's gloss unchanged")

-- Precedence: defaults, preset, style, then bodyAlpha.
local tuned = lib:New({ preset = "pearl", style = { wash = 0.3, tint = { 0.2, 0.1, 0.05, 0.9 } }, bodyAlpha = 0.65 })
eq(tuned.STYLE.wash, 0.3, "style beats the preset")
eq(tuned.STYLE.gloss, 0.15, "the preset beats the defaults")
local tg = surface(tuned)
eq(tg.tint._color[4], 0.65, "bodyAlpha last")
eq(tg.tint._color[1], 0.2, "keeping the style's tint colour")
eq(surface(pearl).tint._color[4], 0.24, "pearl's own body: clear 0.24")

------------------------------------------------------------------------------
-- What pearl draws
------------------------------------------------------------------------------
local pg = surface(pearl)
eq(pg.size, "thin", "pearl builds clean's thin geometry")
near(pg.wash._gradient[3].a, 0.10, "the softer wash")
local bar = pearl.Bar(newHost(), 22)
bar:SetStatusBarColor(1, 1, 1)
eq(bar:GetStatusBarTexture()._file, pearl.MEDIA .. "bar_fill", "the rounded fill texture stays")
local fg = bar:GetStatusBarTexture()._gradient
check(fg[2].r == 1 and fg[2].g == 1 and fg[2].b == 1, "priest white stays white: the colour is the caller's")
near(fg[2].a, 0.6, "at the fill opacity")
local frost, gloss
for _, w in ipairs(WoW.widgets) do
    if w._parent == bar and w._sublevel == 2 and w._layer == "BACKGROUND" then frost = w end
    if w._parent == bar.overlay and w._file == pearl.MEDIA .. "gloss" then gloss = w end
end
near(frost._gradient[3].a, 0.06, "the softer frost")
eq(gloss._alpha, 0.15, "the softer gloss")
near(bar.glassState.inner._gradient[2].a, 0.15, "the inner shade kept")
eq(pearl.TUNABLES[1].default, 0.6, "TUNABLES' defaults are the instance's STYLE at New")

-- "classic" draws exactly what New() draws, call for call.
WoW.reset()
local function build(inst)
    local start = #WoW.widgets
    surface(inst, "large"); surface(inst, "small")
    local b = inst.Bar(newHost(), 20); b:SetStatusBarColor(0.2, 0.5, 0.9)
    inst.Disc(newHost(64, 64), "disc_small")
    local out = {}
    for i = start + 1, #WoW.widgets do
        local w, calls = WoW.widgets[i], {}
        for _, c in ipairs(w._log) do
            local args = {}
            for j = 1, c.n do
                local a = c[j]
                args[j] = type(a) == "table" and (a.r and string.format("%s,%s,%s,%s", a.r, a.g, a.b, a.a) or "obj")
                    or tostring(a)
            end
            calls[#calls + 1] = c[1] .. "(" .. table.concat(args, ";") .. ")"
        end
        out[#out + 1] = w._type .. ":" .. table.concat(calls, " ")
    end
    return out
end
local a, b = build(lib:New()), build(lib:New({ preset = "classic" }))
eq(#a, #b, "classic builds as many widgets as New()")
local same = true
for i = 1, #a do if a[i] ~= b[i] then same = false end end
check(same, "classic draws exactly what New() draws")

------------------------------------------------------------------------------
-- Refusals, isolation, disabled and Reflect
------------------------------------------------------------------------------
local count = #lib.instances
local ok, err = pcall(lib.New, lib, { preset = "smoked" })
check(not ok and err:find('use "classic", "clean" or "pearl"', 1, true), "an unknown preset errors with the names")
eq(#lib.instances, count, "before registering anything")

local p2, c2 = lib:New({ preset = "pearl" }), lib:New({ preset = "clean" })
local pb, cb = p2.Bar(newHost(), 20), c2.Bar(newHost(), 20)
pb:SetStatusBarColor(1, 1, 1); cb:SetStatusBarColor(1, 1, 1)
local cGrad = cb:GetStatusBarTexture()._gradient
p2.SetFillAlpha(0.4)
near(pb:GetStatusBarTexture()._gradient[2].a, 0.4, "a pearl instance's setter reaches its bars")
check(cb:GetStatusBarTexture()._gradient == cGrad, "and not a clean instance's")
eq(c2.STYLE.fillAlpha, 0.6, "nor its STYLE")

local off = surface(p2, "large")
p2.SetSurfaceEnabled(off, false)
near(off.wash._gradient[3].a, 0.10 * 0.25, "disabled: pearl's wash dims from its own peak")
p2.SetSurfaceEnabled(off, true)
near(off.wash._gradient[3].a, 0.10, "enabled: pearl's peak back")
local host = newHost(300, 200)
local shell = p2.Apply(host, "large")
local rf = p2.Reflect(shell, host, { header = 60 })
p2.SetSurfaceEnabled(shell, false)
near(rf.rim._gradient[3].a, 0.52 * 0.25, "Reflect on a pearl surface: its lit rim dims")
near(rf.header._gradient[3].a, 0.105 * 0.25, "and its header")
p2.SetSurfaceEnabled(shell, true)
near(rf.rim._gradient[3].a, 0.52, "and comes back")

------------------------------------------------------------------------------
-- Older copies: an upgrade never names an instance's preset, nor restyles it
------------------------------------------------------------------------------
for _, file in ipairs(RELEASES) do
    WoW.reset(); WoW.resetLibStub()
    local oldLib = loadCopy(fixtureCopy(file), "OldHost")
    local hasClean = file ~= "LibGlass-r1.lua" and file ~= "LibGlass-r2.lua" and file ~= "LibGlass-r3.lua"
        and file ~= "LibGlass-r4.lua" and file ~= "LibGlass-r5.lua"
    local oldClassic = oldLib:New({ style = { rimAlpha = 0.5 } })
    local oldClean = hasClean and oldLib:New({ preset = "clean", style = { gloss = 0.4 } }) or nil
    local held = oldClean and oldClean.STYLE.gloss
    local cur = loadLibrary("NewHost")
    eq(rawget(oldClassic, "preset"), nil, file .. ": an older instance's preset is unknown (nil)")
    eq(oldClassic.STYLE.rimAlpha, 0.5, file .. ": its override kept")
    if oldClean then
        eq(rawget(oldClean, "preset"), nil, file .. ": an older clean instance isn't named either")
        eq(oldClean.STYLE.gloss, held, file .. ": its override kept")
        eq(oldClean.STYLE.wash, 0.18, file .. ": and no pearl light")
    end
    local fresh = cur:New({ preset = "pearl" })
    eq(fresh.preset, "pearl", file .. " then r11: New makes pearl")
    loadCopy(fixtureCopy(file), "OlderSecond")
    local after = cur:New({ preset = "pearl" })
    eq(after.preset, "pearl", file .. " loaded after r11: New still makes pearl")
    eq(after.STYLE.wash, 0.10, file .. " loaded after r11: with pearl's light")
    eq(fresh.STYLE.wash, 0.10, file .. " loaded after r11: an instance already made is untouched")
end
done("test_presets")
