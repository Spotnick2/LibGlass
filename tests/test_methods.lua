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
Glass.SetRimAlpha(0.5); Glass.SetFillAlpha(0.5); Glass.SetTrackAlpha(0.5)
Glass.SetFillEnd(0.5); Glass.SetEdgeAlpha(0.5); Glass.SetFont("friz")

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
