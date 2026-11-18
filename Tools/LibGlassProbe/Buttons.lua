-- Buttons.lua: the button skin's procedure (r13, #46), on LibGlassProbe's
-- helpers (NS, from LibGlassProbe.lua).
--
-- button: Glass.Button on probe-made buttons, one column per material
--   (Classic, Clean, Pearl), a filled and an empty button in each, with a
--   cooldown sweep on the filled ones (the rim sits over it, by choice). The
--   look is the probe's own getter, so each step can change it live: the halo
--   and the ripple, a smoked tint (empty slots keep it instead of frosting),
--   the skin off and back on, a resize. Last, a SecureActionButtonTemplate
--   button (it targets you) restyled and clicked in combat: the host logs any
--   ADDON_ACTION_BLOCKED or FORBIDDEN in the same console.
--                                            /fp steps lg button walks it

local _, NS = ...
local Probe, say, board, report, minor, winner = NS.Probe, NS.say, NS.board, NS.report, NS.minor, NS.winner

local MATERIALS = { "classic", "clean", "pearl" }
local ICONS = { "Interface\\Icons\\Spell_Frost_FrostBolt02", "Interface\\Icons\\Spell_Fire_FlameBolt",
                "Interface\\Icons\\Spell_Nature_Lightning" }
local SIZE, GAP, COL = 45, 14, 150   -- 45: Blizzard's action buttons (the large fonts)
local SMOKED = { 0.05, 0.06, 0.08, 0.62 }   -- GAB's smoked theme, as a colour

local PB = { look = {}, skins = {}, glass = {}, buttons = {}, failures = {} }

