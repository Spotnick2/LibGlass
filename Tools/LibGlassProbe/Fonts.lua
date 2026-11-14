-- Fonts.lua: the fonts-by-locale procedure (#69), on LibGlassProbe's helpers
-- (NS, from LibGlassProbe.lua).
--
-- fonts: r11 handed every client the Latin files (Arial Narrow, Friz
--   Quadrata); r12 hands a Russian, Korean or Chinese client its own font for
--   that script, as Blizzard's font families pick it. Font files are the same
--   on every client, so an English client can show what each language's
--   players would see. One row per language, its own text: r11's two files on
--   the left, r12's on the right (the library's own choice, through its
--   _test.fontsFor seam). The last row is an English client showing names in
--   four scripts: the plain files, beside a font family (CreateFontFamily)
--   with each script's file as a member, to see whether a family falls back
--   per character where a plain file doesn't. Text only: no glass, no events.
--                                            /fp steps lg fonts walks it

local _, NS = ...
local Probe, say, board, report, minor, winner = NS.Probe, NS.say, NS.board, NS.report, NS.minor, NS.winner

local SIZE = 15
local R11 = { arial = "Fonts\\ARIALN.TTF", friz = "Fonts\\FRIZQT__.TTF" }
local ROWS = {
    { locale = "enUS", text = "English: Health 100%" },
    { locale = "ruRU", text = "Русский: Здоровье 100%" },
    { locale = "koKR", text = "한국어: 생명력 100%" },
    { locale = "zhCN", text = "简体中文: 生命值 100%" },
    { locale = "zhTW", text = "繁體中文: 生命值 100%" },
}
local MIXED = "Thrall Артас 상현 李明"
-- Blizzard's member names (Blizzard_Fonts_Shared's alphabet= attributes).
local ALPHABETS = {
    { alphabet = "roman", locale = "enUS" },
    { alphabet = "russian", locale = "ruRU" },
    { alphabet = "korean", locale = "koKR" },
    { alphabet = "simplifiedchinese", locale = "zhCN" },
    { alphabet = "traditionalchinese", locale = "zhTW" },
}
local COLUMNS = { "r11 arial", "r11 friz", "r12 arial", "r12 friz" }
local FIRST, WIDTH, HEIGHT = 150, 190, 34

local FB = { cells = {}, families = {} }

local function fontsFor(locale)
    local lib = LibStub("LibGlass-1.0")
    local seam = lib._test and lib._test.fontsFor
    return seam and seam(locale)
end

