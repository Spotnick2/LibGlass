-- wow_stubs.lua: a minimal WoW: Forever mock for Lua 5.1 unit tests, trimmed
-- from GlassUnitFrames' to what the material uses.
-- dofile("tests/wow_stubs.lua") FIRST in every test; drive it via the WoW table.
--
-- What it models, on purpose:
-- - STRICT globals: reading any global it does not define is an error. The
--   stub is the allowlist of APIs verified present in the API dump; defining
--   something Forever lacks is how a missing API survives into a build.
-- - SECRETS as newproxy userdata: arithmetic, ordering, tostring, concat and
--   string.format on one throw. Lua 5.1 cannot make a truth test or == throw,
--   so those two misuses are NOT caught here (only in game / in review).
-- - METHOD calls: every widget method called is recorded (WoW.methodsCalled)
--   so test_methods.lua can check each against the dump's widget methods, and
--   logged per widget with its arguments (w._log) so test_parity.lua can
--   compare everything the library draws with GlassUnitFrames' Glass.lua v3.

WoW = {}
WoW.DUMP = os.getenv("LIBGLASS_API_DUMP") or "C:/Projects/References/forever-api-1.60.1.70205.md"

--------------------------------------------------------------------------------
-- Secrets
--------------------------------------------------------------------------------

local secrets = setmetatable({}, { __mode = "k" })

function WoW.Secret(label)
    local p = newproxy(true)
    local mt = getmetatable(p)
    local function boom() error("secret value touched in Lua: " .. label, 2) end
    for _, k in ipairs({ "__tostring", "__concat", "__add", "__sub", "__mul", "__div", "__mod",
                         "__pow", "__unm", "__lt", "__le", "__len", "__index", "__newindex", "__call" }) do
        mt[k] = boom
    end
    secrets[p] = label
    return p
end

function WoW.IsSecret(v) return secrets[v] ~= nil end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function WoW.reset()
    WoW.frames = {}
    WoW.widgets = {}          -- every widget, in creation order (frames and regions)
    WoW.methodsCalled = {}
end

-- A fresh client: no LibStub, so the next load starts the library from scratch.
function WoW.resetLibStub()
    rawset(_G, "LibStub", nil)
end

--------------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------------

local Methods = {}   -- shared implementations, by method name

local widgetMT = {
    __index = function(w, k)
        if type(k) ~= "string" or not k:match("^%u") then return nil end  -- fields read as nil
        return function(self, ...)
            WoW.methodsCalled[self._type .. ":" .. k] = true
            table.insert(self._log, { k, n = select("#", ...), ... })
            local impl = Methods[k]
            if impl then return impl(self, ...) end
            return nil
        end
    end,
}

local function newWidget(wtype, parent, name)
    local w = setmetatable({ _type = wtype, _parent = parent, _shown = true, _points = {}, _log = {},
                             _level = parent and parent._level and (parent._level + 1) or 1,
                             _width = 0, _height = 0, _name = name }, widgetMT)
    table.insert(WoW.widgets, w)
    return w
end

function CreateFrame(ftype, name, parent, template)
    local w = newWidget(ftype, parent, name)
    w._template = template
    if ftype == "StatusBar" then w._min, w._max, w._value = 0, 1, 0 end
    table.insert(WoW.frames, w)
    if name then rawset(_G, name, w) end
    return w
end

function Methods.Show(w) w._shown = true end
function Methods.Hide(w) w._shown = false end
function Methods.SetShown(w, v) w._shown = v and true or false end
function Methods.IsShown(w) return w._shown end
function Methods.SetPoint(w, ...) table.insert(w._points, { ... }) end
function Methods.ClearAllPoints(w) w._points = {} end
function Methods.SetAllPoints(w, rel) table.insert(w._points, { "ALL", rel }) end
function Methods.SetSize(w, x, y) w._width, w._height = x, y end
function Methods.SetWidth(w, x) w._width = x end
function Methods.SetHeight(w, y) w._height = y end
function Methods.GetWidth(w) return w._width end
function Methods.GetHeight(w) return w._height end
function Methods.GetFrameLevel(w) return w._level end
function Methods.SetFrameLevel(w, l) w._level = l end
function Methods.GetParent(w) return w._parent end
function Methods.GetObjectType(w) return w._type end
function Methods.SetClipsChildren(w, v) w._clips = v end

