-- Every widget method the library calls must exist on this client.
--
-- The stub answers any method call (a no-op for ones it does not implement),
-- so a call to a method Forever lacks would otherwise pass silently. This
-- checks each recorded "Type:Method" against the API dump's widget-method
-- walk, falling back to Animation for the animation subtypes the walk does
-- not list (Translation, Alpha), then to the documented functions
-- (Alpha:SetToAlpha), as GlassUnitFrames' test_methods does.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local f = io.open(WoW.DUMP, "r")
if not f then
    io.write("test_methods: SKIPPED (no API dump at " .. WoW.DUMP .. ")\n")
    os.exit(0)
end
local widget, documented = {}, {}
for line in f:lines() do
    local wm = line:match("^(%a+:%a+)%s*$")
    if wm then widget[wm] = true end
    local fn = line:match("^([%a_]+)%(")
    if fn then documented[fn] = true end
end
f:close()

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
local um = Glass.Mask(newHost(), "disc_mask", nil)
eq(um._slice, nil, "Mask with a nil margin is unsliced")

Glass.SetRimAlpha(0.5); Glass.SetFillAlpha(0.5); Glass.SetTrackAlpha(0.5)
Glass.SetFillEnd(0.5); Glass.SetEdgeAlpha(0.5); Glass.SetFont("friz")
for _, g in ipairs(discs) do eq(g.rim._alpha, 0.5, g.size .. ": SetRimAlpha reaches the disc") end

local n = 0
for name in pairs(WoW.methodsCalled) do
    n = n + 1
    local wtype, method = name:match("^(%a+):(%a+)$")
    local ok = widget[name]
        or ((wtype == "Translation" or wtype == "Alpha") and widget["Animation:" .. method])
        or documented[method]
    check(ok, "method exists on Forever: " .. name)
end
check(n > 30, "recorded a realistic number of methods (" .. n .. ")")
done("test_methods")
