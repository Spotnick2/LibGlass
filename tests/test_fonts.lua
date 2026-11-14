-- The fonts by locale (r12, #69): FONTS[key].file is the client's own font
-- for the scripts the Latin files lack, on the locale it loads on; English
-- and every other Latin locale keep r11's files; an upgrade fills FONTS in
-- place, so a consumer holding the table (or reading .file) sees the newer
-- copy's choice.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local ARIALN, FRIZ = "Fonts\\ARIALN.TTF", "Fonts\\FRIZQT__.TTF"
-- Blizzard's members (wow-ui-source Blizzard_Fonts_Shared, at 70938).
local EXPECT = {
    enUS = { arial = ARIALN, friz = FRIZ },
    enGB = { arial = ARIALN, friz = FRIZ },
    deDE = { arial = ARIALN, friz = FRIZ },
    frFR = { arial = ARIALN, friz = FRIZ },
    esES = { arial = ARIALN, friz = FRIZ },
    ptBR = { arial = ARIALN, friz = FRIZ },
    ruRU = { arial = ARIALN, friz = "Fonts\\FRIZQT___CYR.TTF" },
    koKR = { arial = "Fonts\\2002.TTF", friz = "Fonts\\2002.TTF" },
    zhCN = { arial = "Fonts\\ARKai_C.ttf", friz = "Fonts\\ARKai_T.ttf" },
    zhTW = { arial = "Fonts\\arheiuhk_bd.TTF", friz = "Fonts\\blei00d.TTF" },
}

local function fresh(locale, copy)
    WoW.reset(); WoW.resetLibStub()
    WoW.locale = locale
    return loadCopy(copy or copyOf(), "GlassUnitFrames")
end

------------------------------------------------------------------------------
-- What each locale loads
------------------------------------------------------------------------------
for locale, want in pairs(EXPECT) do
    local lib = fresh(locale)
    eq(lib.FONTS.arial.file, want.arial, locale .. ": arial")
    eq(lib.FONTS.friz.file, want.friz, locale .. ": friz")
    eq(lib.FONTS.arial.bump, 1, locale .. ": arial keeps its point")
    eq(lib.FONTS.friz.bump, 0, locale .. ": friz keeps its size")
    -- The seam the probe draws other locales with gives the same answer.
    local seam = lib._test.fontsFor(locale)
    eq(seam.friz.file, want.friz, locale .. ": fontsFor agrees")

    -- Font and SetFont draw it.
    local inst = lib:New()
    local fs = inst.Font(newHost(), 12)
    eq(fs._font[1], want.arial, locale .. ": Font uses the locale's arial")
    eq(fs._font[2], 13, locale .. ": at its size")
    inst.SetFont("friz")
    eq(fs._font[1], want.friz, locale .. ": SetFont restyles to the locale's friz")
    eq(lib:New({ font = "friz" }).Font(newHost(), 12)._font[1], want.friz, locale .. ": font = friz at New")
end

-- An unknown locale is a Latin one.
eq(fresh("xxXX").FONTS.friz.file, FRIZ, "an unknown locale keeps the Latin files")
-- fontsFor hands out fresh tables: nothing a caller does to one reaches FONTS.
local lib = fresh("koKR")
local t = lib._test.fontsFor("koKR")
t.arial.file = "nope"
eq(lib.FONTS.arial.file, "Fonts\\2002.TTF", "fontsFor's result is a copy")

------------------------------------------------------------------------------
-- Upgrade: r11 first, this copy over it, on a Russian client
------------------------------------------------------------------------------
local old = fresh("ruRU", fixtureCopy("LibGlass-r11.lua"))
local held, heldFriz = old.FONTS, old.FONTS.friz
eq(heldFriz.file, FRIZ, "r11 loads the Latin friz, whatever the locale")
local inst11 = old:New({ font = "friz" })
local fs11 = inst11.Font(newHost(), 12)
local new = loadCopy(copyOf(), "GlassRaidFrames")
eq(new, old, "the same library object")
check(new.FONTS == held, "FONTS keeps its identity across the upgrade")
check(new.FONTS.friz == heldFriz, "and so does each entry")
eq(heldFriz.file, "Fonts\\FRIZQT___CYR.TTF", "a consumer holding FONTS reads the Cyrillic Friz")
eq(fs11._font[1], FRIZ, "a string r11 already built keeps its file (stated limitation)")
inst11.SetFont("friz")
eq(fs11._font[1], "Fonts\\FRIZQT___CYR.TTF", "r11's instance takes it on its next SetFont")

-- An older copy loading second changes nothing.
loadCopy(fixtureCopy("LibGlass-r11.lua"), "GlassChat")
eq(new.FONTS.friz.file, "Fonts\\FRIZQT___CYR.TTF", "r11 loading second is a no-op")

WoW.locale = "enUS"
done("test_fonts")