-- A family per key: each script's r12 file as its member. Kept: a family is a
-- named global font object, made once per session.
local function family(key)
    if FB.families[key] ~= nil then return FB.families[key] or nil, FB.familyError end
    local create = rawget(_G, "CreateFontFamily")
    if not create then FB.families[key] = false; FB.familyError = "no CreateFontFamily"; return nil, FB.familyError end
    local members = {}
    for _, a in ipairs(ALPHABETS) do
        members[#members + 1] = { alphabet = a.alphabet, file = fontsFor(a.locale)[key].file, height = SIZE, flags = "" }
    end
    local ok, fam = pcall(create, "LibGlassProbeFont_" .. key, members)
    if not ok or not fam then
        FB.families[key] = false
        FB.familyError = tostring(fam)
        return nil, FB.familyError
    end
    FB.families[key] = fam
    return fam
end

local function text(parent, s, x, y, colour)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetTextColor(colour or 1, colour or 1, colour or 1)
    return fs, s
end

-- One cell: `s` in `file` (or in a family font object). Logs what the client
-- answered: SetFont's success and the file GetFont reads back.
local function cell(parent, row, col, s, file, fam, name)
    local fs = text(parent, s, FIRST + (col - 1) * WIDTH, -(row - 1) * HEIGHT)
    local ok
    if fam then fs:SetFontObject(fam); ok = true else ok = fs:SetFont(file, SIZE, "") end
    fs:SetText(s)
    local got = fs:GetFont()
    FB.cells[#FB.cells + 1] = { fs = fs, name = name, file = file, ok = ok, got = got }
    if not ok then FB.failed[#FB.failed + 1] = name .. " (" .. tostring(file) .. ")" end
    return fs
end

local function buildFonts()
    if FB.root then FB.root:Hide() end
    if not fontsFor("enUS") then
        say("fonts: the running LibGlass r" .. tostring(minor()) .. " has no fontsFor (r12 or later, from " .. winner() .. ")")
        return false, "LibGlass r" .. tostring(minor()) .. " has no fontsFor"
    end
    FB.cells, FB.failed = {}, {}
    local glass = LibStub("LibGlass-1.0"):New()
    local w = FIRST + #COLUMNS * WIDTH + 30
    local h = 64 + 30 + (#ROWS + 2) * HEIGHT + 30
    FB.root = board(glass, w, h, "LibGlass #69: fonts by locale",
        "Each language's own text: r11's files left, r12's right. Last row: names in four scripts on this client.")
    local bg = FB.root:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", FB.root, "TOPLEFT", 0, -64)
    bg:SetPoint("BOTTOMRIGHT", FB.root, "BOTTOMRIGHT")
    bg:SetColorTexture(0.06, 0.07, 0.09, 0.96)
    local grid = CreateFrame("Frame", nil, FB.root)
    grid:SetPoint("TOPLEFT", FB.root, "TOPLEFT", 15, -82)
    grid:SetSize(w - 30, h - 100)

    local function head(s, x, y)
        local fs = text(grid, s, x, y, 0.7)
        fs:SetFont(R11.arial, 13, "")
        fs:SetText(s)
    end
    for c, name in ipairs(COLUMNS) do head(name, FIRST + (c - 1) * WIDTH, 0) end
    for r, row in ipairs(ROWS) do
        local y = r + 1
        head(row.locale .. " client", 0, -(y - 1) * HEIGHT)
        local now = fontsFor(row.locale)
        cell(grid, y, 1, row.text, R11.arial, nil, row.locale .. " r11 arial")
        cell(grid, y, 2, row.text, R11.friz, nil, row.locale .. " r11 friz")
        cell(grid, y, 3, row.text, now.arial.file, nil, row.locale .. " r12 arial")
        cell(grid, y, 4, row.text, now.friz.file, nil, row.locale .. " r12 friz")
    end
    local y = #ROWS + 2
    head("this client, names", 0, -(y - 1) * HEIGHT)
    cell(grid, y, 1, MIXED, R11.arial, nil, "names plain arial")
    cell(grid, y, 2, MIXED, R11.friz, nil, "names plain friz")
    local famA, errA = family("arial")
    local famF, errF = family("friz")
    if famA then cell(grid, y, 3, MIXED, nil, famA, "names family arial") else head("family arial: " .. errA, FIRST + 2 * WIDTH, -(y - 1) * HEIGHT) end
    if famF then cell(grid, y, 4, MIXED, nil, famF, "names family friz") else head("family friz: " .. errF, FIRST + 3 * WIDTH, -(y - 1) * HEIGHT) end
    head("plain arial", FIRST, -y * HEIGHT + 14)
    head("plain friz", FIRST + WIDTH, -y * HEIGHT + 14)
    head("family arial", FIRST + 2 * WIDTH, -y * HEIGHT + 14)
    head("family friz", FIRST + 3 * WIDTH, -y * HEIGHT + 14)
    FB.root:Show()
    return true
end

-- What the client answered, cell by cell, and this client's locale.
local function fontsState()
    local locale = GetLocale()
    say("fonts: this client is " .. tostring(locale) .. "; FONTS here: arial " .. tostring(LibStub("LibGlass-1.0").FONTS.arial.file)
        .. ", friz " .. tostring(LibStub("LibGlass-1.0").FONTS.friz.file))
    for _, c in ipairs(FB.cells) do
        say("fonts: " .. c.name .. ": " .. tostring(c.file or "family") .. " -> SetFont " .. Probe.Show(c.ok)
            .. ", GetFont " .. tostring(c.got))
    end
    if FB.familyError then say("fonts: CreateFontFamily: " .. FB.familyError) end
    local failed = FB.failed and #FB.failed or 0
    return failed == 0, "locale " .. tostring(locale) .. ", " .. #FB.cells .. " cells, " .. failed .. " files refused"
        .. (failed > 0 and (": " .. table.concat(FB.failed, "; ")) or "")
end

local function needFonts() if not FB.root then buildFonts() end end

Probe:Command("fonts", function() buildFonts(); fontsState() end,
    "#69: each language's text in r11's and r12's fonts, and a font family's fallback")

NS.hides[#NS.hides + 1] = function() if FB.root then FB.root:Hide() end end

Probe:Steps("fonts", {
    title = "LibGlass #69: fonts by locale",
    rev = 1,
    { text = "Checking which copy of LibGlass is running: r12 or later, and this probe's own.",
      auto = true, run = report,
      check = function()
          local m, host = minor(), winner()
          return type(m) == "number" and m >= 12 and host == "LibGlassProbe", "LibGlass r" .. tostring(m) .. " from " .. host
      end },
    { text = "Open the board: one row per client language with its own text, in r11's fonts (left two columns) and r12's (right two). The last row is your client showing names in four scripts. Drag it by its header.",
      button = "Show board", run = buildFonts, screenshot = "fonts: the board" },
    { text = "Logging what the client answered for each font file.", auto = true,
      run = needFonts, check = fontsState },
    { text = "In the two r12 columns (right), does every language's row show real letters, with no empty boxes or question marks?",
      ask = true },
    { text = "In the two r11 columns (left), which rows show boxes? Note them, e.g. \"friz: Russian, Korean, Chinese; arial: Korean, Chinese\".",
      ask = true },
    { text = "Last row: do the two family cells show all four names where the plain cells show boxes? Note what each cell shows.",
      ask = true },
    { text = "That's all. Press Finish, then type /reload so the results and screenshots are saved." },
})

NS._test = NS._test or {}
NS._test.Fonts = { FB = FB, buildFonts = buildFonts, fontsState = fontsState, ROWS = ROWS }
