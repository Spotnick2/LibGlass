-- Pearl.lua: the Pearl preset's two probe procedures (#64), on LibGlassProbe's
-- helpers (NS, from LibGlassProbe.lua).
--
-- repaint: in the owner's screenshots the live player bar looked whiter and
--   more opaque than the probe's sample A. The hypothesis, not yet measured:
--   the client's SetStatusBarColor drops the fill's gradient, where its
--   opacity lives (r8, #53), and OnBarColor skips an unchanged colour, so the
--   gradient is never painted back. Six bars, one instance each (a setter
--   repaints every bar of its instance, so one bar's repair can't touch
--   another's), each started the same way, then driven frame by frame:
--   colour once; the same colour every frame; alternating, then restored;
--   as the second, then repaired; values only; SetBar then the same colour,
--   as GlassUnitFrames' painters do. GetAlpha proves nothing on a gradient
--   (#53): the screenshots are the evidence. Then a sample beside the live
--   GlassUnitFrames player bar, with its STYLE, read only.
--                                            /fp steps lg repaint walks it
-- pearl: baseline A, run #186's column A (the consumers' clean + clear,
--   which is New({ preset = "clean" })), and candidate P, A plus lighting
--   deltas, at the same position. One layer per round. The fill keeps
--   bar_fill (its rounded shading) and the class colours stay the client's.
--                                            /fp steps lg pearl walks it
-- r11: the released recipe, New({ preset = "pearl" }), beside P as the owner
--   chose it (run #192); then the repaint program and the live sample again,
--   on r11's OnBarColor.                     /fp steps lg r11 walks it
--
-- Bars bound to the player's own health and power get secret values: they go
-- straight into SetBar, and nothing here reads, compares or prints them.

local _, NS = ...
local Probe, say, label, board, stripes, report, minor, winner = NS.Probe, NS.say, NS.label, NS.board,
    NS.stripes, NS.report, NS.minor, NS.winner

local WHITE = { 1, 1, 1 }              -- priest: the client's class colour
local HUNTER = { 0.67, 0.83, 0.45 }
local WARLOCK = { 0.53, 0.53, 0.93 }
local PET = { 0.3, 0.85, 0.4 }
local MANA = { 0.16, 0.56, 1 }
local GOLD = { 0.92, 0.76, 0.22 }
local QUIET_TRACK = 0.25               -- GlassUnitFrames' empty-part strength (its Frames.lua:88)
local FRAMES = 20                      -- the repaint program's length, in rendered frames

local function colour(bar, c) bar:SetStatusBarColor(c[1], c[2], c[3]) end
local function colourName(c) return c == WHITE and "white" or c == HUNTER and "hunter" or "other" end

-- Baseline A: run #186's column A, logged there as wash .18, gloss .25, shade
-- .15, frost .10, fill .6, rim .7, track 0, thin rims, body .24: exactly the
-- clean preset over the defaults. Frozen here, never copied from a consumer.
local function newA(style)
    return LibStub("LibGlass-1.0"):New({ preset = "clean", style = style })
end

-- A plain deep copy (STYLE holds numbers, booleans and the tint table).
local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and copy(v) or v end
    return out
end

-- The STYLE keys the material's lighting lives in, for the log.
local LIGHTING = { "wash", "gloss", "frost", "innerShadow", "rimAlpha", "fillAlpha", "trackTop", "grain",
                   "shadowAlpha", "thinRim", "bodyAlpha" }
local function lighting(st)
    local parts = {}
    for _, k in ipairs(LIGHTING) do parts[#parts + 1] = k .. "=" .. Probe.Show(st[k], true) end
    return table.concat(parts, " ")
end

--------------------------------------------------------------------------------
-- Live bars: the player's own health and power, painted the way
-- GlassUnitFrames' painters do (SetBar, then the colour, on every event).
--------------------------------------------------------------------------------

local LIVE = { bound = {}, events = 0 }
local SOURCES = {
    health = { "UnitHealthMax", "UnitHealth" },
    power = { "UnitPowerMax", "UnitPower" },
}
local EVENTS = {
    UNIT_HEALTH = "health", UNIT_MAXHEALTH = "health",
    UNIT_POWER_UPDATE = "power", UNIT_MAXPOWER = "power", UNIT_DISPLAYPOWER = "power",
}

-- One entry: { bar, glass (nil for a plain overlay bar), kind, colour, owner }.
local function paintLive(e)
    local src = SOURCES[e.kind]
    local maxFn, curFn = rawget(_G, src[1]), rawget(_G, src[2])
    if not (maxFn and curFn) then return false end
    local mx, cur = maxFn("player"), curFn("player")   -- may be secret: passed on, never read
    if e.glass then
        e.glass.SetBar(e.bar, mx, cur)
    else
        e.bar:SetMinMaxValues(0, mx)
        e.bar:SetValue(cur)
    end
    if e.colour then colour(e.bar, e.colour) end
    return true
end

local liveFrame = CreateFrame("Frame")
liveFrame:SetScript("OnEvent", function(_, event, unit)
    local kind = EVENTS[event]
    if unit ~= "player" or not kind then return end
    LIVE.events = LIVE.events + 1
    for _, e in ipairs(LIVE.bound) do
        if e.kind == kind then Probe:Try("live " .. kind, paintLive, e) end
    end
end)

local function liveBind(entries)
    if not LIVE.registered then
        local list = {}
        for event in pairs(EVENTS) do list[#list + 1] = event end
        table.sort(list)
        LIVE.registered = Probe:RegisterEvents(liveFrame, list)
    end
    local painted = 0
    for _, e in ipairs(entries) do
        LIVE.bound[#LIVE.bound + 1] = e
        if paintLive(e) then painted = painted + 1 end
    end
    if painted < #entries then say("live: no UnitHealth/UnitPower on this client; the bars keep their values") end
    return painted
end

local function liveUnbind(owner)
    local keep = {}
    for _, e in ipairs(LIVE.bound) do
        if e.owner ~= owner then keep[#keep + 1] = e end
    end
    LIVE.bound = keep
end

--------------------------------------------------------------------------------
-- repaint: does a fill keep its gradient through repeated colour calls?
--------------------------------------------------------------------------------

local RP = { rows = {}, colour = WHITE }
local LV = {}   -- the sample beside the live GlassUnitFrames player bar

local VARIANTS = {
    { key = "1", text = "1  coloured once" },
    { key = "2", text = "2  the same colour, every frame" },
    { key = "3", text = "3  alternating, then restored" },
    { key = "4", text = "4  as 2, then repaired" },
    { key = "5", text = "5  values only (eased SetBar)" },
    { key = "6", text = "6  SetBar, then the same colour" },
}

-- What each bar gets on frame i of the program (`last` on the final one).
local ACTIONS = {
    ["1"] = function() end,
    ["2"] = function(row) colour(row.bar, RP.colour) end,
    ["3"] = function(row, i, last)
        local other = RP.colour == WHITE and HUNTER or WHITE
        colour(row.bar, (last or i % 2 == 0) and RP.colour or other)
    end,
    ["4"] = function(row) colour(row.bar, RP.colour) end,
    ["5"] = function(row, i, last) row.glass.SetBar(row.bar, 100, last and 60 or (i % 2 == 0 and 55 or 65)) end,
    ["6"] = function(row, i, last)
        row.glass.SetBar(row.bar, 100, last and 60 or (i % 2 == 0 and 58 or 62))
        colour(row.bar, RP.colour)
    end,
}

-- What a region's getters say, each secret-checked by Probe.Show before it is
-- formatted: the fill's identity against the one built, its texture (an ID
-- here, not a path), its vertex colour, and the bar's recorded colour.
local function fillLine(name, bar, builtFill)
    local fill = bar:GetStatusBarTexture()
    local okT, tex = Probe:Try("GetTexture " .. name, fill.GetTexture, fill)
    local okV, r, g, b, a = Probe:Try("GetVertexColor " .. name, fill.GetVertexColor, fill)
    local c = bar.trackColor
    local same = builtFill == nil and "" or (fill == builtFill and " same fill" or " NEW fill")
    return name .. same .. " tex " .. Probe.Show(okT and tex)
        .. " vertex " .. (okV and (Probe.Show(r) .. "," .. Probe.Show(g) .. "," .. Probe.Show(b) .. ","
            .. Probe.Show(a)) or "?")
        .. " trackColor " .. (type(c) == "table" and (Probe.Show(c[1]) .. "," .. Probe.Show(c[2]) .. ","
            .. Probe.Show(c[3]) .. "," .. Probe.Show(c[4])) or "nil")
end

local function repaintState()
    local parts = {}
    for _, row in ipairs(RP.rows) do parts[#parts + 1] = fillLine(row.key, row.bar, row.fill) end
    local line = "frame " .. tostring(RP.frame) .. "; " .. table.concat(parts, "; ")
    say("repaint: " .. line)
    return line
end

local function setStripes(on)
    for _, row in ipairs(RP.rows) do
        for _, t in ipairs(row.strip) do t:SetShown(on) end
    end
    say("repaint: " .. (on and "stripes behind the bars" or "no stripes: the scenery shows"))
    return on
end

-- Built fresh each time: new instances, every bar started the same way.
local function buildRepaint(c)
    if RP.root then RP.root:Hide() end
    RP.driver = RP.driver or CreateFrame("Frame")
    RP.driver:SetScript("OnUpdate", nil)
    local text = LibStub("LibGlass-1.0"):New()
    RP.colour, RP.rows, RP.frame, RP.done = c or RP.colour, {}, 0, false
    RP.root = board(text, 660, 540, "LibGlass #64: a fill through repeated colours",
        "Six bars, one instance each, stripes behind. /fp steps lg repaint walks it")
    for i, v in ipairs(VARIANTS) do
        local y = -84 - (i - 1) * 74
        label(text, RP.root, v.text, 13, 20, y)
        local host = CreateFrame("Frame", nil, RP.root)
        host:SetSize(300, 30)
        host:SetPoint("TOPLEFT", RP.root, "TOPLEFT", 330, y + 6)
        local strip = stripes(host, 300, 30)
        local glass = newA()
        local bar = glass.Bar(host, 22)
        bar:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -4)
        bar:SetWidth(300)
        bar.trackClip:SetAlpha(QUIET_TRACK)
        glass.SetBar(bar, 100, 60, true)
        colour(bar, RP.colour)
        RP.rows[i] = { key = v.key, glass = glass, bar = bar, fill = bar:GetStatusBarTexture(), strip = strip }
    end
    RP.root:Show()
    say("repaint board on LibGlass r" .. tostring(minor()) .. ", colour " .. colourName(RP.colour)
        .. "; each instance: " .. lighting(RP.rows[1].glass.STYLE))
    return repaintState()
end

local function needRepaint() if not RP.root then buildRepaint() end; RP.root:Show() end

-- The program: FRAMES rendered frames, each bar's action once per frame.
local function startProgram()
    needRepaint()
    RP.frame, RP.done = 0, false
    RP.driver:SetScript("OnUpdate", function(self)
        RP.frame = RP.frame + 1
        local last = RP.frame >= FRAMES
        for _, row in ipairs(RP.rows) do ACTIONS[row.key](row, RP.frame, last) end
        if last then
            self:SetScript("OnUpdate", nil)
            RP.done = true
            repaintState()
        end
    end)
    say("repaint: " .. FRAMES .. "-frame program started, colour " .. colourName(RP.colour))
    return "started"
end

-- Bar 4's own instance repaints its fill (SetFillAlpha at the value it has).
local function repairFour()
    needRepaint()
    local row = RP.rows[4]
    row.glass.SetFillAlpha(row.glass.STYLE.fillAlpha)
    say("repaint: bar 4 repaired (its instance's SetFillAlpha)")
    return repaintState()
end

-- The live comparison. GlassUnitFrames' player frame, read only: nothing of
-- it is called but getters, and the sample anchors to it, never the reverse.
local function gufPlayer()
    local guf = rawget(_G, "GlassUF")
    local frames = type(guf) == "table" and guf.Frames
    local b = type(frames) == "table" and type(frames.byUnit) == "table" and frames.byUnit.player
    if type(b) == "table" and type(b.health) == "table" then return guf, b end
end

local function shownLine(name, w)
    if type(w) ~= "table" then return name .. " none" end
    local okS, shown = Probe:Try(name .. " IsShown", w.IsShown, w)
    local okA, a = Probe:Try(name .. " GetAlpha", w.GetAlpha, w)
    return name .. " shown " .. Probe.Show(okS and shown) .. " alpha " .. Probe.Show(okA and a)
end

local function liveState()
    local guf, b = gufPlayer()
    local parts = {}
    if guf then
        local st = type(guf.Glass) == "table" and guf.Glass.STYLE
        parts[#parts + 1] = "GlassUnitFrames look " .. Probe.Show(guf.look, true) .. " body "
            .. Probe.Show(guf.body, true) .. "; its STYLE " .. (type(st) == "table" and lighting(st) or "?")
        parts[#parts + 1] = fillLine("live", b.health)
        parts[#parts + 1] = shownLine("live trackClip", b.health.trackClip)
        parts[#parts + 1] = shownLine("live loss", b.lossBar)
        parts[#parts + 1] = shownLine("live heal", b.healPred)
    else
        parts[#parts + 1] = "GlassUnitFrames' player frame isn't loaded"
    end
    if LV.bar then
        parts[#parts + 1] = fillLine("sample", LV.bar, LV.fill)
        parts[#parts + 1] = "overlays " .. (LV.overlays and "on" or "off")
    end
    parts[#parts + 1] = "LibGlass r" .. tostring(minor()) .. ", " .. LIVE.events .. " unit events so far"
    local line = table.concat(parts, "; ")
    say("live: " .. line)
    return line
end

-- GlassUnitFrames' overlayBar (its Frames.lua): a plain StatusBar with the
-- library's fill texture, its alpha on the frame, masked to the base bar.
local function overlayBar(glass, base, c, level, fromEdge)
    local clip = CreateFrame("Frame", nil, base)
    if fromEdge then
        clip:SetPoint("TOPLEFT", base:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
        clip:SetPoint("BOTTOMRIGHT", base, "BOTTOMRIGHT", 0, 0)
    else
        clip:SetAllPoints(base)
    end
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(base:GetFrameLevel() + level)
    local bar = CreateFrame("StatusBar", nil, clip)
    bar:SetFrameLevel(clip:GetFrameLevel())
    bar:SetStatusBarTexture(glass.MEDIA .. "bar_fill")
    bar:SetStatusBarColor(c[1], c[2], c[3])
    bar:SetAlpha(c[4])
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:GetStatusBarTexture():AddMaskTexture(glass.Mask(bar, "bar_mask", 8, 0, base))
    bar:SetAllPoints(base)
    return clip, bar
end

local LOSS_COLOR = { 1.00, 0.55, 0.50, 0.90 }   -- GlassUnitFrames' health loss
local HEAL_COLOR = { 0.35, 0.95, 0.55, 0.45 }   -- and incoming heals

local function plainColour(c)
    if type(c) ~= "table" then return nil end
    for i = 1, 3 do
        if Probe.Shape(c[i]) ~= "number" then return nil end
    end
    return { c[1], c[2], c[3] }
end

-- A sample bar on the live player bar's STYLE (a copy), with its quiet track,
-- bound to the player's health and recoloured on every event as the live bar
-- is, and the same two overlays, off until asked for.
local function buildLive()
    if LV.root then LV.root:Hide() end
    liveUnbind("live")
    local guf, b = gufPlayer()
    local st = guf and type(guf.Glass) == "table" and type(guf.Glass.STYLE) == "table" and guf.Glass.STYLE
    local glass = st and LibStub("LibGlass-1.0"):New({ style = copy(st) }) or newA()
    local w = b and b.health:GetWidth()
    local h = b and b.health:GetHeight()
    if Probe.Shape(w) ~= "number" or not (w > 0) then w = 260 end
    if Probe.Shape(h) ~= "number" or not (h > 0) then h = 22 end
    local inset = glass.Inset("large")
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetSize(w + 2 * inset, h + 2 * inset)
    if b then
        root:SetPoint("TOPLEFT", b.health, "BOTTOMLEFT", -inset, -48)
    else
        root:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    end
    glass.Apply(root, "large")
    local bar = glass.Bar(root, h)
    bar:SetPoint("TOPLEFT", root, "TOPLEFT", inset, -inset)
    bar:SetWidth(w)
    bar:SetFrameLevel(glass.ContentLevel(root))
    bar.trackClip:SetAlpha(QUIET_TRACK)
    local c = (b and plainColour(b.health.trackColor)) or WHITE
    local lossClip, loss = overlayBar(glass, bar, LOSS_COLOR, 2, true)
    local healClip, heal = overlayBar(glass, bar, HEAL_COLOR, 3, false)
    lossClip:Hide()
    healClip:Hide()
    LV.root, LV.glass, LV.bar, LV.fill, LV.overlays = root, glass, bar, bar:GetStatusBarTexture(), false
    LV.lossClip, LV.healClip = lossClip, healClip
    liveBind({ { bar = bar, glass = glass, kind = "health", colour = c, owner = "live" },
               { bar = loss, kind = "health", owner = "live" } })
    root:Show()
    say("live: sample beside " .. (b and "GlassUnitFrames' player bar" or "nothing (GlassUnitFrames isn't loaded)")
        .. ", colour " .. Probe.Show(c[1]) .. "," .. Probe.Show(c[2]) .. "," .. Probe.Show(c[3]))
    return liveState()
end

local function needLive() if not LV.root then buildLive() end; LV.root:Show() end

local function repairLive()
    needLive()
    LV.glass.SetFillAlpha(LV.glass.STYLE.fillAlpha)
    say("live: sample repaired (its instance's SetFillAlpha)")
    return liveState()
end

local function setOverlays(on)
    needLive()
    LV.overlays = on
    LV.lossClip:SetShown(on)
    LV.healClip:SetShown(on)
    return liveState()
end

local function hideRepaint()
    if RP.root then RP.root:Hide() end
    if RP.driver then RP.driver:SetScript("OnUpdate", nil) end
    if LV.root then LV.root:Hide() end
    liveUnbind("live")
end

Probe:Command("repaint", function(args)
    local a, b = args:lower():match("^(%S*)%s*(%S*)")
    if a == "" or a == "white" or a == "hunter" then
        buildRepaint(a == "hunter" and HUNTER or (a == "white" and WHITE or nil))
    elseif a == "run" then startProgram()
    elseif a == "repair" then repairFour()
    elseif a == "stripes" and (b == "on" or b == "off") then needRepaint(); setStripes(b == "on")
    elseif a == "live" then buildLive()
    elseif a == "fix" then repairLive()
    elseif a == "overlays" and (b == "on" or b == "off") then setOverlays(b == "on")
    elseif a == "report" then
        if RP.root then repaintState() end
        liveState()
    else
        say("repaint [white|hunter] | run | repair | stripes on|off | live | fix | overlays on|off | report")
    end
end, "#64: six bars through repeated colour calls; live: a sample beside your player bar")

local function waitProgram()
    if RP.done then return true, repaintState() end
    return false, "frame " .. tostring(RP.frame) .. " of " .. FRAMES
end

Probe:Steps("repaint", {
    title = "LibGlass #64: does a fill survive a repeated colour?",
    rev = 1,
    { text = "Checking which copy of LibGlass is running.", auto = true, run = report,
      check = function()
          local m = minor()
          return type(m) == "number" and m >= 8, "LibGlass r" .. tostring(m)
      end },
    { text = "Open the board: six bars in priest white, each with its own LibGlass instance, over black and white stripes. Where a fill is see-through, the stripes show through it. Drag the board by its header so this panel doesn't cover it.",
      button = "Show board", run = function() return buildRepaint(WHITE) end, screenshot = "repaint: built" },
    { text = "Do the six bars look the same now, before anything else happens to them?", ask = true },
    { text = "Run the program: for 20 frames, each bar gets what its label says.", button = "Run 20 frames",
      run = startProgram },
    { text = "Waiting for the 20 frames.", wait = waitProgram, timeout = 10, screenshot = "repaint: after 20 frames" },
    { text = "Compared with bar 1, is bar 2 (the same colour again every frame) more opaque or whiter? (Less of the stripes shows through it.)",
      ask = true },
    { text = "Is bar 6 (SetBar, then the same colour, as GlassUnitFrames paints) more opaque or whiter than bar 1?", ask = true },
    { text = "Is bar 3 (alternating colours, then the white restored) more opaque or whiter than bar 1?", ask = true },
    { text = "Does bar 5 (values only, no colour call) look the same as bar 1?", ask = true },
    { text = "Repair bar 4: its own instance repaints its fill. Bar 4 got the same as bar 2 until now.",
      button = "Repair bar 4", run = repairFour, screenshot = "repaint: bar 4 repaired" },
    { text = "Does bar 4 now look like bar 1 (and no longer like bar 2)?", ask = true },
    { text = "Take the stripes away, so the scenery shows behind the bars. Bright scenery shows the difference best.",
      button = "Scenery", run = function() return setStripes(false) end, screenshot = "repaint: over the scenery" },
    { text = "Over the scenery, do bars 2, 3 and 6 still differ from bar 1 the same way?", ask = true },
    { text = "Again with a class colour: the board rebuilt in hunter green, then the same 20 frames.",
      button = "Hunter green", run = function() buildRepaint(HUNTER); return startProgram() end },
    { text = "Waiting for the 20 frames.", wait = waitProgram, timeout = 10, screenshot = "repaint: hunter, after 20 frames" },
    { text = "In green, do bars 2, 3 and 6 differ from bar 1 the way they did in white?", ask = true },
    { text = "Now your own GlassUnitFrames player frame. Out of combat, near full health, open a sample bar under it: its STYLE copied from GlassUnitFrames, its empty part as quiet, and recoloured on every health event, as the live bar is.",
      button = "Sample under player", run = buildLive, screenshot = "repaint: live bar and sample" },
    { text = "Does your live player bar look like the sample under it (same whiteness, same see-through)?", ask = true },
    { text = "Repair the sample (its own instance repaints its fill). Look right away, then take a little damage or wait for a health tick and look again.",
      button = "Repair sample", run = repairLive, screenshot = "repaint: sample repaired" },
    { text = "Right after the repair, was the sample less white or opaque than your live bar? And after a health event, did it go back?",
      ask = true },
    { text = "Show the sample's health-loss and incoming-heal overlays, built the way GlassUnitFrames builds them.",
      button = "Overlays on", run = function() return setOverlays(true) end, screenshot = "repaint: sample overlays on" },
    { text = "Did the overlays change how the sample looks at rest?", ask = true },
    { text = "Logging what the live bar and the sample report.", auto = true, run = liveState },
    { text = "That's all. Press Finish, then type /reload so the results and screenshots are saved." },
})

--------------------------------------------------------------------------------
-- pearl: baseline A beside candidate P, at the same position
--------------------------------------------------------------------------------

local PB = { view = "all", rotation = 0, value = 100, deltas = {}, entries = {} }
local KNOBS = { wash = "wash", gloss = "gloss", frost = "frost", shade = "innerShadow", rim = "rimAlpha" }
-- What the owner chose in run #192 (2026-10-18, 70450): every round kept.
local CHOSEN = { wash = 0.10, gloss = 0.15, frost = 0.06, rimAlpha = 0.6 }

local function pStyle()
    local st = {}
    for k, v in pairs(PB.deltas) do st[KNOBS[k]] = v end
    return st
end

local PEARL_COLUMNS = {
    { key = "a", title = "A  baseline", note = "clean + clear, as run #186", make = function() return newA() end },
    { key = "p", title = "P  candidate", make = function() return newA(pStyle()) end },
}
local R11_COLUMNS = {
    { key = "a", title = "Pearl  the preset", note = 'New({ preset = "pearl" })',
      make = function() return LibStub("LibGlass-1.0"):New({ preset = "pearl" }) end },
    { key = "p", title = "P  as chosen", note = "clean + wash .10, gloss .15, frost .06, rim .6",
      make = function() return newA(CHOSEN) end },
}
local COLUMNS = PEARL_COLUMNS
local CELLS = {
    { name = "Karuzo", c = WHITE },
    { name = "Kaleid", c = HUNTER },
    { name = "Drakuzo", c = WARLOCK },
    { name = "Pet", c = PET },
}

local function deltaText()
    local parts = {}
    for _, k in ipairs({ "wash", "gloss", "frost", "shade", "rim" }) do
        if PB.deltas[k] ~= nil then parts[#parts + 1] = k .. " " .. PB.deltas[k] end
    end
    return #parts > 0 and table.concat(parts, ", ") or "none (P = A)"
end

-- A bar on a sample surface. `kind`: health follows the level; power and
-- cast stay put. Unit bars get GlassUnitFrames' quiet track.
local function sampleBar(col, glass, host, w, h, x, y, c, kind, unit)
    local bar = glass.Bar(host, h)
    bar:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
    bar:SetWidth(w)
    bar:SetFrameLevel(glass.ContentLevel(host))
    if unit then bar.trackClip:SetAlpha(QUIET_TRACK) end
    glass.SetBar(bar, 100, kind == "health" and PB.value or (kind == "cast" and 58 or 62), true)
    colour(bar, c)
    col.entries[#col.entries + 1] = { bar = bar, glass = glass, kind = kind, colour = c, owner = "pearl" }
    return bar
end

local function surface(parent, glass, w, h, x, y, size)
    local host = CreateFrame("Frame", nil, parent)
    host:SetSize(w, h)
    host:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return host, glass.Apply(host, size)
end

local function buildColumn(spec, text)
    local glass = spec.make()
    local col = { key = spec.key, glass = glass, entries = {}, texts = {} }
    local f = CreateFrame("Frame", nil, PB.root)
    f:SetSize(344, 370)
    col.frame = f
    label(text, f, spec.title, 15, 0, 0)
    label(text, f, spec.note or ("deltas: " .. deltaText()), 11, 0, -20)

    local li, si = glass.Inset("large"), glass.Inset("small")
    local uf, ug = surface(f, glass, 300, 62, 0, -42, "large")
    local hh = math.floor((62 - 2 * li - 2) * 0.74)
    sampleBar(col, glass, uf, 300 - 2 * li, hh, li, -li, WHITE, "health", true)
    sampleBar(col, glass, uf, 300 - 2 * li, 62 - 2 * li - 2 - hh, li, -li - hh - 2, MANA, "power", true)
    label(text, ug.top, "Karuzo Mistwalker", 13, li + 6, -li - 5)
    col.texts[#col.texts + 1] = label(text, ug.top, "", 12, 240, -li - 5)

    for i, cell in ipairs(CELLS) do
        local host, cg = surface(f, glass, 80, 58, (i - 1) * 86, -112, "small")
        local ch = 58 - 2 * si - 6
        sampleBar(col, glass, host, 80 - 2 * si, ch, si, -si, cell.c, "health", false)
        sampleBar(col, glass, host, 80 - 2 * si, 5, si, -si - ch - 1, MANA, "power", false)
        label(text, cg.top, cell.name, 11, si + 4, -si - 4)
    end

    local cast, cgl = surface(f, glass, 300, 26, 0, -182, "small")
    sampleBar(col, glass, cast, 300 - 2 * si, 26 - 2 * si, si, -si, GOLD, "cast", true)
    label(text, cgl.top, "Lesser Heal", 11, si + 6, -si - 3)

    local small, sg = surface(f, glass, 180, 26, 0, -220, "small")
    sampleBar(col, glass, small, 180 - 2 * si, 26 - 2 * si, si, -si, WHITE, "health", true)
    label(text, sg.top, "Karuzo", 11, si + 6, -si - 3)
    return col
end

local function setValue(v)
    PB.value = v
    for _, col in ipairs(PB.cols or {}) do
        for _, e in ipairs(col.entries) do
            if e.kind == "health" and not PB.live then e.glass.SetBar(e.bar, 100, v, true) end
        end
        for _, t in ipairs(col.texts) do t:SetText(PB.live and "live" or (v .. "%")) end
    end
    say("pearl: health " .. v .. "% in both columns" .. (PB.live and " (the live bars keep yours)" or ""))
    return v
end

local function layout()
    local all = PB.view == "all"
    PB.root:SetWidth(all and 740 or 384)
    for i, col in ipairs(PB.cols) do
        col.frame:ClearAllPoints()
        local slot = all and ((i - 1 + PB.rotation) % #COLUMNS) or 0
        col.frame:SetPoint("TOPLEFT", PB.root, "TOPLEFT", 20 + slot * 360, -108)
        col.frame:SetShown(all or PB.view == col.key)
    end
end

local function pearlState()
    local line = "view " .. PB.view .. ", rotation " .. PB.rotation .. ", health " .. PB.value .. "%"
        .. (PB.live and " (live)" or "") .. "; P deltas: " .. deltaText()
    if PB.cols then
        line = line .. "; A: " .. lighting(PB.cols[1].glass.STYLE) .. "; P: " .. lighting(PB.cols[2].glass.STYLE)
    end
    say("pearl: " .. line)
    return line
end

-- The header buttons: health levels and views, for judging at one position.
local function headerButton(text, x, caption, fn)
    local b = CreateFrame("Button", nil, PB.root)
    b:SetSize(44, 22)
    b:SetPoint("TOPLEFT", PB.root, "TOPLEFT", x, -74)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetColorTexture(0.12, 0.14, 0.18, 0.95)
    label(text, b, caption, 12, 6, -4)
    b:SetScript("OnClick", fn)
    return b
end

local refreshColumns, setView, rotate

local function buildPearlBoard()
    local text = LibStub("LibGlass-1.0"):New()
    PB.text = text
    PB.root = board(text, 740, 490, "LibGlass #64: Pearl, A beside P",
        "Same position: /fp lg pearl a | p | next.  /fp steps lg pearl walks it")
    for i, lvl in ipairs({ 100, 30, 5, 0 }) do
        headerButton(text, 12 + (i - 1) * 50, lvl .. "%", function() setValue(lvl) end)
    end
    for i, v in ipairs({ "a", "p", "all" }) do
        headerButton(text, 230 + (i - 1) * 50, v:upper(), function() setView(v) end)
    end
    headerButton(text, 390, "Rot", function() rotate() end)
end

refreshColumns = function()
    if not PB.root then buildPearlBoard() end
    liveUnbind("pearl")
    for _, col in ipairs(PB.cols or {}) do col.frame:Hide() end
    PB.cols = {}
    for i, spec in ipairs(COLUMNS) do PB.cols[i] = buildColumn(spec, PB.text) end
    if PB.live then
        for _, col in ipairs(PB.cols) do
            local bound = {}
            for _, e in ipairs(col.entries) do
                if e.kind ~= "cast" then bound[#bound + 1] = e end
            end
            liveBind(bound)
        end
    end
    layout()
    setValue(PB.value)
    PB.root:Show()
    return pearlState()
end

local function needPearl() if not PB.cols then refreshColumns() end; PB.root:Show() end

setView = function(v)
    needPearl()
    PB.view = v
    layout()
    say("pearl: view " .. v)
    return v
end

rotate = function()
    needPearl()
    PB.rotation = (PB.rotation + 1) % #COLUMNS
    PB.view = "all"
    layout()
    say("pearl: rotation " .. PB.rotation)
    return PB.rotation
end

-- One lighting knob on P, or nil to give it A's value back. P is rebuilt.
local function setDelta(knob, v)
    PB.deltas[knob] = v
    return refreshColumns()
end

local function setLive(on)
    PB.live = on
    say("pearl: live bars " .. (on and "on: your own health and power" or "off"))
    return refreshColumns()
end

local function showPearl()
    COLUMNS = PEARL_COLUMNS
    PB.view, PB.value = "all", 100
    return refreshColumns()
end

-- The r11 board: the same samples, the preset beside the chosen P.
local function showR11()
    COLUMNS = R11_COLUMNS
    PB.view, PB.value = "all", 100
    return refreshColumns()
end

-- PASS when the preset's lighting is exactly the chosen recipe's.
local function sameRecipe()
    needPearl()
    local a, b = PB.cols[1].glass.STYLE, PB.cols[2].glass.STYLE
    for _, k in ipairs(LIGHTING) do
        if a[k] ~= b[k] then return false, k .. " differs: " .. Probe.Show(a[k], true) .. " vs " .. Probe.Show(b[k], true) end
    end
    return true, lighting(a)
end

Probe:Command("pearl", function(args)
    local a, b, c = args:lower():match("^(%S*)%s*(%S*)%s*(%S*)")
    local n = tonumber(b)
    if a == "" then showPearl()
    elseif a == "a" or a == "p" or a == "all" then setView(a)
    elseif a == "next" then setView(({ all = "a", a = "p", p = "a" })[PB.view] or "a")
    elseif a == "rotate" then rotate()
    elseif a == "value" and n and n >= 0 and n <= 100 then needPearl(); setValue(n)
    elseif a == "set" and KNOBS[b] and tonumber(c) and tonumber(c) >= 0 and tonumber(c) <= 1 then
        setDelta(b, tonumber(c))
    elseif a == "set" and KNOBS[b] and c == "off" then setDelta(b, nil)
    elseif a == "reset" then PB.deltas = {}; refreshColumns()
    elseif a == "live" and (b == "on" or b == "off") then setLive(b == "on")
    elseif a == "report" then needPearl(); pearlState()
    else
        say("pearl | a | p | all | next | rotate | value 0..100 | set wash|gloss|frost|shade|rim 0..1|off"
            .. " | reset | live on|off | report")
    end
end, "#64: baseline A beside candidate P (A plus lighting deltas), at the same position")

local function hidePearl()
    if PB.root then PB.root:Hide() end
    if PB.live then PB.live = false; liveUnbind("pearl") end
end

NS.hides[#NS.hides + 1] = hideRepaint
NS.hides[#NS.hides + 1] = hidePearl

-- One round per lighting layer: set it on P, look at full and very low
-- health, answer, and revert it if P didn't read better.
local ROUNDS = {
    { knob = "wash", from = 0.18, to = 0.10, what = "the body's top-down white wash" },
    { knob = "gloss", from = 0.25, to = 0.15, what = "the bright highlight on the bars" },
    { knob = "frost", from = 0.10, to = 0.06, what = "the white frost at the top of each bar" },
    { knob = "rim", from = 0.7, to = 0.6, what = "the glass outline (optional: skip all four steps to keep 0.7)" },
}

local steps = {
    title = "LibGlass #64: Pearl, A beside P",
    rev = 1,
    { text = "Checking which copy of LibGlass is running.", auto = true, run = report,
      check = function()
          local m = minor()
          return type(m) == "number" and m >= 8, "LibGlass r" .. tostring(m)
      end },
    { text = "Open the board: A (today's clean + clear) and P side by side, P identical to A for now. Unit frame, four raid cells, a cast bar, a small bar. The buttons under the header set the health and the view. Drag the board by its header.",
      button = "Show board", run = showPearl, screenshot = "pearl: A and P, unchanged" },
}
for r, round in ipairs(ROUNDS) do
    steps[#steps + 1] = { text = "Round " .. r .. ": P's " .. round.knob .. " " .. round.from .. " to " .. round.to
        .. ", " .. round.what .. ". Compare at the same position too: the A and P buttons swap them in place. Look over bright and dark scenery.",
        button = "Set " .. round.knob .. " " .. round.to,
        run = function() setDelta(round.knob, round.to); setView("all"); setValue(100); return pearlState() end,
        screenshot = "pearl: round " .. r .. ", 100%" }
    steps[#steps + 1] = { text = "Very low health: 5%.", button = "Health 5",
        run = function() needPearl(); return setValue(5) end, screenshot = "pearl: round " .. r .. ", 5%" }
    steps[#steps + 1] = { text = "Does P read better than A: a softer highlight, the depth kept, the class colours (priest white) and the health boundary still clear? Note what you see.",
        ask = true }
    steps[#steps + 1] = { text = "If you answered No, revert this change on P. Otherwise press Skip.",
        button = "Revert " .. round.knob, run = function() return setDelta(round.knob, nil) end }
end
local tail = {
    { text = "Low health: 30%.", button = "Health 30", run = function() needPearl(); return setValue(30) end,
      screenshot = "pearl: 30%" },
    { text = "Empty: 0%.", button = "Health 0", run = function() needPearl(); return setValue(0) end,
      screenshot = "pearl: 0%" },
    { text = "At 30% and at 0%, are remaining and missing health clearly told apart in P, on the unit frame and on the small raid cells?",
      ask = true },
    { text = "Swap the columns' positions, back at full health, to rule out the background deciding it.",
      button = "Rotate", run = function() rotate(); return setValue(100) end, screenshot = "pearl: rotated" },
    { text = "With the columns swapped, do you still prefer P?", ask = true },
    { text = "Bind the bars to your own health and mana. Take some damage, cast something (in combat is fine: nothing here is secure).",
      button = "Live bars", run = function() return setLive(true) end, screenshot = "pearl: live" },
    { text = "Do P's bars follow your health and mana smoothly, and stay as see-through as A's while they update?", ask = true },
    { text = "Back to the sample values.", button = "Live off", run = function() return setLive(false) end },
    { text = "Logging P's final settings.", auto = true, run = pearlState },
    { text = "That's all. Press Finish, then type /reload so the results and screenshots are saved." },
}
for _, s in ipairs(tail) do steps[#steps + 1] = s end
Probe:Steps("pearl", steps)

-- The check r11 is tagged on: the production code, not the probe's recipe.
Probe:Steps("r11", {
    title = "LibGlass r11: the Pearl preset and the repaint fix",
    rev = 2,
    { text = "Checking which copy of LibGlass is running: r11 or later, and this probe's own (another addon's copy of the same MINOR may win the tie).",
      auto = true, run = report,
      check = function()
          local m, host = minor(), winner()
          return type(m) == "number" and m >= 11 and host == "LibGlassProbe", "LibGlass r" .. tostring(m) .. " from " .. host
      end },
    { text = "Open the board: the library's Pearl preset on the left, P as you chose it on the right. Drag it by its header.",
      button = "Show board", run = showR11, screenshot = "r11: preset beside P", check = sameRecipe },
    { text = "Do the two columns look the same?", ask = true },
    { text = "Very low health: 5%.", button = "Health 5", run = function() needPearl(); return setValue(5) end,
      screenshot = "r11: 5%" },
    { text = "Bind the bars to your own health and mana, then take some damage or cast something.",
      button = "Live bars", run = function() return setLive(true) end, screenshot = "r11: live" },
    { text = "Do the Pearl bars follow your health and mana and stay see-through while they update?", ask = true },
    { text = "Back to the sample values, and close the board.", button = "Done with it",
      run = function() setLive(false); PB.root:Hide(); return "closed" end },
    { text = "The repaint program again, on r11: six bars in white, 20 frames.", button = "Run 20 frames",
      run = function() buildRepaint(WHITE); return startProgram() end },
    { text = "Waiting for the 20 frames.", wait = waitProgram, timeout = 10, screenshot = "r11: repaint after 20 frames" },
    { text = "Do all six bars look the same now (bars 2, 4 and 6 no longer more opaque or whiter than bar 1)?", ask = true },
    { text = "Your GlassUnitFrames player frame: the sample bar under it again, out of combat.",
      button = "Sample under player", run = function() RP.root:Hide(); return buildLive() end,
      screenshot = "r11: live bar and sample" },
    { text = "Does your live player bar now look like the sample under it (same see-through)?", ask = true },
    { text = "That's all. Press Finish, then type /reload so the results and screenshots are saved." },
})

NS._test = NS._test or {}
NS._test.Pearl = { RP = RP, LV = LV, PB = PB, LIVE = LIVE, buildRepaint = buildRepaint, startProgram = startProgram,
                   repairFour = repairFour, buildLive = buildLive, repairLive = repairLive, setOverlays = setOverlays,
                   showPearl = showPearl, setDelta = setDelta, setValue = setValue, setView = setView,
                   rotate = rotate, setLive = setLive, pearlState = pearlState, ROUNDS = ROUNDS, FRAMES = FRAMES,
                   showR11 = showR11, sameRecipe = sameRecipe, CHOSEN = CHOSEN }
