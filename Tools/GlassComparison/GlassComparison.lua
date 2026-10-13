-- Standalone visual experiment. Only this addon's instances/regions are tuned.
-- No unit queries, secure templates, SavedVariables, or continuous updates.
local root, glass, columns
local surfaces, bars = {}, {}
local smokeAlpha, fillValue = 0.24, 3
local selected, rotation = "all", 0
local variants = {
    { key = "a", title = "A  Current track", note = "Empty-track colour: 0.75", track = 0.75 },
    { key = "b", title = "B  Reduced track", note = "Empty-track colour: 0.20", track = 0.20 },
    { key = "c", title = "C  Neutral track", note = "Empty-track colour: off", track = 0 },
}

local function say(message) print("|cff7fd4ffLibGlass probe:|r " .. message) end

local function label(parent, text, size, x, y)
    local fs = glass.Font(parent, size, "LEFT")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function surface(host, variant, small)
    local g = variant.glass.Apply(host, small and "small" or "large")
    surfaces[#surfaces + 1] = { g = g, glass = variant.glass }
    return g
end

local function sample(parent, variant, y, height, small)
    local host = CreateFrame("Frame", nil, parent)
    host:SetSize(280, height)
    host:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    return host, surface(host, variant, small)
end

local function layout()
    root:SetWidth(selected == "all" and 940 or 320)
    for i, column in ipairs(columns) do
        column:ClearAllPoints()
        local slot = selected == "all" and ((i - 1 + rotation) % #variants) or 0
        column:SetPoint("TOPLEFT", root, "TOPLEFT", 20 + slot * 310, -82)
        column:SetShown(selected == "all" or selected == variants[i].key)
    end
end

local function build()
    glass = LibStub("LibGlass-1.0"):New()
    root = CreateFrame("Frame", "LibGlassComparisonFrame", UIParent)
    root:SetSize(940, 410)
    root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    root:SetFrameStrata("DIALOG")
    root:SetClampedToScreen(true)
    root:SetMovable(true)

    -- Only the header catches the mouse; the open comparison area shows the world.
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
    label(header, "Glass probe 4  |  Drag here", 14, 12, -9)
    label(header, "/lgprobe a | b | c | next | all", 12, 12, -32)
    local close = CreateFrame("Button", nil, header)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -4, -4)
    label(close, "X", 14, 7, -4)
    close:SetScript("OnClick", function() root:Hide() end)

    columns = {}
    for i, variant in ipairs(variants) do
        variant.glass = LibStub("LibGlass-1.0"):New({ preset = "clean", bodyAlpha = smokeAlpha })
        variant.glass.SetTrackAlpha(variant.track)
        local column = CreateFrame("Frame", nil, root)
        column:SetSize(280, 320)
        columns[i] = column
        label(column, variant.title, 16, 0, 0)
        label(column, variant.note, 12, 0, -22)

        local panel, pg = sample(column, variant, -52, 104, false)
        label(pg.top, "Reading panel", 14, 16, -14)
        label(pg.top, "Watch the scenery through the center.", 12, 16, -40)
        label(pg.top, "Move the camera; check text contrast.", 12, 16, -61)
        label(pg.top, "Same rims, wash and shadow strength.", 12, 16, -80)

        local unit, ug = sample(column, variant, -185, 64, false)
        label(ug.top, "Sample unit", 13, 12, -8)
        local bar = variant.glass.Bar(unit, 22)
        bar:SetPoint("TOPLEFT", unit, "TOPLEFT", 12, -30)
        bar:SetWidth(256)
        bar:SetFrameLevel(glass.ContentLevel(unit))
        bar:SetStatusBarColor(0.22, 0.72, 0.42)
        variant.glass.SetBar(bar, 100, fillValue, true)
        local value = label(ug.top, fillValue .. " / 100", 12, 112, -34)
        bars[#bars + 1] = { bar = bar, text = value, glass = variant.glass }

        local button = CreateFrame("Button", nil, column)
        button:SetSize(112, 28)
        button:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -279)
        local buttonGlass = surface(button, variant, true)
        label(buttonGlass.top, "Small control", 12, 16, -7)
        label(column, "28 px tall", 12, 130, -287)
    end
    layout()
end

local function show(mode)
    if not root then build() end
    if mode then selected = mode end
    layout()
    root:Show()
end

SLASH_LIBGLASSCOMPARISON1 = "/lgprobe"
SlashCmdList.LIBGLASSCOMPARISON = function(message)
    local command, arg = message:lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "" or command == "all" or command == "a" or command == "b" or command == "c" then
        show(command == "" and selected or command)
    elseif command == "next" then
        local nextKey = { all = "a", a = "b", b = "c", c = "a" }
        show(nextKey[selected])
    elseif command == "hide" then
        if root then root:Hide() end
    elseif command == "rotate" then
        rotation = (rotation + 1) % #variants
        show("all")
    elseif command == "smoke" then
        local value = tonumber(arg)
        if not value or value < 0 or value > 1 then say("Use /lgprobe smoke 0..1 (all variants, default 0.24).") return end
        smokeAlpha = value
        show()
        for _, entry in ipairs(surfaces) do entry.glass.SetSurfaceTint(entry.g, nil, nil, nil, value) end
        say("All variants: body alpha " .. value .. ".")
    elseif command == "value" then
        local value = tonumber(arg)
        if not value or value < 0 or value > 100 then say("Use /lgprobe value 0..100.") return end
        fillValue = value
        show()
        for _, entry in ipairs(bars) do
            entry.glass.SetBar(entry.bar, 100, value, true)
            entry.text:SetText(value .. " / 100")
        end
    elseif command == "report" then
        show()
        local _, minor = LibStub:GetLibrary("LibGlass-1.0")
        say("Probe 4; library r" .. minor .. "; UI scale " .. root:GetEffectiveScale()
            .. "; view " .. selected .. "; shared body alpha " .. smokeAlpha .. "; fill " .. fillValue .. "%.")
        say("All: grain 0, gloss 0.25, shade 0.15; track alpha A: 0.75, B: 0.20, C: 0.")
    else
        say("a / b / c: same-position view; next: cycle; all: side by side; rotate: swap columns; hide: close.")
        say("smoke 0..1: all bodies (default 0.24; try 0.50 or 0.80); value 0..100: fake health; report: settings.")
        say("Drag the header. /reload resets the probe. No motion or hover effect in this comparison.")
    end
end

say("Probe 4 ready. /lgprobe to open; /lgprobe help for comparisons.")
