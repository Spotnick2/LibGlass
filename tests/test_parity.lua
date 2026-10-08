-- The look must not change: LibGlass draws exactly what GlassUnitFrames'
-- Glass.lua v3 drew (frozen as tests/fixtures/GlassUF-v3.lua, @ 09b6f0d).
--
-- The same script builds surfaces and drives every setter and hook on both,
-- and every widget each one creates is compared: type, parent, and every
-- method call in order with its arguments (draw layers, sublevels, colours,
-- alphas, slice margins, frame levels, the hooks installed). Texture paths
-- are compared below their media folder, which is the one intended change.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUF_MEDIA = "Interface\\AddOns\\GlassUnitFrames\\Media\\"
local LIB_MEDIA = "Interface\\AddOns\\GlassUnitFrames\\Libs\\LibGlass-1.0\\Media\\"

-- Everything the widgets did, as text.
local function dump()
    local index = {}
    for i, w in ipairs(WoW.widgets) do index[w] = i end
    local function arg(v)
        local t = type(v)
        if t == "string" then
            local s = v:gsub("^" .. GUF_MEDIA:gsub("%p", "%%%0"), "<MEDIA>")
            s = s:gsub("^" .. LIB_MEDIA:gsub("%p", "%%%0"), "<MEDIA>")
            return string.format("%q", s)
        elseif t == "table" then
            if index[v] then return "#" .. index[v] end
            if v.r then return string.format("C(%s,%s,%s,%s)", tostring(v.r), tostring(v.g), tostring(v.b), tostring(v.a)) end
            return "table"
        elseif t == "function" then return "fn"
        end
        return tostring(v)
    end
    local out = {}
    for i, w in ipairs(WoW.widgets) do
        out[#out + 1] = string.format("#%d %s parent=%s", i, w._type, w._parent == UIParent and "UIParent" or w._parent and (index[w._parent] or "?") or "nil")
        for _, call in ipairs(w._log) do
            local args = {}
            for j = 1, call.n do args[j] = arg(call[j + 1]) end
            out[#out + 1] = "  " .. call[1] .. "(" .. table.concat(args, ", ") .. ")"
        end
    end
    return out
end

local function sortedKeys(t)
    local ks = {}
    for k in pairs(t) do ks[#ks + 1] = tostring(k) end
    table.sort(ks)
    return table.concat(ks, ",")
end

-- The scenario, written against the dot-called API both expose.
local function scenario(Glass)
    local r = {}
    local function note(v) r[#r + 1] = tostring(v) end
    local host = newHost(300, 60)
    local g = Glass.Apply(host, "large")
    local small = newHost(120, 24)
    local g2 = Glass.Apply(small, "small")
    local bar = Glass.Bar(host, 20)
    bar:SetPoint("TOPLEFT", host, "TOPLEFT", Glass.Inset("large"), -Glass.Inset("large"))
    bar:SetFrameLevel(Glass.ContentLevel(host))
    note(Glass.Inset("small")); note(Glass.ContentLevel(small))
    local bar2 = Glass.Bar(small, 7)
    local fs = Glass.Font(g.top, 14, "RIGHT")
    local fs2 = Glass.Font(g2.top, 10)
    local ag = Glass.Sheen(g, host, 300, 60)
    local ag2 = Glass.Sheen(g2, small, 120, 24)
    -- hooks
    bar:SetStatusBarColor(1, 0, 0)
    bar:SetStatusBarColor(1, 0, 0)            -- unchanged: no re-tint
    bar:SetStatusBarColor(0, 1, 0, 0.5)
    bar2:SetStatusBarColor(0.2, 0.4, 0.6)
    bar:SetHeight(14)
    bar:SetHeight(2)
    bar2:SetFrameLevel(9)
    -- setters, valid and refused
    for _, v in ipairs({ 0.5, 0, 2, 0 / 0, "0.5" }) do
        note(Glass.SetRimAlpha(v)); note(Glass.SetFillAlpha(v)); note(Glass.SetTrackAlpha(v))
        note(Glass.SetFillEnd(v)); note(Glass.SetEdgeAlpha(v))
    end
    Glass.SetEdge(g2, 0.6, 0.2, 0.5, 6)
    Glass.SetEdge(g, 0.3, 0.1, 0.2)
    note(Glass.SetEdgeAlpha(0.45))
    note(Glass.SetFont("friz")); note(Glass.SetFont("comic"))
    local fs3 = Glass.Font(host, 12)
    -- bars, instant and eased
    Glass.SetBar(bar, 100, 40, true)
    Glass.SetBar(bar, 100, 50)
    Enum.StatusBarInterpolation = { ExponentialEaseOut = 2 }
    note(Glass.Smooth())
    Glass.SetBar(bar, 120, 60)
    Glass.SetBar(bar, 120, 70, true)
    Enum.StatusBarInterpolation = nil
    -- data
    for _, k in ipairs({ "TRACK_LEVEL", "OVERLAY_LEVEL", "fontKey" }) do note(k .. "=" .. tostring(Glass[k])) end
    for _, k in ipairs({ "STYLE", "EDGE" }) do
        local t = Glass[k]
        local ks = {}
        for key in pairs(t) do
            if key ~= "disabledAlpha" then ks[#ks + 1] = key end   -- added in r3 (SetSurfaceEnabled)
        end
        table.sort(ks)
        for _, key in ipairs(ks) do
            local v = t[key]
            if type(v) == "table" then v = table.concat(v, ",") end
            note(k .. "." .. key .. "=" .. tostring(v))
        end
    end
    for _, name in ipairs({ "large", "small" }) do   -- v3's sets (the disc sets came in r2)
        local S = Glass.SIZES[name]
        for key, v in pairs(S) do
            if type(v) == "table" then v = table.concat(v, ",") end
            note("SIZES." .. name .. "." .. key .. "=" .. tostring(v))
        end
    end
    for name, f in pairs(Glass.FONTS) do note("FONTS." .. name .. "=" .. f.file .. "," .. f.bump) end
    for i, t in ipairs(Glass.TUNABLES) do
        note(string.format("TUNABLES[%d] %s %s %s %s %s %s %s %s", i, t.key, t.style, tostring(t.min),
            tostring(t.max), t.label, t.help, tostring(t.default), type(t.set)))
    end
    note("g:" .. sortedKeys(g)); note("g2:" .. sortedKeys(g2)); note("edge:" .. sortedKeys(g.edge))
    for _, f in ipairs({ "glassMask", "track", "trackClip", "overlay", "trackColor" }) do
        note("bar." .. f .. "=" .. type(rawget(bar, f)))
    end
    note(type(ag) .. type(ag2) .. type(fs) .. type(fs2) .. type(fs3))
    return r
end

local function run(load)
    WoW.reset()
    WoW.resetLibStub()
    rawset(_G, "GlassUF", nil)
    local Glass = load()
    local r = scenario(Glass)
    return dump(), r
end

local gufDump, gufNotes = run(function()
    assert(loadfile("tests/fixtures/GlassUF-v3.lua"))("GlassUnitFrames", {})
    return GlassUF.Glass
end)
local libDump, libNotes = run(function()
    return loadLibrary("GlassUnitFrames"):New()
end)

check(#gufDump > 300, "the scenario drew a realistic amount (" .. #gufDump .. " lines)")
eq(#libDump, #gufDump, "the same number of widget records")
local shown = 0
for i = 1, math.max(#gufDump, #libDump) do
    if gufDump[i] ~= libDump[i] then
        check(false, string.format("widget record %d: v3 %s | LibGlass %s", i, tostring(gufDump[i]), tostring(libDump[i])))
        shown = shown + 1
        if shown >= 10 then break end
    end
end

table.sort(gufNotes); table.sort(libNotes)
eq(#libNotes, #gufNotes, "the same results and data")
for i = 1, math.max(#gufNotes, #libNotes) do
    if gufNotes[i] ~= libNotes[i] then
        check(false, string.format("result: v3 %s | LibGlass %s", tostring(gufNotes[i]), tostring(libNotes[i])))
    end
end

-- The media folder is the one intended difference.
local bar = nil
for _, w in ipairs(WoW.widgets) do if w._type == "StatusBar" then bar = w; break end end
eq(bar:GetStatusBarTexture()._file, LIB_MEDIA .. "bar_fill", "textures come from the embedded library's folder")

done("test_parity")
