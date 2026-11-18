-- Every widget method the library calls must exist on this client.
--
-- A method the pinned build lacks on one widget type can still answer on the
-- stub (an implementation another type uses), so a call to it would
-- otherwise pass silently. This exercises the library, then checks each
-- recorded "Type:Method" against the build's widget methods with WowTestKit's
-- Kit.checkMethods (an animation subtype may also call Animation's).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- Exercise everything so every method is recorded.
local Glass = loadLibrary("GlassUnitFrames"):New()
for _, size in ipairs({ "large", "small" }) do
    local host = newHost(200, size == "large" and 60 or 24)
    local g = Glass.Apply(host, size)
    local bar = Glass.Bar(host, 20)
    bar:SetStatusBarColor(1, 0, 0, 0.8)
    bar:SetHeight(12)
    bar:SetFrameLevel(5)
    Glass.SetBar(bar, 100, 50, true)
    Enum.StatusBarInterpolation = { ExponentialEaseOut = 2 }
    Glass.SetBar(bar, 100, 60)
    Enum.StatusBarInterpolation = nil
    Glass.Font(g.top, 12, "CENTER")
    local ag = Glass.Sheen(g, host, 200, 40)
    ag:Stop(); ag:Play()
    Glass.Mask(host, "bar_mask", 8, 2, g.top)
    Glass.SetEdge(g, 0.5, 0.1, 0.3)
end
-- Discs (r2): their own builder, every layer unsliced.
local discs = {}
for _, case in ipairs({ { "disc", 320 }, { "disc_small", 64 }, { "disc_small", 40 } }) do
    local size, px = case[1], case[2]
    local host = newHost(px, px)
    local g = Glass.Disc(host, size)
    discs[#discs + 1] = g
    local S = Glass.SIZES[size]
    eq(g.size, size, size .. ": g.size")
    for _, f in ipairs({ "shadow", "mask", "tint", "grain", "wash", "top", "dark", "rim" }) do
        check(g[f] ~= nil, size .. " " .. px .. ": g." .. f)
    end
    eq(g.edge, nil, size .. ": no edge")
    eq(g.mask._file, Glass.MEDIA .. S.mask, size .. ": the disc mask")
    eq(g.rim._file, Glass.MEDIA .. S.rim, size .. ": the disc rim")
    eq(g.dark._file, Glass.MEDIA .. S.dark, size .. ": the disc dark rim")
    eq(g.shadow._file, Glass.MEDIA .. S.shadow, size .. ": the disc shadow")
    for _, f in ipairs({ "shadow", "mask", "tint", "grain", "wash", "dark", "rim" }) do
        eq(g[f]._slice, nil, size .. ": g." .. f .. " is not sliced")
    end
    for _, f in ipairs({ "tint", "grain", "wash" }) do
        check(g[f]._masks and g[f]._masks[1] == g.mask, size .. ": g." .. f .. " masked by the disc mask")
    end
    local out = px * S.shadowOutset
    local p1, p2 = g.shadow._points[1], g.shadow._points[2]
    check(p1[1] == "TOPLEFT" and p1[4] == -out and p1[5] == out and p2[1] == "BOTTOMRIGHT"
          and p2[4] == out and p2[5] == -out, size .. ": the shadow is a symmetric outset of " .. out)
    eq(g.rim._alpha, Glass.STYLE.rimAlpha, size .. ": the rim at STYLE.rimAlpha")
    eq(g.top:GetFrameLevel(), host:GetFrameLevel() + 10, size .. ": g.top above the content")
    local registered = false
    for _, r in ipairs(Glass._rims) do if r == g.rim then registered = true end end
    check(registered, size .. ": the rim is registered for SetRimAlpha")
    local ag = Glass.Sheen(g, host, px, px)
    ag:Stop(); ag:Play()
    Glass.Mask(CreateFrame("Frame", nil, host), S.mask, nil, 2, host)
    Glass.SetEdge(g, 0.5, 0.1, 0.3)   -- no edge: ignored
end
eq(Glass.Inset("disc"), 6, "disc inset")
eq(Glass.Inset("disc_small"), 4, "disc_small inset: past the inner catch-light (3.8 texture px)")
check(pcall(Glass.Disc, newHost(128, 128)), "Disc defaults to \"disc\"")
local okRect, errRect = pcall(Glass.Disc, newHost(100, 60), "disc")
check(not okRect and tostring(errRect):find("square host", 1, true), "a non-square host is refused: " .. tostring(errRect))
local okZero, errZero = pcall(Glass.Disc, CreateFrame("Frame", nil, UIParent), "disc")
check(not okZero and tostring(errZero):find("sized before", 1, true), "an unsized host is refused: " .. tostring(errZero))
local okSize, errSize = pcall(Glass.Disc, newHost(64, 64), "large")
check(not okSize and tostring(errSize):find("Disc takes", 1, true), "a rect size is refused: " .. tostring(errSize))
local okApply, errApply = pcall(Glass.Apply, newHost(64, 64), "disc")
check(not okApply and tostring(errApply):find("use Glass.Disc", 1, true), "Apply refuses a disc size: " .. tostring(errApply))
-- Refusals name the consumer's line, through the instance wrapper's tail call.
for _, case in ipairs({ { "Disc", newHost(100, 60), "disc" }, { "Disc", newHost(64, 64), "large" },
                        { "Apply", newHost(64, 64), "disc" } }) do
    local ok, err = pcall(function() Glass[case[1]](case[2], case[3]) end)
    check(not ok and tostring(err):find("test_methods%.lua:%d+: LibGlass"), case[1] .. "(" .. case[3] .. ") errors at the call site: " .. tostring(err))
end
-- Pills (r5): the button's highlight, the pill and its rims' levels.
local pb = CreateFrame("Button", nil, UIParent)
pb:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
local pill = Glass.Pill(pb, { side = 20 })
pb:SetFrameLevel(6)
Glass.RelevelPill(pill)
local um = Glass.Mask(newHost(), "disc_mask", nil)
eq(um._slice, nil, "Mask with a nil margin is unsliced")

Glass.SetRimAlpha(0.5); Glass.SetFillAlpha(0.5); Glass.SetTrackAlpha(0.5)
Glass.SetFillEnd(0.5); Glass.SetEdgeAlpha(0.5); Glass.SetFont("friz")
Glass.SetTrackLength(0.05); Glass.SetTrackLength(0)
for _, g in ipairs(discs) do eq(g.rim._alpha, 0.5, g.size .. ": SetRimAlpha reaches the disc") end

-- The button skin (r13, #46), on a Pearl instance (its face too): build,
-- every hook, the effects, paint, restyle, off and on.
local Pearl = loadLibrary("GlassUnitFrames"):New({ preset = "pearl" })
local bb = CreateFrame("CheckButton", nil, UIParent)
bb:SetSize(36, 36)
bb:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
local br = { icon = bb:CreateTexture(), pushed = bb:CreateTexture(), highlight = bb:GetHighlightTexture(),
             hotkey = bb:CreateFontString(), count = bb:CreateFontString(), name = bb:CreateFontString(),
             fade = { border = bb:CreateTexture() } }
local bLook = { hover = "halo", press = "ripple" }
local skin = Pearl.Button(bb, br, { look = function(k) return bLook[k] end, maskIcon = true, inset = 2 })
check(skin ~= nil and next(skin.failures) == nil, "the button skin built, no step failed")
skin.body._escale, skin.body._left, skin.body._bottom, bb._mouseOver = 1, 0, 0, true
for _, script in ipairs({ "OnEnter", "OnMouseDown", "OnLeave", "OnHide" }) do
    for _, fn in ipairs(bb._hooks[script]) do fn(bb) end
end
for _, fn in ipairs(bb._hooks.OnEnter) do fn(bb) end
WoW.tick(0.5)
Pearl.SetButtonEmpty(skin, true)
Pearl.RefreshButtons()
Pearl.RestyleButton(skin)
Pearl.SetButtonShown(skin, false)
Pearl.SetButtonShown(skin, true)
check(next(skin.failures) == nil, "the skin's exercise failed no step")

-- The floor is what the exercise above records today (94), rounded down: it
-- keeps the exercise from quietly shrinking.
local recorded = Kit.checkMethods()
check(recorded >= 90, "the exercise reached every builder and setter (" .. recorded .. " recorded)")
done("test_methods")