-- Regions. Draw layer and sublevel are kept, as the client draws by them.
function Methods.CreateTexture(w, name, layer, template, sublevel)
    local t = newWidget("Texture", w, name)
    t._layer, t._sublevel = layer, sublevel
    return t
end
function Methods.CreateMaskTexture(w, name, layer) return newWidget("MaskTexture", w, name) end
function Methods.CreateFontString(w, name, layer, template, sublevel)
    local t = newWidget("FontString", w, name)
    t._layer, t._sublevel = layer, sublevel
    return t
end
function Methods.CreateAnimationGroup(w)
    local ag = newWidget("AnimationGroup", w)
    ag._plays = 0
    return ag
end
function Methods.CreateAnimation(ag, atype) return newWidget(atype or "Animation", ag) end
function Methods.Play(ag) ag._plays = (ag._plays or 0) + 1 end
function Methods.Stop(ag) ag._stops = (ag._stops or 0) + 1 end
function Methods.SetTexture(t, file) t._file = file; return true end
function Methods.SetAlpha(w, a) w._alpha = a end
function Methods.GetAlpha(w) return w._alpha or 1 end
function Methods.SetVertexColor(t, r, g, b, a) t._vertex = { r, g, b, a } end
function Methods.SetColorTexture(t, r, g, b, a) t._color = { r, g, b, a } end
function Methods.AddMaskTexture(t, m) t._masks = t._masks or {}; table.insert(t._masks, m) end
function Methods.SetGradient(t, orientation, c1, c2)
    assert(type(c1) == "table" and type(c2) == "table", "SetGradient takes color objects on this API")
    t._gradient = { orientation, c1, c2 }
end
function Methods.SetTextureSliceMargins(t, l, tp, r, b) t._slice = { l, tp, r, b } end
function Methods.SetBlendMode(t, mode) t._blend = mode end
function Methods.SetFont(fs, file, size, flags) fs._font = { file, size, flags }; return true end
function Methods.GetFont(fs) if fs._font then return fs._font[1], fs._font[2], fs._font[3] end end

-- StatusBar: takes values (secret or not) without inspecting them.
function Methods.SetMinMaxValues(b, lo, hi, interp) b._min, b._max, b._minMaxInterp = lo, hi, interp end
function Methods.GetMinMaxValues(b) return b._min, b._max end
function Methods.SetValue(b, v, interp) b._value = v; b._interp = interp end
function Methods.GetValue(b) return b._value end
function Methods.SetStatusBarTexture(b, file)
    b._fill = b._fill or newWidget("Texture", b)
    b._fill._file = file
    return true
end
function Methods.GetStatusBarTexture(b) return b._fill end
function Methods.SetStatusBarColor(b, r, g, bl, a) b._color = { r, g, bl, a } end

-- Button: its highlight texture (Glass.Pill softens it).
function Methods.SetHighlightTexture(b, file, blend)
    b._highlight = b._highlight or newWidget("Texture", b)
    b._highlight._file, b._highlight._blend = file, blend
end
function Methods.GetHighlightTexture(b) return b._highlight end

--------------------------------------------------------------------------------
-- Globals
--------------------------------------------------------------------------------

WoW.reset()
UIParent = newWidget("Frame", nil, "UIParent")   -- not in WoW.widgets: reset() clears it
UIParent._level = 0

Enum = {
    UITextureSliceMode = { Stretched = 0, Tiled = 1 },
}
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
strmatch = string.match   -- LibStub uses it

-- Post-hook a method, as the client does: the original runs first. Logged on
-- the widget, so the parity test compares the hooks installed too.
function hooksecurefunc(t, name, fn)
    local orig = t[name]
    if t._log then table.insert(t._log, { "hooksecurefunc:" .. name, n = 0 }) end
    rawset(t, name, function(self, ...)
        local r = orig(self, ...)
        fn(self, ...)
        return r
    end)
end

WoW.reset()   -- the tests' widgets only

-- Strict globals: any read of an undefined global is an error, except the
-- globals that are legitimately nil before first assignment: LibStub (the
-- bundled file checks for an earlier copy) and GlassUF (the frozen v3 file).
local allowNil = { LibStub = true, GlassUF = true }
setmetatable(_G, { __index = function(_, k)
    if allowNil[k] then return nil end
    error("read of undefined global '" .. tostring(k) .. "' (not stubbed: is it in the API dump?)", 2)
end })
