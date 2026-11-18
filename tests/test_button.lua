-- The button skin (r13, #46): Glass.Button and its setters. What a consumer
-- relies on: nothing written on the button, nothing mouse-enabled over it,
-- the build refused in combat, the look read through the caller's getters at
-- one secret-safe boundary, the defaults by the instance's material, every
-- step isolated, paint never touching setup, RestyleButton in combat, off
-- letting go and on taking back, the effects, and isolation between
-- instances. GAB's numbers (Buttons.lua and Theme.lua @ eb3afd3) are the
-- expected values.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local lib = loadLibrary("GlassActionBars")
local Pearl = lib:New({ preset = "pearl" })
local Clean = lib:New({ preset = "clean" })
local Classic = lib:New()

-- A button as an addon makes its own: every region by role, and its own art.
local function makeButton(width, ftype, template)
    local b = CreateFrame(ftype or "Button", nil, UIParent, template)
    b:SetSize(width or 36, width or 36)
    local r = {
        icon = b:CreateTexture(), pushed = b:CreateTexture(), highlight = b:CreateTexture(),
        hotkey = b:CreateFontString(), count = b:CreateFontString(), name = b:CreateFontString(),
        fade = { border = b:CreateTexture(), empty = b:CreateTexture() },
    }
    return b, r
end

local function rawKeys(t)
    local keys = {}
    for k in pairs(t) do keys[k] = true end
    return keys
end

local function sameKeys(a, b)
    for k in pairs(a) do if not b[k] then return false, k end end
    for k in pairs(b) do if not a[k] then return false, k end end
    return true
end

-- Run the hooks the skin installed on a button's script (the stub keeps
-- them in w._hooks and never runs them itself).
local function fire(b, script)
    for _, fn in ipairs(b._hooks and b._hooks[script] or {}) do fn(b) end
end

local function near3(c, r, g, b, msg)
    near(c[1], r, msg .. " r"); near(c[2], g, msg .. " g"); near(c[3], b, msg .. " b")
end

--------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------

