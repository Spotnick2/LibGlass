-- wow_stubs.lua: LibGlass's part of the WoW: Forever mock for Lua 5.1 unit
-- tests. dofile("tests/wow_stubs.lua") FIRST in every test; drive it via the
-- WoW table.
--
-- The mechanics are WowTestKit's core (tests/kit.lua loads it at the commit
-- and build tests/kit.pin names; its README is the reference): strict
-- globals, secrets (WoW.Secret, issecretvalue), CreateFrame and the widget
-- method recorder (WoW.methodsCalled, checked by Kit.checkMethods), events
-- checked against the build, OnShow / OnHide, OnUpdate ticks, timers,
-- hooksecurefunc, print, combat lockdown. This file adds only what the
-- library, its probe and its tests use beyond them.
dofile("tests/kit.lua")
local Methods = WoW.Methods

--------------------------------------------------------------------------------
-- WowTestKit #67: the per-widget call log the core lacks. WoW.widgets is
-- every widget the tests made (frames and regions), in creation order, and
-- each one's w._log the methods called on it, in order, with their arguments
-- ({ name, n = argc, ... }), so test_parity.lua can compare everything the
-- library draws with GlassUnitFrames' Glass.lua v3, and the upgrade and
-- isolation tests can prove that nothing was repainted. A hooksecurefunc on
-- a widget is logged too ("hooksecurefunc:<name>"), so the parity test
-- compares the hooks installed.
--------------------------------------------------------------------------------

-- Each widget type's method table (the core's, the __index of the type's
-- metatable) hands out logging wrappers of its methods: the build's ones are
-- wrapped once and kept in the table, as the core keeps them, so every read
-- still gives the same function.
local function logging(name, fn)
    return function(self, ...)
        local log = type(self) == "table" and rawget(self, "_log")
        if log then table.insert(log, { name, n = select("#", ...), ... }) end
        return fn(self, ...)
    end
end
local patched = {}
local function patchType(wtype)
    if patched[wtype] then return end
    patched[wtype] = true
    local methods = getmetatable(WoW.newWidget(wtype)).__index
    for k, fn in pairs(methods) do rawset(methods, k, logging(k, fn)) end
    local mt = getmetatable(methods)
    local lookup = mt.__index
    mt.__index = function(tbl, k)
        local fn = lookup(tbl, k)
        if type(fn) ~= "function" then return fn end
        local wrapped = logging(k, fn)
        if rawget(tbl, k) == fn then rawset(tbl, k, wrapped) end
        return wrapped
    end
end

local function track(w)
    patchType(w._type)
    rawset(w, "_log", {})
    table.insert(WoW.widgets, w)
    return w
end

WoW.widgets = {}
table.insert(WoW.onReset, function() WoW.widgets = {} end)

local coreCreateFrame = CreateFrame
function CreateFrame(...) return track(coreCreateFrame(...)) end
for _, name in ipairs({ "CreateTexture", "CreateFontString", "CreateMaskTexture",
                        "CreateAnimationGroup", "CreateAnimation" }) do
    local core = Methods[name]
    Methods[name] = function(w, ...) return track(core(w, ...)) end
end
local coreSetStatusBarTexture = Methods.SetStatusBarTexture
function Methods.SetStatusBarTexture(b, ...)
    local had = b._fill
    local r = coreSetStatusBarTexture(b, ...)
    if b._fill and b._fill ~= had then track(b._fill) end
    return r
end

local coreHook = hooksecurefunc
function hooksecurefunc(t, name, fn)
    if type(t) == "table" and rawget(t, "_log") then table.insert(t._log, { "hooksecurefunc:" .. name, n = 0 }) end
    return coreHook(t, name, fn)
end

--------------------------------------------------------------------------------
-- The tests' own helpers
--------------------------------------------------------------------------------

function WoW.IsSecret(v) return issecretvalue(v) end

-- A fresh client: no LibStub, so the next load starts the library from scratch.
function WoW.resetLibStub()
    rawset(_G, "LibStub", nil)
end

--------------------------------------------------------------------------------
-- Widget methods that differ from the core's, each because a test relies on it
--------------------------------------------------------------------------------