local function look(key) return PB.look[key] end
local function onError(step, msg)
    PB.failures[#PB.failures + 1] = step .. ": " .. msg
    say("button: step " .. step .. " failed: " .. msg)
end

local function instance(material)
    if not PB.glass[material] then PB.glass[material] = LibStub("LibGlass-1.0"):New({ preset = material }) end
    return PB.glass[material]
end

-- One probe button, as an addon makes its own: every region by role, and a
-- bronze frame of its own for the skin to fade: four 3 px strips round the
-- button, an outline, so an empty slot (its icon hidden, as an empty action
-- slot's is) reads as an empty framed slot when the skin is off.
local FRAME_EDGES = {
    frameTop    = { "TOPLEFT", -3, 3, "TOPRIGHT", 3, 0 },
    frameBottom = { "BOTTOMLEFT", -3, 0, "BOTTOMRIGHT", 3, -3 },
    frameLeft   = { "TOPLEFT", -3, 0, "BOTTOMLEFT", 0, 0 },
    frameRight  = { "TOPRIGHT", 0, 0, "BOTTOMRIGHT", 3, 0 },
}
local function makeButton(parent, x, y, icon)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIZE, SIZE)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(b)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if icon then t:SetTexture(icon) else t:Hide() end
    local fade = {}
    for name, e in pairs(FRAME_EDGES) do
        -- e: the strip's top-left and bottom-right, each on a point of the
        -- button; top and bottom span the corners, the sides sit between.
        local strip = b:CreateTexture(nil, "BACKGROUND")
        strip:SetPoint("TOPLEFT", b, e[1], e[2], e[3])
        strip:SetPoint("BOTTOMRIGHT", b, e[4], e[5], e[6])
        strip:SetColorTexture(0.55, 0.4, 0.2, 0.9)
        fade[name] = strip
    end
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- A font of its own, as an action button has from its template: SetText
    -- on a font string without one throws "Font not set" (70959).
    local hk = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    hk:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
    local count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    cd:SetAllPoints(t)
    local regions = { icon = t, pushed = b:GetPushedTexture(), highlight = b:GetHighlightTexture(),
                      hotkey = hk, count = count, fade = fade }
    return b, regions, cd
end

local function skinOne(glass, b, regions, empty)
    local skin, why = glass.Button(b, regions, { look = look, onError = onError, maskIcon = true })
    if not skin then say("button: Button refused: " .. tostring(why)); return nil end
    if empty then glass.SetButtonEmpty(skin, true) end
    PB.skins[#PB.skins + 1] = { skin = skin, glass = glass }
    return skin
end

local function buildButtons()
    if PB.root then PB.root:Show(); return true end
    if type(minor()) ~= "number" or minor() < 13 then
        say("button: the running LibGlass r" .. tostring(minor()) .. " has no Button (r13 or later, from " .. winner() .. ")")
        return false, "LibGlass r" .. tostring(minor()) .. " has no Button"
    end
    PB.look = {}
    local w, h = 30 + #MATERIALS * COL, 64 + 40 + 2 * (SIZE + GAP) + 40
    PB.root = board(instance("classic"), w, h, "LibGlass #46: the button skin",
        "One column per material: filled (top), empty (bottom). Hover and click them.")
    local grid = CreateFrame("Frame", nil, PB.root)
    grid:SetPoint("TOPLEFT", PB.root, "TOPLEFT", 15, -90)
    grid:SetSize(w - 30, h - 100)
    for c, material in ipairs(MATERIALS) do
        local glass = instance(material)
        local head = glass.Font(grid, 12, "LEFT")
        head:SetPoint("TOPLEFT", grid, "TOPLEFT", (c - 1) * COL, 18)
        head:SetText(material)
        for row = 1, 2 do
            local x, y = (c - 1) * COL, -(row - 1) * (SIZE + GAP)
            local icon = row == 1 and ICONS[c] or nil
            local b, regions, cd = makeButton(grid, x, y, icon)
            regions.hotkey:SetText(tostring(c))
            regions.count:SetText(row == 1 and "20" or "")
            skinOne(glass, b, regions, row == 2)
            PB.buttons[#PB.buttons + 1] = { button = b, cd = cd, filled = row == 1 }
            local b2, r2 = makeButton(grid, x + SIZE + GAP, y, icon)
            r2.hotkey:SetText("")
            r2.count:SetText("")
            skinOne(glass, b2, r2, row == 2)
            PB.buttons[#PB.buttons + 1] = { button = b2, filled = row == 1 }
        end
    end
    PB.root:Show()
    return true
end

local function needButtons() if not PB.root then buildButtons() end end

local function refresh()
    for _, s in ipairs(PB.skins) do s.glass.RefreshButton(s.skin) end
end

local function setLook(key, value)
    needButtons()
    PB.look[key] = value
    refresh()
    say("button: look " .. key .. " = " .. Probe.Show(value))
    return true
end

local function cooldowns()
    needButtons()
    local now = GetTime()
    for _, e in ipairs(PB.buttons) do
        if e.cd and e.filled then e.cd:SetCooldown(now, 30) end
    end
    return true
end

local function setShown(shown)
    needButtons()
    for _, s in ipairs(PB.skins) do s.glass.SetButtonShown(s.skin, shown) end
    say("button: skins " .. (shown and "on" or "off"))
    return true
end

local function resize(size)
    needButtons()
    for _, e in ipairs(PB.buttons) do e.button:SetSize(size, size) end
    for _, s in ipairs(PB.skins) do s.glass.RestyleButton(s.skin) end
    say("button: resized to " .. size .. ", restyled")
    return true
end

-- The secure button: SecureActionButtonTemplate, on UIParent (a protected
-- frame inside the board would make hiding the board protected in combat),
-- targeting you on a click. Built and skinned out of combat.
local function buildSecure()
    if PB.secure then PB.secure:Show(); return true end
    if InCombatLockdown() then return false, "build it out of combat" end
    needButtons()
    local b = CreateFrame("Button", "LibGlassProbeSecureButton", UIParent, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:SetPoint("TOP", UIParent, "CENTER", 0, -120)
    b:SetFrameStrata("DIALOG")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "target")
    b:SetAttribute("unit", "player")
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(b)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t:SetTexture(ICONS[1])
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local glass = instance("pearl")
    PB.secureSkin = skinOne(glass, b, { icon = t, pushed = b:GetPushedTexture(), highlight = b:GetHighlightTexture() })
    PB.secure = b
    return PB.secureSkin ~= nil
end

-- In combat: the setup again (RestyleButton), the paint, the empty state
-- and back, on the secure button.
local function restyleInCombat()
    if not PB.secureSkin then return false, "no secure button" end
    local fight = InCombatLockdown()
    local glass = instance("pearl")
    local ok = glass.RestyleButton(PB.secureSkin)
    glass.SetButtonEmpty(PB.secureSkin, true)
    glass.RefreshButton(PB.secureSkin)
    glass.SetButtonEmpty(PB.secureSkin, false)
    PB.combat = { fight = fight, ok = ok }
    say("button: restyle in combat " .. Probe.Show(fight) .. ", returned " .. Probe.Show(ok))
    return fight, ok
end

local function combatChecked()
    local c = PB.combat or {}
    return c.fight == true and c.ok == true, "in combat " .. Probe.Show(c.fight) .. ", restyle " .. Probe.Show(c.ok)
end

-- What the skins hold: failures by step, per skin, and the probe's own list.
local function buttonState()
    local failed = 0
    for i, s in ipairs(PB.skins) do
        for step, msg in pairs(s.skin.failures) do
            failed = failed + 1
            say("button: skin " .. i .. " failed " .. step .. ": " .. msg)
        end
    end
    say("button: " .. #PB.skins .. " skins, " .. failed .. " step failures, look " .. Probe.Describe(PB.look))
    return failed == 0, #PB.skins .. " skins, " .. failed .. " step failures"
end

Probe:Command("button", function() buildButtons(); buttonState() end, "#46: the button skin on each material")
Probe:Command("buttonlook", function(args)
    local key, value = (args or ""):match("^(%S+)%s*(%S*)$")
    if not key then say("button: /fp lg buttonlook <hover|press|emptySlots|tint> <value|smoked|nil>"); return end
    if key == "tint" then setLook(key, value == "smoked" and SMOKED or nil) else setLook(key, value ~= "" and value or nil) end
end, "#46: set one look key live (tint smoked or nil)")

NS.hides[#NS.hides + 1] = function()
    if PB.root then PB.root:Hide() end
    if PB.secure and not InCombatLockdown() then PB.secure:Hide() end
end

Probe:Steps("button", {
    title = "LibGlass #46: the button skin",
    rev = 1,
    { text = "Checking which copy of LibGlass is running: r13 or later, and this probe's own.",
      auto = true, run = report,
      check = function()
          local m, host = minor(), winner()
          return type(m) == "number" and m >= 13 and host == "LibGlassProbe", "LibGlass r" .. tostring(m) .. " from " .. host
      end },
    { text = "Open the board: Classic, Clean and Pearl columns, filled buttons on top, empty below. Drag it by its header.",
      button = "Show board", run = buildButtons, screenshot = "button: the board" },
    { text = "Start a cooldown sweep on the filled buttons.", button = "Start cooldowns", run = cooldowns,
      screenshot = "button: cooldowns" },
    { text = "Filled buttons: a crisp light rim over the icon's edge, rounded icons, no bronze frame, the rim over the sweep. Pearl also shows a soft reflection at the top. Right?",
      ask = true },
    { text = "Empty buttons: a pale frosted tile. On Pearl, a recessed socket (a lit lower lip) instead of the raised rim. Right?",
      ask = true },
    { text = "Hover the buttons: a softened highlight (the glow). Then switch to the halo.", button = "Halo on hover",
      run = function() return setLook("hover", "halo") end },
    { text = "Hover again: a warm halo fades in round the button and out when you leave, no square highlight. Right?",
      ask = true },
    { text = "Switch the press look to the ripple, then click a few buttons.", button = "Ripple on click",
      run = function() return setLook("press", "ripple") end },
    { text = "Did a ripple swell from where you clicked, inside the rounded square, and fade?", ask = true },
    { text = "Give the glass a smoked tint, as a theme would.", button = "Smoked tint",
      run = function() return setLook("tint", SMOKED) end, screenshot = "button: smoked" },
    { text = "Smoked: the empty buttons keep the dark tint (fainter), not the pale frost. Right?", ask = true },
    { text = "Back to clear glass, then turn every skin off.", button = "Skins off",
      run = function() setLook("tint", nil); return setShown(false) end, screenshot = "button: off" },
    { text = "Off: square icons, the bronze frames back, the full Blizzard highlight on hover, no rim. Right?",
      ask = true },
    { text = "Turn the skins back on.", button = "Skins on", run = function() return setShown(true) end,
      screenshot = "button: on again" },
    { text = "On again: the same look as at the start (rims, rounded icons, frost, frames faded). Right?", ask = true },
    { text = "Shrink the buttons to 30 and restyle them (smaller hotkey and count text).", button = "Shrink",
      run = function() return resize(30) end, screenshot = "button: small" },
    { text = "Small: the rim, frost and halo still fit the smaller buttons, and the text is smaller. Right?",
      ask = true },
    { text = "Back to 45.", button = "Restore", run = function() return resize(SIZE) end },
    { text = "Out of combat: make the secure test button (it targets you on a click). It appears under the board.",
      button = "Make secure button", run = buildSecure },
    { text = "Now start a fight (a training dummy or a weak mob). Don't move the board in combat. In combat, press the button below.",
      button = "Restyle in combat", run = restyleInCombat, check = combatChecked },
    { text = "Still in combat, click the secure test button: it should target you. Did it, with no \"action blocked\" message?",
      ask = true },
    { text = "Logging the skins' step failures.", auto = true, run = needButtons, check = buttonState },
    { text = "That's all. Press Finish, then type /reload so the results and screenshots are saved." },
})

NS._test = NS._test or {}
NS._test.Buttons = { PB = PB, buildButtons = buildButtons, buildSecure = buildSecure, restyleInCombat = restyleInCombat,
                     buttonState = buttonState, setLook = setLook, setShown = setShown, resize = resize }
