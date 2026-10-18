-- LibGlassProbe: LibGlass's developer probe, a ForeverProbe module (/fp lg).
-- Its lines go to the ForeverProbe console and LibGlassProbeDB.log, never to
-- chat. It is never packaged: the library has no TOC of its own.
--
-- Boards, each a plain frame holding glass built by the probe's own
-- instances (an instance's setters reach only the surfaces it built):
-- - compare: probe 4 (r6, #41). Three clean columns that differ only in the
--   empty-track colour.                      /fp lg show a|b|c|all, next, ...
-- - r7: the disabled look through the gradients, and SetWash (#47, #50).
--   Each surface beside a disabled copy, classic and clean, and a strip of
--   four gradients for the SetAlpha-before-SetGradient question.
--                                            /fp steps lg r7 walks it
-- - fill, preview: the bar fill's opacity (#53).
-- - r9: the reflective shell through Reflect beside the recipe by hand
--   (#56), and one surface's own rim (SetSurfaceRim, #40).
--                                            /fp steps lg r9 walks it;
--                                            /fp steps lg rim, the rims alone
-- The embedded library is this checkout (deploy.ps1). A newer copy in
-- another addon would win LibStub, so `report` and the procedure's first
-- step log which MINOR runs.
--
-- No unit queries, secure templates or continuous updates.

local ADDON, NS = ...
local MAX_LOG = 3000
local Probe = ForeverProbe:Module("LibGlassProbe", { api = 1, cmd = "lg" })
local function say(msg) Probe:Say(msg) end

local function minor()
    local _, m = LibStub:GetLibrary("LibGlass-1.0", true)
    return m
end

local function label(glass, parent, text, size, x, y)
    local fs = glass.Font(parent, size, "LEFT")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

-- A movable board: only the header catches the mouse, so the open area shows
-- the world behind the glass.
local function board(glass, width, height, title, hint)
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetSize(width, height)
    root:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    root:SetFrameStrata("DIALOG")
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    local header = CreateFrame("Frame", nil, root)
    header:SetPoint("TOPLEFT", root, "TOPLEFT")
    header:SetPoint("TOPRIGHT", root, "TOPRIGHT")
    header:SetHeight(64)
    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(header)
    bg:SetColorTexture(0.025, 0.03, 0.04, 0.94)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() root:StartMoving() end)
    header:SetScript("OnDragStop", function() root:StopMovingOrSizing() end)
    label(glass, header, title .. "  |  Drag here", 14, 12, -9)
    label(glass, header, hint, 12, 12, -32)
    local close = CreateFrame("Button", nil, header)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -4, -4)
    label(glass, close, "X", 14, 7, -4)
    close:SetScript("OnClick", function() root:Hide() end)
    return root
end

--------------------------------------------------------------------------------
-- compare: probe 4 (r6). Only the empty-track colour differs between columns.
--------------------------------------------------------------------------------

local C = { surfaces = {}, bars = {}, smoke = 0.24, fill = 3, selected = "all", rotation = 0 }
local variants = {
    { key = "a", title = "A  Current track", note = "Empty-track colour: 0.75", track = 0.75 },
    { key = "b", title = "B  Reduced track", note = "Empty-track colour: 0.20", track = 0.20 },
    { key = "c", title = "C  Neutral track", note = "Empty-track colour: off", track = 0 },
}

local function compareSurface(host, variant, small)
    local g = variant.glass.Apply(host, small and "small" or "large")
    C.surfaces[#C.surfaces + 1] = { g = g, glass = variant.glass }
    return g
end

local function sample(parent, variant, y, height, small)
    local host = CreateFrame("Frame", nil, parent)
    host:SetSize(280, height)
    host:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    return host, compareSurface(host, variant, small)
end

local function layout()
    C.root:SetWidth(C.selected == "all" and 940 or 320)
    for i, column in ipairs(C.columns) do
        column:ClearAllPoints()
        local slot = C.selected == "all" and ((i - 1 + C.rotation) % #variants) or 0
        column:SetPoint("TOPLEFT", C.root, "TOPLEFT", 20 + slot * 310, -82)
        column:SetShown(C.selected == "all" or C.selected == variants[i].key)
    end
end

local function buildCompare()
    local glass = LibStub("LibGlass-1.0"):New()
    C.glass = glass
    C.root = board(glass, 940, 410, "Glass probe 4", "/fp lg show a | b | c | all, next, rotate")
    C.columns = {}
    for i, variant in ipairs(variants) do
        variant.glass = LibStub("LibGlass-1.0"):New({ preset = "clean", bodyAlpha = C.smoke })
        variant.glass.SetTrackAlpha(variant.track)
        local column = CreateFrame("Frame", nil, C.root)
        column:SetSize(280, 320)
        C.columns[i] = column
        label(glass, column, variant.title, 16, 0, 0)
        label(glass, column, variant.note, 12, 0, -22)

        local _, pg = sample(column, variant, -52, 104, false)
        label(glass, pg.top, "Reading panel", 14, 16, -14)
        label(glass, pg.top, "Watch the scenery through the center.", 12, 16, -40)
        label(glass, pg.top, "Move the camera; check text contrast.", 12, 16, -61)
        label(glass, pg.top, "Same rims, wash and shadow strength.", 12, 16, -80)

        local unit, ug = sample(column, variant, -185, 64, false)
        label(glass, ug.top, "Sample unit", 13, 12, -8)
        local bar = variant.glass.Bar(unit, 22)
        bar:SetPoint("TOPLEFT", unit, "TOPLEFT", 12, -30)
        bar:SetWidth(256)
        bar:SetFrameLevel(glass.ContentLevel(unit))
        bar:SetStatusBarColor(0.22, 0.72, 0.42)
        variant.glass.SetBar(bar, 100, C.fill, true)
        local value = label(glass, ug.top, C.fill .. " / 100", 12, 112, -34)
        C.bars[#C.bars + 1] = { bar = bar, text = value, glass = variant.glass }

        local button = CreateFrame("Button", nil, column)
        button:SetSize(112, 28)
        button:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -279)
        local buttonGlass = compareSurface(button, variant, true)
        label(glass, buttonGlass.top, "Small control", 12, 16, -7)
        label(glass, column, "28 px tall", 12, 130, -287)
    end
    layout()
end

local function showCompare(mode)
    if not C.root then buildCompare() end
    if mode then C.selected = mode end
    layout()
    C.root:Show()
end

Probe:Command("show", function(args)
    local mode = args:lower()
    if mode ~= "" and mode ~= "all" and mode ~= "a" and mode ~= "b" and mode ~= "c" then
        say("show a | b | c | all")
        return
    end
    showCompare(mode ~= "" and mode or nil)
end, "the r6 track comparison: a, b or c at the same position, or all side by side")

Probe:Command("next", function()
    showCompare(({ all = "a", a = "b", b = "c", c = "a" })[C.selected])
end, "cycle a, b, c at the same position")

Probe:Command("rotate", function()
    C.rotation = (C.rotation + 1) % #variants
    showCompare("all")
end, "swap the columns' positions")

Probe:Command("smoke", function(args)
    local v = tonumber(args)
    if not v or v < 0 or v > 1 then say("smoke 0..1 (every column's body; default 0.24)") return end
    C.smoke = v
    showCompare()
    for _, s in ipairs(C.surfaces) do s.glass.SetSurfaceTint(s.g, nil, nil, nil, v) end
    say("every column: body alpha " .. v)
end, "0..1: every column's body opacity (default 0.24; try 0.50, 0.80)")

Probe:Command("value", function(args)
    local v = tonumber(args)
    if not v or v < 0 or v > 100 then say("value 0..100") return end
    C.fill = v
    showCompare()
    for _, b in ipairs(C.bars) do
        b.glass.SetBar(b.bar, 100, v, true)
        b.text:SetText(v .. " / 100")
    end
end, "0..100: the sample bars' fake health")

--------------------------------------------------------------------------------
-- r7: the disabled look through the gradients, and SetWash
--------------------------------------------------------------------------------

local R = { surfaces = {}, strip = {} }
local F = { rows = {} }   -- the #53 fill board (below)
local P                   -- the #53 preview board (below)
local Q                   -- the r9 board (below)

-- One line per surface: the wash's painted peak (what the gradient was given)
-- and whether it is shown. The library records the peak as glassPeak and the
-- dim as glassDim on the region; the client offers no gradient getter.
local function painted(r)
    if not r or r.glassPeak == nil then return "?" end
    return string.format("%.3f", r.glassPeak * (r.glassDim or 1))
end

local function state()
    local parts = {}
    for _, s in ipairs(R.surfaces) do
        local glow = s.g.edge and painted(s.g.edge.glow) or "-"
        parts[#parts + 1] = s.name .. " wash " .. painted(s.g.wash) .. (s.g.wash:IsShown() and "" or " hidden")
            .. " glow " .. glow
    end
    local line = table.concat(parts, "; ")
    say(line)
    return line
end

-- The four gradients: does SetAlpha survive when it comes BEFORE SetGradient
-- (on a colour texture, on a file texture), and is it lost AFTER (#47)?
local STRIP = {
    { key = "A", text = "A  colour, alpha first", file = false, alpha = "before" },
    { key = "B", text = "B  file, alpha first", file = true, alpha = "before" },
    { key = "C", text = "C  reference", file = false },
    { key = "D", text = "D  colour, alpha after", file = false, alpha = "after" },
}

local function gradientSample(parent, spec, x, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(150, 44)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if spec.file then t:SetTexture("Interface\\Buttons\\WHITE8X8") else t:SetColorTexture(1, 1, 1, 1) end
    if spec.alpha == "before" then t:SetAlpha(0.2) end
    t:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))
    if spec.alpha == "after" then t:SetAlpha(0.2) end
    return t
end

local SIZES = {
    { size = "large", w = 200, h = 90, x = 20 },
    { size = "small", w = 112, h = 28, x = 470 },
}

-- Built fresh each time, with new instances: SetEdge marks an edge custom for
-- good, so a rerun needs surfaces that haven't been through the procedure.
local function buildR7()
    if R.root then R.root:Hide() end
    local lib = LibStub("LibGlass-1.0")
    local text = lib:New()
    R.surfaces, R.glasses, R.strip = {}, {}, {}
    R.root = board(text, 720, 520, "LibGlass r7: disabled look",
        "Left of each pair enabled, right disabled. /fp steps lg r7 walks it")
    local backdrop = R.root:CreateTexture(nil, "BACKGROUND")
    backdrop:SetPoint("TOPLEFT", R.root, "TOPLEFT", 0, -64)
    backdrop:SetPoint("BOTTOMRIGHT", R.root, "BOTTOMRIGHT")
    backdrop:SetColorTexture(0, 0, 0, 0.9)
    R.backdrop = backdrop
    local rows = { { key = "classic", glass = lib:New() }, { key = "clean", glass = lib:New({ preset = "clean" }) } }
    for r, row in ipairs(rows) do
        R.glasses[r] = row.glass
        local top = -76 - (r - 1) * 150
        label(text, R.root, row.key .. (row.key == "clean" and ' (preset "clean")' or " (the default)"), 13, 20, top)
        for _, sz in ipairs(SIZES) do
            for pair, enabled in ipairs({ true, false }) do
                local host = CreateFrame("Frame", nil, R.root)
                host:SetSize(sz.w, sz.h)
                local x = sz.x + (pair - 1) * (sz.w + 16)
                host:SetPoint("TOPLEFT", R.root, "TOPLEFT", x, top - 22)
                local g = row.glass.Apply(host, sz.size)
                if not enabled then row.glass.SetSurfaceEnabled(g, false) end
                label(text, R.root, enabled and "enabled" or "disabled", 11, x, top - 26 - sz.h)
                R.surfaces[#R.surfaces + 1] = { g = g, glass = row.glass, enabled = enabled,
                                                name = row.key .. " " .. sz.size .. " " .. (enabled and "on" or "off") }
            end
        end
    end
    label(text, R.root, "Gradient strip: white, clear at the bottom to full at the top", 13, 20, -382)
    for i, spec in ipairs(STRIP) do
        local x = 20 + (i - 1) * 172
        R.strip[i] = { spec = spec, tex = gradientSample(R.root, spec, x, -406) }
        label(text, R.root, spec.text, 12, x, -456)
    end
    R.root:Show()
    say("r7 board on LibGlass r" .. tostring(minor()))
    return state()
end

local function need() if not R.root then buildR7() end; R.root:Show() end

-- Every surface's wash; nil = the default each instance was built with.
local function setWash(v)
    need()
    for _, s in ipairs(R.surfaces) do s.glass.SetWash(s.g, v or s.glass.STYLE.wash) end
    return state()
end

local function setDisabled(on)
    need()
    for _, s in ipairs(R.surfaces) do
        if not s.enabled then s.glass.SetSurfaceEnabled(s.g, not on) end
    end
    return state()
end

local function setEdge(v)
    need()
    for _, glass in ipairs(R.glasses) do glass.SetEdgeAlpha(v) end
    return state()
end

local function strongGlow()
    need()
    for _, s in ipairs(R.surfaces) do
        if s.g.edge then s.glass.SetEdge(s.g, 0.9, 0.6, 0.6, 8) end
    end
    return state()
end

local function setBackdrop(on)
    need()
    R.backdrop:SetShown(on)
    say("backdrop " .. (on and "black" or "off: the scenery shows"))
    return on
end

-- GetAlpha on each strip texture: on 70374 it read 1 straight after
-- SetAlpha(0) on a gradient wash (#47).
local function readStrip()
    need()
    local parts = {}
    for _, s in ipairs(R.strip) do
        local ok, a = Probe:Try("GetAlpha " .. s.spec.key, s.tex.GetAlpha, s.tex)
        parts[#parts + 1] = s.spec.key .. " GetAlpha " .. Probe.Show(ok and a)
    end
    local line = table.concat(parts, "; ")
    say("strip: " .. line)
    return line
end

local function report()
    local m = minor()
    local scale = UIParent:GetEffectiveScale()
    say("LibGlass r" .. tostring(m) .. " is the loaded copy; UI scale " .. Probe.Show(scale))
    return m, scale
end

Probe:Command("report", function()
    report()
    if C.root then
        say("compare: view " .. C.selected .. ", body alpha " .. C.smoke .. ", fill " .. C.fill
            .. "%; grain 0, gloss 0.25, shade 0.15; track A 0.75, B 0.20, C 0")
    end
    if R.root then state() end
end, "which LibGlass runs, the UI scale, and each board's settings")

Probe:Command("r7", function() buildR7() end, "the r7 board, built fresh (/fp steps lg r7 walks it)")
Probe:Command("wash", function(args)
    local v = tonumber(args)
    if args ~= "" and not v then say("wash 0..1, or nothing for the default") return end
    setWash(v)
end, "0..1: every r7 surface's wash (SetWash); nothing = the default")
Probe:Command("disabled", function(args) setDisabled(args:lower() ~= "off") end,
    "on|off: the right-hand r7 surfaces disabled or enabled")
Probe:Command("edge", function(args)
    local v = tonumber(args)
    if not v then say("edge 0..1") return end
    setEdge(v)
end, "0..1: the r7 surfaces' edge (SetEdgeAlpha)")
Probe:Command("backdrop", function(args) setBackdrop(args:lower() ~= "off") end,
    "on|off: black behind the r7 board, or the scenery")
Probe:Command("hide", function()
    if C.root then C.root:Hide() end
    if R.root then R.root:Hide() end
    if F.root then F.root:Hide() end
    if P.root then P.root:Hide() end
    if Q.root then Q.root:Hide() end
    for _, hide in ipairs(NS.hides) do hide() end
end, "close every board")
Probe:Command("clear", function() Probe:ClearLog(); say("log cleared") end, "empty the saved log")

-- The r7 check (#50): what tagging r7 waits on. Each look is a run step, then
-- a yes/no question; what the library painted is logged at every step.
Probe:Steps("r7", {
    title = "LibGlass r7: the disabled look and SetWash",
    rev = 1,
    { text = "Checking which copy of LibGlass is running. (Another Glass addon may carry a newer or older one; the newest wins.)",
      auto = true, run = report,
      check = function()
          local m = minor()
          return type(m) == "number" and m >= 7, "LibGlass r" .. tostring(m)
      end },
    { text = "Open the r7 board. Each surface has a disabled copy on its right; classic on top, clean below. Drag the board by its header so this panel doesn't cover it.",
      button = "Show board", run = buildR7 },
    { text = "Make every wash strong (0.6), so the difference is easy to see.", button = "Wash 0.6",
      run = function() return setWash(0.6) end },
    { text = "In both rows, is each disabled surface's top haze clearly fainter than the enabled one on its left?", ask = true },
    { text = "Turn every wash off (0).", button = "Wash 0", run = function() return setWash(0) end },
    { text = "Is the haze gone from every surface, enabled and disabled?", ask = true },
    { text = "Back to the default wash (0.18).", button = "Default wash", run = function() return setWash(nil) end },
    { text = "At the default, can you still tell the disabled haze is fainter? Subtle is fine; say how subtle in a note.", ask = true },
    { text = "Turn the edge on (0.45): a fine top line, a soft glow under it, a dark bottom line.", button = "Edge on",
      run = function() return setEdge(0.45) end },
    { text = "On the disabled surfaces, are the top line AND the soft glow under it dimmer than on the enabled ones?", ask = true },
    { text = "Make the glow strong (each surface's own edge, glow 0.6 over 8 px).", button = "Strong glow",
      run = strongGlow },
    { text = "Is the disabled surfaces' glow clearly dimmer?", ask = true },
    { text = "Enable the right-hand surfaces.", button = "Enable", run = function() return setDisabled(false) end },
    { text = "Do the right-hand surfaces now look the same as the left ones: haze, lines and glow?", ask = true },
    { text = "Disable them again, then set a strong wash (0.6) while they're disabled.", button = "Disable, wash 0.6",
      run = function() setDisabled(true); return setWash(0.6) end },
    { text = "Is the disabled haze fainter again, as in step 4?", ask = true },
    { text = "Take the black backdrop away, so the scenery shows behind the glass.", button = "Scenery",
      run = function() return setBackdrop(false) end },
    { text = "Over the scenery, is the difference still visible? A bright sky can hide a white haze: note what was behind.", ask = true },
    { text = "Put the backdrop back and look at the gradient strip at the bottom. C is the reference.", button = "Backdrop, read strip",
      run = function() setBackdrop(true); return readStrip() end },
    { text = "Strip: is A (a colour texture, SetAlpha 0.2 BEFORE its gradient) as bright as C?", ask = true },
    { text = "Is B (a file texture, SetAlpha 0.2 BEFORE its gradient) as bright as C?", ask = true },
    { text = "Is D (SetAlpha 0.2 AFTER the gradient) as bright as C? #47 says it should be.", ask = true },
    { text = "That's all. Press Finish, then type /reload so the results are saved to disk." },
})

--------------------------------------------------------------------------------
-- fill (#53): is a bar's fill opacity (STYLE.fillAlpha, SetFillAlpha) drawn?
-- The library sets it with SetAlpha, then paints the fill's horizontal
-- gradient; the r7 run measured that SetAlpha does nothing on a gradient
-- texture, in either order. Each bar sits on black and white stripes: a
-- see-through fill shows them, an opaque one hides them.
--------------------------------------------------------------------------------

local GREEN = { 0.22, 0.72, 0.42 }

local function fillState()
    local parts = {}
    for _, row in ipairs(F.rows) do
        local fill = row.bar:GetStatusBarTexture()
        local ok, a = Probe:Try("GetAlpha " .. row.key, fill.GetAlpha, fill)
        parts[#parts + 1] = row.key .. " fillAlpha " .. Probe.Show(row.glass.STYLE.fillAlpha)
            .. " GetAlpha " .. Probe.Show(ok and a) .. (row.bar.trackColor and "" or " no colour")
    end
    local line = table.concat(parts, "; ")
    say("fill: " .. line)
    return line
end

local function stripes(host, w, h)
    local n, list = 12, {}
    for i = 0, n - 1 do
        local t = host:CreateTexture(nil, "BACKGROUND")
        t:SetSize(w / n, h)
        t:SetPoint("TOPLEFT", host, "TOPLEFT", i * w / n, 0)
        if i % 2 == 0 then t:SetColorTexture(0.95, 0.95, 0.95, 1) else t:SetColorTexture(0, 0, 0, 1) end
        list[#list + 1] = t
    end
    return list
end

-- Built fresh each time: new instances, so SetFillAlpha starts from the values below.
local function buildFill()
    if F.root then F.root:Hide() end
    local lib = LibStub("LibGlass-1.0")
    local text = lib:New()
    local lo, def, hi = lib:New({ style = { fillAlpha = 0.2 } }), lib:New(), lib:New({ style = { fillAlpha = 1 } })
    F.lo, F.hi, F.rows = lo, hi, {}
    F.root = board(text, 660, 400, "LibGlass #53: bar fill opacity",
        "Stripes behind each bar: see-through fill shows them. /fp steps lg fill walks it")
    local specs = {
        { key = "1", glass = lo, label = "1  fillAlpha 0.2, coloured", colour = true },
        { key = "2", glass = def, label = "2  fillAlpha 0.6 (default), coloured", colour = true },
        { key = "3", glass = hi, label = "3  fillAlpha 1.0, coloured", colour = true },
        { key = "4", glass = lo, label = "4  fillAlpha 0.2, no colour yet", colour = false },
    }
    for i, spec in ipairs(specs) do
        local y = -88 - (i - 1) * 74
        label(text, F.root, spec.label, 13, 20, y)
        local host = CreateFrame("Frame", nil, F.root)
        host:SetSize(300, 30)
        host:SetPoint("TOPLEFT", F.root, "TOPLEFT", 330, y + 6)
        stripes(host, 300, 30)
        local bar = spec.glass.Bar(host, 22)
        bar:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -4)
        bar:SetWidth(300)
        if spec.colour then bar:SetStatusBarColor(GREEN[1], GREEN[2], GREEN[3]) end
        spec.glass.SetBar(bar, 100, 60, true)
        F.rows[i] = { key = spec.key, glass = spec.glass, bar = bar }
    end
    F.root:Show()
    say("fill board on LibGlass r" .. tostring(minor()))
    return fillState()
end

local function needFill() if not F.root then buildFill() end; F.root:Show() end

-- The client's own timer on a bar (GlassUnitFrames' cast bars use it): the
-- "visual reset" tintTrack's comment says left a fill opaque.
local function startTimer()
    needFill()
    local du = rawget(_G, "C_DurationUtil")
    local bar = F.rows[1].bar
    if not (du and du.CreateDuration and bar.SetTimerDuration) then
        say("fill: no SetTimerDuration on this client")
        return "no timer"
    end
    local okD, d = Probe:Try("CreateDuration", du.CreateDuration)
    if not okD or not d then return "no duration" end
    local getTime = rawget(_G, "GetTime")
    Probe:Try("SetTimeFromStart", d.SetTimeFromStart, d, getTime and getTime() or 0, 20)
    Probe:Try("SetTimerDuration", bar.SetTimerDuration, bar, d)
    return fillState()
end

Probe:Command("fill", function() buildFill() end, "the #53 fill-opacity board, built fresh (/fp steps lg fill walks it)")

Probe:Steps("fill", {
    title = "LibGlass #53: bar fill opacity",
    rev = 1,
    { text = "Checking which copy of LibGlass is running.", auto = true, run = report },
    { text = "Open the board. Four bars over black and white stripes: where the fill is see-through, the stripes show through the green. Drag the board so this panel doesn't cover it.",
      button = "Show board", run = buildFill, screenshot = "fill: the board" },
    { text = "Rows 1, 2 and 3 are coloured bars at fill 0.2, 0.6 and 1.0. Do the stripes show through the green differently in each? (All three the same means the fill opacity isn't drawn.)",
      ask = true },
    { text = "Row 4 is fill 0.2 too, but has no colour yet (no gradient). Do the stripes show through its fill more than through row 1's?",
      ask = true },
    { text = "Give row 4 the same green as the others.", button = "Colour row 4",
      run = function() needFill(); F.rows[4].bar:SetStatusBarColor(GREEN[1], GREEN[2], GREEN[3]); return fillState() end,
      screenshot = "fill: row 4 coloured" },
    { text = "Did row 4's fill change when it got its colour (the stripes covered up)?", ask = true },
    { text = "Raise fill 0.2 to 1.0 with SetFillAlpha (rows 1 and 4).", button = "SetFillAlpha 1",
      run = function() needFill(); F.lo.SetFillAlpha(1); return fillState() end, screenshot = "fill: SetFillAlpha 1" },
    { text = "And back to 0.2.", button = "SetFillAlpha 0.2",
      run = function() needFill(); F.lo.SetFillAlpha(0.2); return fillState() end, screenshot = "fill: SetFillAlpha 0.2" },
    { text = "Between those two, did rows 1 and 4 change at all?", ask = true },
    { text = "Give row 3 (fill 1.0) a colour whose own alpha is 0.3: that alpha goes into the gradient.",
      button = "Colour alpha 0.3",
      run = function() needFill(); F.rows[3].bar:SetStatusBarColor(GREEN[1], GREEN[2], GREEN[3], 0.3); return fillState() end,
      screenshot = "fill: row 3 colour alpha 0.3" },
    { text = "Did row 3 turn see-through (the stripes showing)?", ask = true },
    { text = "Start the client's own timer on row 1 (SetTimerDuration, 20 s).", button = "Start timer",
      run = startTimer, screenshot = "fill: row 1 timer" },
    { text = "Did row 1 look different once its timer started (more solid, less, or no change)? Say which in a note.",
      ask = true },
    { text = "That's all. Press Finish, then type /reload so the results and screenshots are saved." },
})

--------------------------------------------------------------------------------
-- preview (#53): an opaque fill (fillAlpha 1.0, what every coloured bar drew
-- until r7) beside the default 0.6, which r8 draws in the fill's gradient.
-- On an r7 or older copy both draw opaque: the board names the running MINOR.
--------------------------------------------------------------------------------

P = { bars = {} }

local function setPreviewValue(v)
    for _, b in ipairs(P.bars) do
        b.glass.SetBar(b.bar, 100, v, true)
        b.text:SetText(v .. " / 100")
    end
    say("preview: health " .. v .. "%")
    return v
end

local function buildPreview()
    if P.root then P.root:Hide() end
    local lib = LibStub("LibGlass-1.0")
    local text = lib:New()
    P.bars = {}
    P.root = board(text, 640, 300, "LibGlass #53: fill 1.0 beside 0.6",
        "Left: fill 1.0 (opaque, as before r8). Right: fill 0.6, the default. /fp steps lg preview")
    local rows = { { key = "classic", style = {} }, { key = "clean", preset = "clean", style = {} } }
    for r, row in ipairs(rows) do
        local y = -84 - (r - 1) * 104
        for c, alpha in ipairs({ 1, 0.6 }) do
            local x = 20 + (c - 1) * 310
            local glass = lib:New({ preset = row.preset, style = { fillAlpha = alpha } })
            label(text, P.root, row.key .. (alpha == 1 and ", fill 1.0 (opaque)" or ", fill 0.6"), 12, x, y)
            local host = CreateFrame("Frame", nil, P.root)
            host:SetSize(290, 64)
            host:SetPoint("TOPLEFT", P.root, "TOPLEFT", x, y - 18)
            local g = glass.Apply(host, "large")
            label(text, g.top, "Sample unit", 13, 12, -8)
            local bar = glass.Bar(host, 22)
            bar:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -30)
            bar:SetWidth(266)
            bar:SetFrameLevel(text.ContentLevel(host))
            bar:SetStatusBarColor(GREEN[1], GREEN[2], GREEN[3])
            P.bars[#P.bars + 1] = { bar = bar, glass = glass, text = label(text, g.top, "", 12, 120, -34) }
        end
    end
    P.root:Show()
    say("preview board on LibGlass r" .. tostring(minor()))
    return setPreviewValue(100)
end

local function needPreview() if not P.root then buildPreview() end; P.root:Show() end

Probe:Command("preview", function(args)
    local v = tonumber(args)
    if args ~= "" and (not v or v < 0 or v > 100) then say("preview, or preview 0..100 for the health") return end
    if not P.root or not v then buildPreview() end
    if v then setPreviewValue(v) end
end, "the #53 preview: fill 1.0 (opaque) beside the default 0.6 (preview 0..100 sets the health)")

Probe:Steps("preview", {
    title = "LibGlass #53: fill 1.0 beside 0.6",
    rev = 2,
    { text = "Open the preview. In each row, the left bar is fill 1.0 (opaque, every bar before r8) and the right one fill 0.6, the default. Move the camera so something detailed is behind it.",
      button = "Show preview", run = buildPreview, screenshot = "preview: full health" },
    { text = "Low health: 30%.", button = "Health 30",
      run = function() needPreview(); return setPreviewValue(30) end, screenshot = "preview: 30%" },
    { text = "Very low: 5%.", button = "Health 5",
      run = function() needPreview(); return setPreviewValue(5) end, screenshot = "preview: 5%" },
    { text = "Do you prefer the 0.6 bars (right) to the opaque ones (left)? Say why in a note, even a few words.", ask = true },
    { text = "Press Finish, then type /reload so the answer and screenshots are saved. (/fp lg preview reopens it any time.)" },
})

--------------------------------------------------------------------------------
-- r9: the reflective shell through Reflect (#56) beside the recipe built by
-- hand, as PetStable's UI.lua builds it (References\Docs\LIBGLASS-WINDOW-
-- STYLING.md), and one surface's own rim (SetSurfaceRim, #40). No backdrop
-- behind the shells: the scenery shows through. The controls sit on a black
-- strip and are large, with a red rim: the first run's small gold rims over
-- yellow grass were too faint to judge (rim5_small peaks at 106/255).
--------------------------------------------------------------------------------

Q = { controls = {} }
local SHELL_W, SHELL_H, HEADER = 320, 200, 70
local RED = { 1, 0.25, 0.2 }

-- The parts both shells share: tint, wash, edge off, a masked backing.
local function shellBody(glass, g, host)
    glass.SetSurfaceTint(g, 0.085, 0.095, 0.115, 0.78)
    glass.SetWash(g, 0)
    glass.SetEdge(g, 0, 0, 0)
    local backing = host:CreateTexture(nil, "BACKGROUND", nil, -7)
    backing:SetAllPoints(host)
    backing:AddMaskTexture(g.mask)
    backing:SetColorTexture(0.03, 0.03, 0.035, 0.55)
end

local function libShell(glass, host)
    local g = glass.Apply(host, "large")
    shellBody(glass, g, host)
    glass.SetSurfaceAlpha(g, "rim", 0.12)
    glass.SetSurfaceAlpha(g, "dark", 0.55)
    glass.SetSurfaceAlpha(g, "grain", 0)
    glass.SetSurfaceAlpha(g, "shadow", 0.18)
    glass.Reflect(g, host, { header = HEADER })
    return g
end

local function handShell(glass, host)
    local g = glass.Apply(host, "large")
    shellBody(glass, g, host)
    g.rim:SetAlpha(0.12)
    g.dark:SetAlpha(0.55)
    g.grain:SetAlpha(0)
    g.shadow:SetAlpha(0.18)
    local S = glass.SIZES[g.size]
    local rim = g.top:CreateTexture(nil, "OVERLAY", nil, 6)
    rim:SetAllPoints(host)
    rim:SetTexture(glass.MEDIA .. S.rim)
    rim:SetTextureSliceMargins(S.rimMargin, S.rimMargin, S.rimMargin, S.rimMargin)
    rim:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    rim:SetGradient("VERTICAL", CreateColor(0.55, 0.65, 0.75, 0.035), CreateColor(0.84, 0.88, 0.91, 0.52))
    local top = g.top:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetColorTexture(1, 1, 1, 1)
    top:SetPoint("TOPLEFT", host, "TOPLEFT", S.maskMargin, -1)
    top:SetPoint("TOPRIGHT", host, "TOPRIGHT", -S.maskMargin, -1)
    top:SetHeight(1)
    top:SetGradient("HORIZONTAL", CreateColor(0.88, 0.91, 0.93, 0.58), CreateColor(0.65, 0.73, 0.8, 0.035))
    local reflection = host:CreateTexture(nil, "BACKGROUND", nil, -3)
    reflection:SetColorTexture(1, 1, 1, 1)
    reflection:AddMaskTexture(g.mask)
    reflection:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    reflection:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
    reflection:SetHeight(HEADER)
    reflection:SetGradient("VERTICAL", CreateColor(0.77, 0.81, 0.85, 0), CreateColor(0.77, 0.81, 0.85, 0.105))
    return g
end

-- What the library painted: each Reflect layer's peak alpha (its gradient's
-- brighter end, times the dim), and the controls' rims.
local function r9State()
    local parts = {}
    local g = Q.lib
    if g and g.reflect then
        local function peak(r)
            if not r then return "-" end
            local s = r.glassStops
            return string.format("%.3f", math.max(s[2][4], s[3][4]) * (r.glassDim or 1))
        end
        parts[#parts + 1] = string.format("library shell rim %.3f, lit rim %s, top %s, header %s",
            g.rim:GetAlpha(), peak(g.reflect.rim), peak(g.reflect.top), peak(g.reflect.header))
    end
    if Q.hand then parts[#parts + 1] = string.format("hand shell rim %.3f", Q.hand.rim:GetAlpha()) end
    for _, c in ipairs(Q.controls) do
        parts[#parts + 1] = string.format("%s rim %.3f %s", c.name, c.g.rim:GetAlpha(), c.colour)
    end
    local line = table.concat(parts, "; ")
    say("r9: " .. line)
    return line
end

local function buildR9()
    if Q.root then Q.root:Hide() end
    local lib = LibStub("LibGlass-1.0")
    local text = lib:New()
    Q.shellGlass, Q.ctlGlass, Q.controls = lib:New({ preset = "clean" }), lib:New(), {}
    Q.root = board(text, 700, 470, "LibGlass r9: reflective shell, own rims",
        "Left: Reflect. Right: the recipe by hand. /fp steps lg r9 walks it")
    for i, spec in ipairs({ { key = "lib", title = "Library: Reflect", build = libShell },
                            { key = "hand", title = "By hand: the recipe", build = handShell } }) do
        local host = CreateFrame("Frame", nil, Q.root)
        host:SetSize(SHELL_W, SHELL_H)
        host:SetPoint("TOPLEFT", Q.root, "TOPLEFT", 20 + (i - 1) * (SHELL_W + 20), -84)
        local g = spec.build(Q.shellGlass, host)
        Q[spec.key] = g
        label(text, g.top, spec.title, 14, 16, -14)
        label(text, g.top, "Header text over the reflection", 12, 16, -38)
        label(text, g.top, "Reading area: the glow is gone here.", 12, 16, -96)
        label(text, g.top, "Small help text at 12 px.", 12, 16, -118)
    end
    label(text, Q.root, "Controls: default rim | red rim (SetSurfaceRim) | red rim, to be disabled", 13, 20, -306)
    local strip = Q.root:CreateTexture(nil, "BACKGROUND")
    strip:SetPoint("TOPLEFT", Q.root, "TOPLEFT", 0, -324)
    strip:SetPoint("BOTTOMRIGHT", Q.root, "BOTTOMRIGHT")
    strip:SetColorTexture(0, 0, 0, 0.9)
    for i, name in ipairs({ "default", "red", "red off" }) do
        local host = CreateFrame("Button", nil, Q.root)
        host:SetSize(200, 44)
        host:SetPoint("TOPLEFT", Q.root, "TOPLEFT", 20 + (i - 1) * 226, -348)
        local g = Q.ctlGlass.Apply(host, "large")
        if i > 1 then Q.ctlGlass.SetSurfaceRim(g, RED[1], RED[2], RED[3], 1) end
        label(text, g.top, name, 13, 16, -14)
        Q.controls[i] = { name = name, g = g, colour = i > 1 and "red" or "white" }
    end
    Q.root:Show()
    say("r9 board on LibGlass r" .. tostring(minor()))
    return r9State()
end

local function needR9() if not Q.root then buildR9() end; Q.root:Show() end

local function setShellEnabled(on)
    needR9()
    Q.shellGlass.SetSurfaceEnabled(Q.lib, on)
    return r9State()
end

local function setControlRim(a)
    needR9()
    Q.ctlGlass.SetRimAlpha(a)
    return r9State()
end

local function setControlEnabled(on)
    needR9()
    Q.ctlGlass.SetSurfaceEnabled(Q.controls[3].g, on)
    return r9State()
end

Probe:Command("r9", function() buildR9() end, "the r9 board, built fresh (/fp steps lg r9 walks it)")
Probe:Command("shell", function(args) setShellEnabled(args:lower() ~= "off") end,
    "on|off: the library shell enabled or disabled (its Reflect layers dim)")
Probe:Command("outline", function(args)
    local v = tonumber(args)
    if not v then say("outline 0.2..1 (SetRimAlpha on the r9 controls)") return end
    setControlRim(v)
end, "0.2..1: SetRimAlpha on the r9 controls (the red ones keep their own)")

-- The own-rim steps, shared by r9 and the shorter rim procedure.
local RIM_STEPS = {
    { text = "Below, on the black strip, the middle and right controls have a red rim (SetSurfaceRim). Is it clearly red, with the rim's shading (brighter along the top) still there, as on the white one?",
      ask = true },
    { text = "Fade the controls' outline to 0.2 (SetRimAlpha, the instance-wide tune).", button = "Outline 0.2",
      run = function() return setControlRim(0.2) end, screenshot = "r9: outline 0.2" },
    { text = "Did only the left (white) control's rim fade? The two red rims have their own alpha and should not change.",
      ask = true },
    { text = "Disable the right control.", button = "Disable right",
      run = function() return setControlEnabled(false) end, screenshot = "r9: right control disabled" },
    { text = "Is the right control's red rim (and its body) dimmer than the middle one's?", ask = true },
    { text = "Enable it again.", button = "Enable right", run = function() return setControlEnabled(true) end },
    { text = "Is it back to the same red as the middle one?", ask = true },
    { text = "That's all. Press Finish, then type /reload so the results and screenshots are saved." },
}

local VERSION_STEP = {
    text = "Checking which copy of LibGlass is running.", auto = true, run = report,
    check = function()
        local m = minor()
        return type(m) == "number" and m >= 9, "LibGlass r" .. tostring(m)
    end,
}

local function procedure(head)
    local t = {}
    for k, v in pairs(head) do t[k] = v end
    for _, step in ipairs(RIM_STEPS) do t[#t + 1] = step end
    return t
end

Probe:Steps("r9", procedure({
    title = "LibGlass r9: reflective shell, own rims",
    rev = 2,
    VERSION_STEP,
    { text = "Open the board. Two window shells: the left one built by the library (Reflect), the right one by hand from the styling recipe. Below, three controls on a black strip. Drag the board by its header so this panel doesn't cover it, ideally over detailed scenery.",
      button = "Show board", run = buildR9, screenshot = "r9: the board" },
    { text = "Do the two shells look the same: the rim brighter along the top and fading down the sides, the fine top line bright on the left, the soft glow behind the header text? Note any difference, however small.",
      ask = true },
    { text = "Disable the left shell (SetSurfaceEnabled).", button = "Disable left",
      run = function() return setShellEnabled(false) end, screenshot = "r9: left shell disabled" },
    { text = "Is the left shell's light (top rim, top line, header glow) now clearly fainter than the right one's?",
      ask = true },
    { text = "Enable it again.", button = "Enable left", run = function() return setShellEnabled(true) end },
    { text = "Does the left shell match the right one again?", ask = true },
}))

-- The own-rim part of r9 alone, on a fresh board (the first r9 run's small
-- gold rims were too faint to judge).
Probe:Steps("rim", procedure({
    title = "LibGlass r9: own rims (SetSurfaceRim)",
    rev = 1,
    VERSION_STEP,
    { text = "Open the r9 board, built fresh. Drag it by its header so this panel doesn't cover the three controls on the black strip.",
      button = "Show board", run = buildR9, screenshot = "rim: the controls" },
}))

-- What Pearl.lua (loaded next) shares; it adds its boards' hides to NS.hides.
NS.Probe, NS.say, NS.label, NS.board, NS.stripes, NS.report, NS.minor = Probe, say, label, board, stripes, report, minor
NS.hides = {}

local boot = CreateFrame("Frame")
Probe:RegisterEvents(boot, { "ADDON_LOADED" })
boot:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON then return end
    Probe:Ready()
    if type(LibGlassProbeDB) ~= "table" then LibGlassProbeDB = {} end
    if type(LibGlassProbeDB.log) ~= "table" then LibGlassProbeDB.log = {} end
    Probe:UseLog(LibGlassProbeDB.log, MAX_LOG)
    LibGlassProbeDB.loads = (LibGlassProbeDB.loads or 0) + 1
    say("loaded (" .. LibGlassProbeDB.loads .. " loads), LibGlass r" .. tostring(minor())
        .. ". /fp lg for the commands, /fp steps lg repaint and /fp steps lg pearl for #64")
end)

NS._test = { Probe = Probe, C = C, R = R, buildR7 = buildR7, setWash = setWash, setDisabled = setDisabled,
             setEdge = setEdge, strongGlow = strongGlow, setBackdrop = setBackdrop, readStrip = readStrip,
             state = state, F = F, buildFill = buildFill, fillState = fillState, startTimer = startTimer,
             P = P, buildPreview = buildPreview, Q = Q, buildR9 = buildR9, r9State = r9State }
