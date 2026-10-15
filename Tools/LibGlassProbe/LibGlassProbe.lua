-- LibGlassProbe: LibGlass's developer probe, a ForeverProbe module (/fp lg).
-- Its lines go to the ForeverProbe console and LibGlassProbeDB.log, never to
-- chat. It is never packaged: the library has no TOC of its own.
--
-- Two boards, each a plain frame holding glass built by the probe's own
-- instances (an instance's setters reach only the surfaces it built):
-- - compare: probe 4 (r6, #41). Three clean columns that differ only in the
--   empty-track colour.                      /fp lg show a|b|c|all, next, ...
-- - r7: the disabled look through the gradients, and SetWash (#47, #50).
--   Each surface beside a disabled copy, classic and clean, and a strip of
--   four gradients for the SetAlpha-before-SetGradient question.
--                                            /fp steps lg r7 walks it
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
end, "close both boards")
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
        .. ". /fp lg for the commands, /fp steps lg r7 for the r7 check")
end)

NS._test = { Probe = Probe, C = C, R = R, buildR7 = buildR7, setWash = setWash, setDisabled = setDisabled,
             setEdge = setEdge, strongGlow = strongGlow, setBackdrop = setBackdrop, readStrip = readStrip,
             state = state }
