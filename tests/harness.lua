-- Shared frozen releases: append here when a release fixture is added.
RELEASES = { "LibGlass-r1.lua", "LibGlass-r2.lua", "LibGlass-r3.lua", "LibGlass-r4.lua",
             "LibGlass-r5.lua", "LibGlass-r6.lua", "LibGlass-r7.lua", "LibGlass-r8.lua",
             "LibGlass-r9.lua", "LibGlass-r10.lua" }

-- harness.lua: assertions and the library loader. dofile it after wow_stubs.lua.
-- Run from the repo root so the relative paths resolve.

local passed, failed = 0, 0

function check(cond, msg)
    if cond then passed = passed + 1 else
        failed = failed + 1
        io.write("  FAIL: " .. tostring(msg) .. "\n")
    end
end

function eq(actual, expected, msg)
    check(actual == expected, string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
end

function near(actual, expected, msg)
    check(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
          string.format("%s: expected ~%s, got %s", msg, tostring(expected), tostring(actual)))
end

function done(name)
    io.write(string.format("%s: %d passed, %d failed\n", name, passed, failed))
    os.exit(failed == 0 and 0 or 1)
end

function readFile(path)
    local f = assert(io.open(path, "rb"), "cannot open " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

-- The Lua files LibGlass-1.0.xml loads, in order. Read from the XML itself,
-- so the tests load exactly what the client loads: a file listed there that
-- does not exist fails here, the same way it would fail in game.
function xmlScripts()
    local xml = readFile("LibGlass-1.0.xml"):gsub("<!%-%-.-%-%->", "")   -- listed in a comment is not loaded
    local files = {}
    for file in xml:gmatch('<Script%s+file="([^"]+)"') do files[#files + 1] = (file:gsub("\\", "/")) end
    return files
end

-- One copy of the library: { [file] = source }, every file the XML lists.
-- `edit(file, src)` may rewrite a file's source (synthetic copies).
function copyOf(edit)
    local copy = {}
    for _, file in ipairs(xmlScripts()) do
        -- LF, whatever the checkout has: a Windows clone with core.autocrlf
        -- gets CRLF, and synthetic()'s substitutions are written with "\n".
        local src = readFile(file):gsub("\r\n", "\n")
        if edit then src = edit(file, src) end
        copy[#copy + 1] = { name = file, src = src }
    end
    return copy
end

-- Load a copy the way the client loads an embedded library: every file the
-- XML lists, in order, each called with (host addon name, namespace).
function loadCopy(copy, host)
    local ns = {}
    for _, file in ipairs(copy) do
        local chunk = assert(loadstring(file.src, "=" .. file.name .. " (" .. tostring(host) .. ")"))
        chunk(host, ns)
    end
    return LibStub("LibGlass-1.0")
end

-- The common case: this checkout, embedded in `host` (default "GlassUnitFrames").
function loadLibrary(host)
    return loadCopy(copyOf(), host or "GlassUnitFrames")
end

-- This checkout with a different MINOR and, optionally, `extra` Lua run just
-- before the completion marker (it sees the file's locals: lib, fill, ...).
-- `replace` is a list of { from, to } plain-text substitutions, each of which
-- must match exactly once.
local MINOR_LINE = 'local MAJOR, MINOR = "LibGlass%-1%.0", (%d+)'
function currentMinor()
    return tonumber(readFile("LibGlass.lua"):match(MINOR_LINE))
end
function synthetic(minor, extra, replace)
    return copyOf(function(file, src)
        if file ~= "LibGlass.lua" then return src end
        local n
        src, n = src:gsub(MINOR_LINE, 'local MAJOR, MINOR = "LibGlass-1.0", ' .. minor)
        assert(n == 1, "synthetic: MINOR line not found")
        for _, r in ipairs(replace or {}) do
            local i, j = src:find(r[1], 1, true)
            assert(i and not src:find(r[1], j + 1, true), "synthetic: must match once: " .. r[1])
            src = src:sub(1, i - 1) .. r[2] .. src:sub(j + 1)
        end
        if extra then
            local i = src:find("\nlib.ready = MINOR%s*$")
            assert(i, "synthetic: the completion marker is not the last line")
            src = src:sub(1, i) .. extra .. "\n" .. src:sub(i + 1)
        end
        return src
    end)
end

-- A released copy, frozen under tests/fixtures (e.g. "LibGlass-r1.lua"),
-- loaded the way the XML loads it: the bundled LibStub, then the library.
function fixtureCopy(file)
    local copy = {}
    for _, name in ipairs(xmlScripts()) do
        local path = name == "LibGlass.lua" and ("tests/fixtures/" .. file) or name
        copy[#copy + 1] = { name = path, src = (readFile(path):gsub("\r\n", "\n")) }
    end
    return copy
end

-- A host frame of the given size under UIParent.
function newHost(w, h)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(w or 200, h or 40)
    return f
end

-- ForeverProbe, the host LibGlassProbe depends on, from its checkout
-- ($FOREVERPROBE, else ..\ForeverProbe), loaded into THIS stub environment
-- the way the client loads a dependency: its TOC's files, then its
-- ADDON_LOADED. The host is private and lives on the owner's disk, so probe
-- tests run locally (ForeverProbe guide, section 8): a missing checkout is an
-- error, except with FOREVERPROBE_OPTIONAL=1 (CI), where `name` prints a
-- SKIPPED line and exits cleanly.
function foreverProbeRoot(name)
    local root = (os.getenv("FOREVERPROBE") or "../ForeverProbe"):gsub("\\", "/"):gsub("/$", "")
    local toc = io.open(root .. "/ForeverProbe.toc", "rb")
    if toc then toc:close(); return root end
    if os.getenv("FOREVERPROBE_OPTIONAL") == "1" then
        io.write(name .. ": SKIPPED (no ForeverProbe checkout; probe tests run locally)\n")
        os.exit(0)
    end
    error("ForeverProbe checkout not found at " .. root .. ": clone it there or set FOREVERPROBE", 0)
end

function loadForeverProbe(root)
    local files = {}
    for line in readFile(root .. "/ForeverProbe.toc"):gmatch("[^\r\n]+") do
        if line:match("%.lua$") and not line:match("^#") then files[#files + 1] = root .. "/" .. line end
    end
    for _, file in ipairs(files) do assert(loadfile(file))("ForeverProbe", {}) end
    WoW.fire("ADDON_LOADED", "ForeverProbe")
    return ForeverProbe
end

-- LibGlassProbe as the client loads it: its TOC, with the embedded library's
-- XML expanded to this checkout's files, each called with (name, ns); then
-- its ADDON_LOADED. Returns the namespace (ns._test is the seam).
function loadProbe()
    local dir = "Tools/LibGlassProbe/"
    local ns = {}
    for line in readFile(dir .. "LibGlassProbe.toc"):gmatch("[^\r\n]+") do
        if line == "Libs\\LibGlass-1.0\\LibGlass-1.0.xml" then
            loadCopy(copyOf(), "LibGlassProbe")
        elseif line:match("%.lua$") and not line:match("^#") then
            assert(loadfile(dir .. line))("LibGlassProbe", ns)
        end
    end
    WoW.fire("ADDON_LOADED", "LibGlassProbe")
    return ns
end