do
    local b, r = makeButton()
    local before = rawKeys(b)
    local look = {}
    local skin, why = Pearl.Button(b, r, { look = function(k) return look[k] end, maskIcon = true })
    check(skin ~= nil and why == nil, "Button builds a skin")
    local after = rawKeys(b)
    after._hooks = nil   -- the stub's own record of HookScript, not a field the skin wrote
    local ok, extra = sameKeys(before, after)
    check(ok, "nothing is written on the button (" .. tostring(extra) .. ")")
    eq(skin.button, b, "skin.button")
    eq(skin.occupied, true, "a skin starts filled")
    eq(skin.small, true, "36 wide: the small fonts (narrower than 40)")
    check(skin.regions ~= r and skin.regions.icon == r.icon, "skin.regions is a copy of the roles")
    check(skin.regions.fade ~= r.fade and skin.regions.fade.border == r.fade.border, "  and of the fade map")
    r.icon = nil
    check(skin.regions.icon ~= nil, "  the caller's table changing later changes nothing")
    eq(next(skin.failures), nil, "no step failed")

    -- Levels: the body under the button, g.top over it, neither taking the mouse.
    eq(skin.body:GetFrameLevel(), b:GetFrameLevel() - 1, "the body one level under the button")
    eq(skin.g.top:GetFrameLevel(), b:GetFrameLevel() + 1, "g.top one level over it")
    eq(skin.body._mouse, false, "the body's mouse is off")
    check(not skin.g.top._mouse, "g.top never takes the mouse")
    eq(skin.g.shadow._alpha, 0, "no shadow (it would spill onto the next button)")
    eq(skin.g.grain._alpha, 0, "no grain")
    check(skin.g.rim._file:match("button_rim$"), "the rim is button_rim")
    eq(skin.g.size, "thin_small", "a Pearl body is thin_small")

    -- The caller's regions.
    eq(skin.regions.fade.border._alpha, 0, "fade.border faded")
    eq(skin.regions.fade.empty._alpha, 0, "fade.empty faded")
    local p = skin.regions.pushed
    check(p._file:match("button_rim$") and p._blend == "ADD", "the pushed texture is the bright rim, ADD")
    eq(p._alpha, 1, "  at alpha 1 (press flash)")
    eq(skin.regions.highlight._alpha, 0.4, "the highlight softened to 0.4 (hover glow)")
    local hk, ct = skin.regions.hotkey._font, skin.regions.count._font
    eq(hk[2], 10 + lib.FONTS.arial.bump, "hotkey 10 + bump on a small button")
    eq(hk[3], "OUTLINE", "  outlined")
    eq(ct[2], 11 + lib.FONTS.arial.bump, "count 11 + bump")
    eq(skin.regions.hotkey._alpha, 1, "hotkey shown")
    eq(skin.regions.name._alpha, 1, "name shown")
    check(skin.regions.icon._masks and #skin.regions.icon._masks == 1, "maskIcon: the icon rounded")

    -- Pearl's face, at its defaults: rim 0.70, dark 0.20, gloss 0.08 on a filled slot.
    check(skin.gloss and skin.socketRim and skin.socketShade, "Pearl's face built on a Pearl instance")
    near(skin.g.rim._alpha, 0.70, "Pearl rim")
    near(skin.g.dark._alpha, 0.20, "Pearl dark line")
    near(skin.gloss._alpha, 0.08, "Pearl gloss on a filled slot")
    eq(skin.socketRim._alpha, 0, "no socket on a filled slot")
    eq(skin.gloss._layer, "ARTWORK", "gloss at ARTWORK")
    eq(skin.gloss._sublevel, 0, "  sublevel 0")
    eq(skin.halo._layer, "ARTWORK", "halo at ARTWORK")
    eq(skin.halo._sublevel, 7, "  sublevel 7")
    eq(skin.socketShade._sublevel, 4, "socket shade at OVERLAY 4")
    eq(skin.socketRim._sublevel, 6, "socket rim at OVERLAY 6")

    -- A second call: the same handle.
    eq(Pearl.Button(b, r), skin, "a second call returns the same skin")
    eq(Pearl.ButtonSkin(b), skin, "ButtonSkin finds it")
    eq(Clean.ButtonSkin(b), nil, "  not from another instance")
    local other, whyOther = Clean.Button(b, {})
    check(other == nil and whyOther == "skinned", "another instance gets nil, \"skinned\"")
end

-- The material's defaults: Clean and Classic share GAB's TUNE, Pearl its own.
do
    eq(Classic.ButtonDefault("rim"), 0.85, "Classic rim 0.85")
    eq(Clean.ButtonDefault("rim"), 0.85, "Clean rim 0.85")
    eq(Pearl.ButtonDefault("rim"), 0.70, "Pearl rim 0.70")
    eq(Pearl.ButtonDefault("empty"), 0.75, "Pearl empty falls back to TUNE's 0.75")
    eq(Classic.ButtonDefault("gloss"), 0, "no gloss off Pearl")
    eq(Classic.ButtonDefault("bogus"), nil, "an unknown key: nil")
    local b, r = makeButton(45)
    local skin = Classic.Button(b, r)
    eq(skin.gloss, nil, "no Pearl face on Classic")
    eq(skin.small, false, "45 wide: the large fonts")
    eq(skin.regions.hotkey._font[2], 12 + lib.FONTS.arial.bump, "hotkey 12 + bump")
    eq(skin.regions.count._font[2], 14 + lib.FONTS.arial.bump, "count 14 + bump")
    near(skin.g.rim._alpha, 0.85, "Classic rim")
    near(skin.g.dark._alpha, 0.15, "Classic dark")
    eq(skin.g.size, "small", "a Classic body is small")
    -- The body at GAB's numbers: tint alpha built * body 0.25, wash STYLE.wash * 0.04.
    local built = skin.g.tint.glassColor
    near(skin.g.tint._color[4], built[4] * 0.25, "the body's tint alpha: built x 0.25")
    near(skin.g.wash.glassPeak, Classic.STYLE.wash * 0.04, "the wash: STYLE.wash x 0.04")
    local list = lib.BUTTON.TUNE_ORDER
    eq(#list, 10, "BUTTON.TUNE_ORDER has the ten tune keys")
    for _, k in ipairs(list) do check(type(Classic.ButtonDefault(k)) == "number", "a default for " .. k) end
    eq(Classic.BUTTON, lib.BUTTON, "BUTTON reads through the instance")
end

--------------------------------------------------------------------------------
-- Arguments and combat
--------------------------------------------------------------------------------

do
    local b, r = makeButton()
    check(not pcall(Classic.Button, CreateFrame("Frame")), "a Frame is refused (throws)")
    check(not pcall(Classic.Button, b, { bogus = r.icon }), "an unknown role throws")
    check(not pcall(Classic.Button, b, { icon = r.hotkey }), "a FontString as the icon throws")
    check(not pcall(Classic.Button, b, { fade = { x = 5 } }), "a fade entry that isn't a region throws")
    check(not pcall(Classic.Button, b, nil, { look = "glow" }), "a look that isn't a function throws")
    check(not pcall(Classic.Button, b, nil, { inset = 99 }), "an inset out of range throws")
    eq(Classic.ButtonSkin(b), nil, "  nothing built by a refused call")

    WoW.combat = true
    local frames = #WoW.frames
    local skin, why = Classic.Button(b, r)
    check(skin == nil and why == "combat", "in combat: nil, \"combat\"")
    eq(#WoW.frames, frames, "  nothing built")
    WoW.combat = false
    check(Classic.Button(b, r) ~= nil, "out of combat: built")

    -- A CheckButton is a Button (the action buttons are).
    local cb, cr = makeButton(36, "CheckButton")
    check(Classic.Button(cb, cr) ~= nil, "a CheckButton is a Button")

    -- inset: the body that far inside the button.
    local ib = makeButton(32)
    local iskin = Classic.Button(ib, {}, { inset = 3 })
    local pt = iskin.body._points[1]
    eq(pt[4], 3, "inset: TOPLEFT x")
    eq(pt[5], -3, "inset: TOPLEFT y")
end

--------------------------------------------------------------------------------
-- The look: getters, secrets, the frosted fill
--------------------------------------------------------------------------------

do
    local b, r = makeButton()
    local look, tune = {}, {}
    local errors = {}
    local skin = Classic.Button(b, r, { look = function(k) return look[k] end, tune = function(k) return tune[k] end,
                                        onError = function(step, msg) errors[#errors + 1] = step end })

    -- Frosted empty slot on as-built glass: the cool grey at frostAlpha, the rim at empty x frostRim.
    Classic.SetButtonEmpty(skin, true)
    eq(skin.occupied, false, "SetButtonEmpty(true): empty")
    near3(skin.g.tint._color, 0.9, 0.91, 0.94, "frost: the cool grey")
    near(skin.g.tint._color[4], 0.08, "frost alpha 0.08, unscaled")
    near(skin.g.rim._alpha, 0.85 * 0.75 * 0.35, "rim: rim x empty x frostRim")
    near(skin.g.wash.glassPeak, Classic.STYLE.wash * 0.04, "frost: the wash unscaled by the factor")

    -- A tint (smoked): the empty slot keeps it, fainter, never frosted.
    look.tint = { 0.05, 0.06, 0.08, 0.62 }
    look.tintWash = 0.14 / 0.18
    Classic.RefreshButton(skin)
    near3(skin.g.tint._color, 0.05, 0.06, 0.08, "a tinted empty slot keeps its tint")
    near(skin.g.tint._color[4], 0.62 * 0.25 * 0.35, "  at tint x body x frostRim")
    near(skin.g.wash.glassPeak, Classic.STYLE.wash * (0.14 / 0.18) * 0.04 * 0.35, "  the wash x tintWash x factor")

    -- Other empty looks.
    look.tint, look.tintWash = nil, nil
    look.emptySlots = "half"
    Classic.RefreshButton(skin)
    near(skin.g.rim._alpha, 0.85 * 0.75 * 0.5, "half: rim x empty x 0.5")
    look.emptySlots = "hidden"
    Classic.RefreshButton(skin)
    eq(skin.g.tint._shown, false, "hidden: the tint hidden at alpha 0")
    look.emptySlots = nil

    -- Tune overrides win on every material; junk falls back.
    tune.rim = 0.5
    Classic.SetButtonEmpty(skin, false)
    near(skin.g.rim._alpha, 0.5, "a tune override")
    tune.rim = 2
    Classic.RefreshButton(skin)
    near(skin.g.rim._alpha, 0.85, "an out-of-range tune: the default")
    tune.rim = WoW.Secret("tune")
    Classic.RefreshButton(skin)
    near(skin.g.rim._alpha, 0.85, "a secret tune: the default")
    -- A secret that keeps its type (a number, as on the client): only the
    -- secret check stops it. An unusual value, so marking it touches nothing else.
    tune.rim = WoW.MarkSecret(0.4321, "tune number")
    Classic.RefreshButton(skin)
    near(skin.g.rim._alpha, 0.85, "a secret number tune: the default")
    WoW.secrets[0.4321] = nil
    tune.rim = nil

    -- Junk and secrets from the look getter: the defaults, nothing thrown.
    look.hover = "sparkle"
    Classic.RefreshButton(skin)
    eq(skin.regions.highlight._alpha, 0.4, "an unknown hover value: glow")
    look.hover = WoW.Secret("hover")
    Classic.RefreshButton(skin)
    eq(skin.regions.highlight._alpha, 0.4, "a secret hover: glow")
    look.hover = nil
    look.tint = { 0.2, WoW.MarkSecret(0.6543, "tint g"), 0.4 }
    Classic.RefreshButton(skin)
    near3(skin.g.tint._color, skin.g.tint.glassColor[1], skin.g.tint.glassColor[2], skin.g.tint.glassColor[3],
          "a tint holding a secret: as built")
    WoW.secrets[0.6543] = nil
    look.tint = WoW.Secret("tint")
    Classic.RefreshButton(skin)
    near3(skin.g.tint._color, skin.g.tint.glassColor[1], skin.g.tint.glassColor[2], skin.g.tint.glassColor[3],
          "a secret tint: as built")
    look.tint = { 0.2, 0.3, 2 }
    check(lib._test.normLook("tint", look.tint) == nil, "a tint out of range: as built")
    look.tint = nil
    look.showHotkey = WoW.Secret("show")
    Classic.RefreshButton(skin)
    eq(skin.regions.hotkey._alpha, 1, "a secret showHotkey: shown")
    look.showHotkey = false
    look.showName = false
    Classic.RefreshButton(skin)
    eq(skin.regions.hotkey._alpha, 0, "showHotkey false: hidden")
    eq(skin.regions.name._alpha, 0, "showName false: hidden")
    look.showHotkey, look.showName = nil, nil

    -- SetButtonEmpty takes only a plain boolean.
    check(not Classic.SetButtonEmpty(skin, WoW.Secret("empty")), "a secret empty state: refused")
    check(not Classic.SetButtonEmpty(skin, nil), "nil: refused")
    eq(skin.occupied, true, "  the last state kept")
    eq(#errors, 0, "no step failed on junk or secrets")

    -- A getter that throws: the default, reported once under "look".
    local b2, r2 = makeButton()
    local reported = {}
    local s2 = Classic.Button(b2, r2, { look = function() error("look broke") end,
                                        onError = function(step, msg) reported[#reported + 1] = step .. "|" .. msg end })
    eq(s2.regions.highlight._alpha, 0.4, "a throwing getter: the defaults")
    check(s2.failures.look and s2.failures.look:find("look broke"), "  recorded under look")
    eq(#reported, 1, "  reported once")
end

--------------------------------------------------------------------------------
-- Each step isolated
--------------------------------------------------------------------------------

do
    local b, r = makeButton()
    rawset(r.fade.border, "SetAlpha", function() error("refused art") end)
    local skin = Classic.Button(b, r)
    check(skin.failures["fade:border"] and skin.failures["fade:border"]:find("refused art"), "a refused fade is recorded")
    eq(r.fade.empty._alpha, 0, "  the other fade still done")
    near(skin.g.rim._alpha, 0.85, "  the rim still painted")
    check(skin.g.tint._color ~= nil, "  the body still painted")
    eq(skin.regions.pushed._blend, "ADD", "  the pushed rim still set")
    check(skin.halo ~= nil, "  the halo still built")
end

--------------------------------------------------------------------------------
-- Paint is not setup; RestyleButton runs in combat
--------------------------------------------------------------------------------

do
    local b, r = makeButton(36, "Button", "SecureActionButtonTemplate")
    local skin = Classic.Button(b, r)
    local SETUP = { SetTexture = true, ClearAllPoints = true, SetAllPoints = true, SetPoint = true,
                    SetBlendMode = true, SetVertexColor = true, AddMaskTexture = true, SetTextureSliceMargins = true }
    local calls = {}
    local regions = { r.pushed, r.highlight, r.hotkey, r.count, r.name, r.fade.border, r.fade.empty, r.icon }
    for _, region in ipairs(regions) do
        for name in pairs(SETUP) do
            local orig = region[name]
            rawset(region, name, function(...) calls[#calls + 1] = name; return orig(...) end)
        end
    end
    WoW.combat = true
    Classic.RefreshButton(skin)
    Classic.RefreshButtons()
    Classic.SetButtonEmpty(skin, true)
    Classic.SetButtonEmpty(skin, false)
    eq(#calls, 0, "paint never calls a setup method on the caller's regions, in combat")
    local blocked = #WoW.blocked
    check(Classic.RestyleButton(skin), "RestyleButton runs in combat")
    eq(#WoW.blocked, blocked, "  nothing blocked on a secure button")
    check(#calls > 0, "  and does the setup again")
    eq(next(skin.failures), nil, "  no step failed")
    WoW.combat = false
    for _, region in ipairs(regions) do for name in pairs(SETUP) do rawset(region, name, nil) end end
end

-- RestyleButton reads the size again.
do
    local b, r = makeButton(45)
    local skin = Classic.Button(b, r)
    eq(skin.small, false, "45: large")
    b:SetSize(30, 30)
    Classic.RestyleButton(skin)
    eq(skin.small, true, "resized to 30 and restyled: small")
    eq(skin.regions.hotkey._font[2], 10 + lib.FONTS.arial.bump, "  the hotkey's small size")
    b._width = WoW.Secret("width")
    Classic.RestyleButton(skin)
    eq(skin.small, false, "a secret width: read as 45")
end

--------------------------------------------------------------------------------
-- The effects: the halo, the ripple, the driver
--------------------------------------------------------------------------------

do
    local b, r = makeButton()
    local look = { hover = "halo", press = "ripple" }
    local skin = Classic.Button(b, r, { look = function(k) return look[k] end })
    eq(skin.regions.highlight._alpha, 0, "hover halo: the highlight off")
    fire(b, "OnEnter")
    check(lib.buttonFx.fading[skin] == 1, "OnEnter: the halo fades in")
    check(lib.buttonDriver and lib.buttonDriver._scripts.OnUpdate, "  the driver runs")
    WoW.tick(0.05)
    near(skin.halo._alpha, 0.5, "  half way after 0.05 s (in over 0.1 s)")
    WoW.tick(0.06)
    eq(skin.halo._alpha, 1, "  full after 0.1 s")
    eq(lib.buttonDriver._scripts.OnUpdate, nil, "  the driver stops when nothing moves")
    fire(b, "OnLeave")
    WoW.tick(0.2)
    eq(skin.halo._alpha, 0, "OnLeave: faded out")

    WoW.cursorX, WoW.cursorY = 236, 236
    skin.body._escale, skin.body._left, skin.body._bottom = 2, 100, 100
    skin.body._width = 36
    fire(b, "OnMouseDown")
    check(skin.ripple and skin.ripple._shown, "OnMouseDown: a ripple")
    eq(skin.ripple._width, 36 * 0.3, "  from 0.3 of the width")
    local pt = skin.ripple._points[1]
    check(pt[1] == "CENTER" and pt[2] == skin.body and pt[3] == "BOTTOMLEFT", "  centred on the pointer")
    eq(pt[4], 18, "  x: cursor over the effective scale, from the body's left")
    eq(pt[5], 18, "  y: from its bottom")
    for _ = 1, 20 do WoW.tick(0.02) end
    eq(skin.ripple._shown, false, "  gone after 0.3 s")
    eq(lib.buttonDriver._scripts.OnUpdate, nil, "  the driver stopped")

    -- Secret reads: the ripple from the centre, a 36 px base.
    skin.body._width = WoW.Secret("w")
    WoW.cursorX = WoW.Secret("x")
    fire(b, "OnMouseDown")
    eq(skin.ripple._width, 36 * 0.3, "secret width: a 36 px base")
    eq(skin.ripple._points[1][3], "CENTER", "secret cursor: from the centre")
    eq(next(skin.failures), nil, "no step failed on secret reads")
    skin.body._width, WoW.cursorX = 36, nil
    fire(b, "OnHide")
    eq(lib.buttonFx.rippling[skin], nil, "OnHide: the effects cleared")

    -- The look changes: the halo off stops it, the ripple off hides it.
    fire(b, "OnEnter")
    look.hover, look.press = "glow", "flash"
    Classic.RefreshButton(skin)
    eq(lib.buttonFx.fading[skin], nil, "hover glow: the halo stopped")
    eq(skin.halo._alpha, 0, "  and cleared")
    eq(skin.regions.highlight._alpha, 0.4, "  the highlight back to 0.4")
    look.press = "off"
    Classic.RefreshButton(skin)
    eq(skin.regions.pushed._alpha, 0, "press off: the pushed rim at 0")
end

--------------------------------------------------------------------------------
-- Off and on
--------------------------------------------------------------------------------

do
    local b, r = makeButton()
    local look = { hover = "halo" }
    local skin = Pearl.Button(b, r, { look = function(k) return look[k] end, maskIcon = true })
    local mask = skin.iconMask
    for cycle = 1, 2 do
        check(Pearl.SetButtonShown(skin, false), "off (" .. cycle .. ")")
        eq(skin.body._shown, false, "  our frames hidden")
        for _, key in ipairs({ "highlight", "pushed", "hotkey", "name" }) do
            eq(skin.regions[key]._alpha, 1, "  " .. key .. " alpha back to 1")
        end
        eq(r.fade.border._alpha, 1, "  the fade back to 1")
        r.highlight:SetAlpha(0.77)
        Pearl.RefreshButtons()
        Pearl.RestyleButton(skin)
        Pearl.SetButtonEmpty(skin, true)
        fire(b, "OnEnter")
        eq(r.highlight._alpha, 0.77, "  while off: refresh, restyle and empty write nothing")
        eq(lib.buttonFx.fading[skin], nil, "  while off: the hooks do nothing")
        eq(skin.occupied, false, "  the empty state still recorded")
        Pearl.SetButtonEmpty(skin, false)
        check(Pearl.SetButtonShown(skin, true), "on (" .. cycle .. ")")
        eq(skin.body._shown, true, "  our frames shown")
        eq(skin.iconMask, mask, "  the same mask object")
        eq(r.fade.border._alpha, 0, "  the fade again")
        eq(r.highlight._alpha, 0, "  the highlight's look again (hover halo)")
        near(skin.g.rim._alpha, 0.70, "  the rim painted")
    end
    local attached = 0
    for _, m in ipairs(r.icon._masks or {}) do if m == mask then attached = attached + 1 end end
    eq(attached, 1, "after two cycles the mask is attached once")
    Pearl.SetButtonShown(skin, false)
    eq(#(r.icon._masks or {}), 0, "off: the mask removed")
    Pearl.SetButtonShown(skin, true)
end

--------------------------------------------------------------------------------
-- Isolation
--------------------------------------------------------------------------------

do
    local A, B = lib:New(), lib:New()
    local ba, ra = makeButton()
    local bb, rb = makeButton()
    local lookA, lookB = {}, {}
    local sa = A.Button(ba, ra, { look = function(k) return lookA[k] end })
    local sb = B.Button(bb, rb, { look = function(k) return lookB[k] end })
    lookA.press, lookB.press = "off", "off"
    A.RefreshButtons()
    eq(sa.regions.pushed._alpha, 0, "RefreshButtons repaints its own instance's skins")
    eq(sb.regions.pushed._alpha, 1, "  never another's")
    check(not A.RefreshButton(sb), "RefreshButton refuses another instance's skin")
    check(not A.SetButtonEmpty(sb, true), "SetButtonEmpty refuses it")
    check(not A.SetButtonShown(sb, false), "SetButtonShown refuses it")
    check(not A.RestyleButton(sb), "RestyleButton refuses it")
    -- SetRimAlpha leaves the skins' rims alone (the skin paints them).
    A.SetRimAlpha(0.3)
    near(sa.g.rim._alpha, 0.85, "SetRimAlpha leaves a skin's rim alone")
end

done("test_button")