-- w._alpha records every SetAlpha the library asked for, on a gradient
-- texture too, and SetGradient keeps it: the tests read it as that record
-- ("the wash's region alpha left alone", "A: SetAlpha before its gradient",
-- the alphas an upgrade gives back). What the client draws is modelled where
-- it reads back: GetAlpha reads 1 on a gradient texture (measured on 70374,
-- #47, #53). The core models it in _alpha itself instead (SetAlpha ignored on
-- a gradient, SetGradient drops it), which those checks can't read.
function Methods.SetAlpha(w, a) w._alpha = a end
function Methods.GetAlpha(w) if w._gradient then return 1 end return w._alpha or 1 end
local coreSetGradient = Methods.SetGradient
function Methods.SetGradient(t, ...)
    local asked = t._alpha
    coreSetGradient(t, ...)
    t._alpha = asked
end

--------------------------------------------------------------------------------
-- Widget methods beyond the core's, each read by a test
--------------------------------------------------------------------------------

function Methods.SetTexCoord(t, ...) t._texCoord = { ... } end
function Methods.SetClipsChildren(w, v) w._clips = v end
function Methods.SetTextureSliceMargins(t, l, tp, r, b) t._slice = { l, tp, r, b } end

-- StatusBar: takes values (secret or not) without inspecting them, and keeps
-- the interpolation each call asked for (test_material's easing checks).
function Methods.SetMinMaxValues(b, lo, hi, interp) b._min, b._max, b._minMaxInterp = lo, hi, interp end
function Methods.GetMinMaxValues(b) return b._min, b._max end
local coreSetValue = Methods.SetValue
function Methods.SetValue(b, v, interp)
    coreSetValue(b, v)
    b._interp = interp
end

-- Button: its highlight texture (Glass.Pill softens it).
function Methods.SetHighlightTexture(b, file, blend)
    b._highlight = b._highlight or track(WoW.newWidget("Texture", b))
    b._highlight._file, b._highlight._blend = file, blend
end
function Methods.GetHighlightTexture(b) return b._highlight end

-- WowTestKit #68: methods on 70959 the core doesn't implement, which the
-- button skin (r13, #46) reads: role checks (IsObjectType, the client's
-- hierarchy as far as asked), the ripple's place (GetEffectiveScale,
-- GetLeft, GetBottom: _escale, _left, _bottom, nil when unset, as the core's
-- secure handles read them), the hover under a still pointer (IsMouseOver:
-- _mouseOver) and letting go of the icon's mask (RemoveMaskTexture). A test
-- may put a secret in any of the fields. GlassActionBars' stub has the same.
local KIND_OF = { CheckButton = "Button", Button = "Frame", Cooldown = "Frame", StatusBar = "Frame" }
function Methods.IsObjectType(w, t)
    local k = w._type
    while k do
        if k == t then return true end
        k = KIND_OF[k]
    end
    return false
end
function Methods.GetEffectiveScale(w) return w._escale end
function Methods.GetLeft(w) return w._left end
function Methods.GetBottom(w) return w._bottom end
function Methods.IsMouseOver(w) return w._mouseOver == true end
function Methods.RemoveMaskTexture(t, m)
    for i, x in ipairs(t._masks or {}) do
        if x == m then table.remove(t._masks, i); return end
    end
end

-- HookScript keeps each hook in w._hooks[script], and never runs it: the
-- track-length test (test_material) counts the bar's OnSizeChanged hooks
-- ("never hooked twice") and calls the one it finds, and the stub has no
-- OnSizeChanged to fire. The core's chains the hook into the script.
function Methods.HookScript(w, name, fn)
    w._hooks = w._hooks or {}
    w._hooks[name] = w._hooks[name] or {}
    table.insert(w._hooks[name], fn)
end

--------------------------------------------------------------------------------
-- Globals (each in the API dump)
--------------------------------------------------------------------------------

Enum = {
    UITextureSliceMode = { Stretched = 0, Tiled = 1 },
}
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end

-- Strict globals, last: any read of an undefined global is an error, except
-- the globals that are legitimately nil before first assignment: LibStub (the
-- bundled file checks for an earlier copy), GlassUF (the frozen v3 file) and
-- LibGlassProbeDB (the probe's SavedVariables, nil on a first load).
Kit.strict({ LibStub = true, GlassUF = true, LibGlassProbeDB = true })
