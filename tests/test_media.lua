-- Media\ holds exactly the textures the code names: a missing one draws
-- nothing in game (no error), and an extra one ships to every consumer for
-- nothing. Each is an uncompressed 32-bit TGA with power-of-two sides, the
-- only format the client reads here.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- Names the code uses: every `lib.MEDIA .. "name"` literal, and every
-- texture named in SIZES (mask, rim, dark, shadow).
local src = readFile("LibGlass.lua")
local named = {}
for name in src:gmatch('lib%.MEDIA %.%. "([%w_]+)"') do named[name] = true end
local lib = loadLibrary("GlassUnitFrames")
for _, S in pairs(lib.SIZES) do
    for _, k in ipairs({ "mask", "rim", "dark", "shadow" }) do named[S[k]] = true end
end
-- And what the builders actually set, so a name built some other way counts.
local Glass = lib:New()
for _, size in ipairs({ "large", "small" }) do
    local host = newHost()
    local g = Glass.Apply(host, size)
    Glass.Bar(host, 20)
    Glass.Sheen(g, host, 200, 40)
end
for _, size in ipairs({ "disc", "disc_small" }) do
    local host = newHost(64, 64)
    Glass.Sheen(Glass.Disc(host, size), host, 64, 64)
end
for _, w in ipairs(WoW.widgets) do
    if w._file then
        local name = w._file:match("^" .. lib.MEDIA:gsub("%p", "%%%0") .. "([%w_]+)$")
        check(name, "a texture from the library's folder: " .. w._file)
        if name then named[name] = true end
    end
end

-- The files.
local list = package.config:sub(1, 1) == "\\" and io.popen('dir /b "Media"') or io.popen("ls Media")
local files = {}
for line in list:lines() do
    line = line:gsub("\r", "")
    if line ~= "" then files[line] = true end
end
list:close()

local count = 0
for name in pairs(named) do
    count = count + 1
    check(files[name .. ".tga"], "Media holds " .. name .. ".tga")
end
eq(count, 23, "the code names 23 textures (r1's 15 and the 8 disc textures)")
for file in pairs(files) do
    local name = file:match("^(.+)%.tga$")
    check(name and named[name], "Media\\" .. file .. " is a texture the code names")
    if name then
        local data = readFile("Media/" .. file)
        local w = data:byte(13) + data:byte(14) * 256
        local h = data:byte(15) + data:byte(16) * 256
        eq(data:byte(3), 2, file .. ": uncompressed true-colour")
        eq(data:byte(17), 32, file .. ": 32-bit")
        local function pow2(x) while x > 1 and x % 2 == 0 do x = x / 2 end; return x == 1 end
        check(pow2(w) and pow2(h), file .. ": power-of-two sides (" .. w .. "x" .. h .. ")")
        eq(#data, 18 + w * h * 4, file .. ": the pixel data is all there")
    end
end

-- Tools/deploy.ps1 names the same textures (its preflight refuses a copy missing one).
local deploy = readFile("Tools/deploy.ps1"):match("%$Textures = @%((.-)%)")
check(deploy, "deploy.ps1 lists its textures")
local listed = 0
for name in (deploy or ""):gmatch('"([%w_]+)"') do
    listed = listed + 1
    check(named[name], "deploy.ps1's " .. name .. " is a texture the code names")
end
eq(listed, count, "deploy.ps1 lists every texture the code names")

done("test_media")
