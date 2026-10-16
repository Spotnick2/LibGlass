-- LibGlassProbe (Tools/LibGlassProbe), a ForeverProbe module: it loads on the
-- host and this checkout's library, every command runs without an error, its
-- lines go to its saved log and never to chat, and the r7 procedure (#50)
-- walks end to end, painting what each step says; so do the #53 fill and
-- preview procedures, their step screenshots driven like the client's.
-- Needs a ForeverProbe checkout ($FOREVERPROBE, else ..\ForeverProbe); in CI
-- (FOREVERPROBE_OPTIONAL=1) it skips without one.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local root = foreverProbeRoot("test_probe")

-- Screenshots: the host shoots from its OnUpdate driver (hide, settle, the
-- gap between shots), then waits for SCREENSHOT_SUCCEEDED. The test owns the
-- clock. A step with a screenshot moves on only once its shot is done.
local clock, shots = 100, 0
rawset(_G, "GetTime", function() return clock end)
rawset(_G, "Screenshot", function() shots = shots + 1 end)
local function shoot()
    for _ = 1, 8 do clock = clock + 0.5; WoW.tick() end
    WoW.fire("SCREENSHOT_SUCCEEDED")
end

-- What the host reads beyond the shared stub (it reads every client API
-- through rawget, so the rest may stay absent).
local chat, errors = {}, {}
rawset(_G, "SlashCmdList", {})
rawset(_G, "print", function(...) chat[#chat + 1] = table.concat({ ... }, " ") end)
rawset(_G, "geterrorhandler", function() return function(e) errors[#errors + 1] = tostring(e) end end)

local FP = loadForeverProbe(root)
local ns = loadProbe()
local T = ns._test
local DB = LibGlassProbeDB
local function fp(msg) SlashCmdList.FOREVERPROBE(msg) end
local function logHas(text)
    for _, l in ipairs(DB.log) do if l:find(text, 1, true) then return true end end
    return false
end
local function logCount(text)
    local n = 0
    for _, l in ipairs(DB.log) do if l:find(text, 1, true) then n = n + 1 end end
    return n
end
local N = currentMinor()
-- The order a widget's methods were called in, as "A,B,C".
local function calls(w, names)
    local want, seen = {}, {}
    for n in names:gmatch("[^,]+") do want[n] = true end
    for _, c in ipairs(w._log) do if want[c[1]] then seen[#seen + 1] = c[1] end end
    return table.concat(seen, ",")
end

check(type(DB) == "table" and type(DB.log) == "table", "the saved table is made at the probe's ADDON_LOADED")
eq(DB.loads, 1, "and counts loads")
check(logHas("loaded (1 loads), LibGlass r" .. N), "the load line names the running LibGlass")
eq(LibStub("LibGlass-1.0").MEDIA, "Interface\\AddOns\\LibGlassProbe\\Libs\\LibGlass-1.0\\Media\\",
   "the embedded copy's media is the probe's own folder")

------------------------------------------------------------------------------
-- The commands
------------------------------------------------------------------------------
fp("lg")
check(logHas("/fp lg <command>:") and logHas("  show - "), "/fp lg lists the commands")
fp("lg show all")
local C = T.C
check(C.root and C.root:IsShown(), "show all: the comparison board")
eq(#C.surfaces, 9, "three columns of a panel, a unit and a control")
eq(#C.bars, 3, "and a bar each")
fp("lg show q")
check(logHas("show a | b | c | all"), "an unknown view is refused with the usage")
fp("lg next"); eq(C.selected, "a", "next: a")
fp("lg rotate"); eq(C.rotation, 1, "rotate")
fp("lg value 50")
eq(C.bars[1].bar._value, 50, "value: the bars' fake health")
eq(C.bars[2].text._text, "50 / 100", "and their labels")
fp("lg smoke 0.5")
eq(C.surfaces[4].g.tint._color[4], 0.5, "smoke: every column's body opacity")
fp("lg smoke 2")
eq(C.smoke, 0.5, "out of range is refused")
fp("lg report")
check(logHas("LibGlass r" .. N .. " is the loaded copy"), "report names the running copy")
check(logHas("compare: view all, body alpha 0.5, fill 50%"), "and the board's settings")

------------------------------------------------------------------------------
-- The r7 procedure, end to end
------------------------------------------------------------------------------
local S = FP.Steps
local D = 0.25   -- STYLE.disabledAlpha
fp("steps lg r7")
local rec = ForeverProbeDB.steps.records["LibGlassProbe/r7"]
check(rec and rec.status == "active", "/fp steps lg r7 starts the procedure")
eq(rec.results[1].status, "done", "step 1 runs on arrival")
eq(rec.results[1].check, "PASS", "and passes on r" .. N)

S.Run()   -- 2: the board
local R = T.R
check(R.root and R.root:IsShown(), "the r7 board")
eq(#R.surfaces, 8, "classic and clean, large and small, each enabled and disabled")
local function each(fn) for _, s in ipairs(R.surfaces) do fn(s, s.enabled and 1 or D) end end
each(function(s, k) near(s.g.wash._gradient[3].a, 0.18 * k, s.name .. ": built wash") end)

S.Run()   -- 3: wash 0.6
each(function(s, k) near(s.g.wash._gradient[3].a, 0.6 * k, s.name .. ": wash 0.6") end)
check(rec.results[3].detail:find("classic large off wash 0.150", 1, true), "the step records what was painted")
S.Answer(true)
S.Run()   -- 5: wash 0
each(function(s) check(not s.g.wash:IsShown() and s.g.wash._gradient[3].a == 0, s.name .. ": wash 0 hides it") end)
S.Answer(true)
S.Run()   -- 7: default
each(function(s, k)
    check(s.g.wash:IsShown(), s.name .. ": shown again")
    near(s.g.wash._gradient[3].a, 0.18 * k, s.name .. ": the default wash")
end)
S.Answer(true)
S.Run()   -- 9: edge 0.45
each(function(s, k)
    eq(s.g.edge.top._color[4], 0.45, s.name .. ": edge on")
    near(s.g.edge.glow._gradient[3].a, 0.12 * k, s.name .. ": its glow, dimmed when disabled")
end)
S.Answer(true)
S.Run()   -- 11: strong glow
each(function(s, k) near(s.g.edge.glow._gradient[3].a, 0.6 * k, s.name .. ": strong glow") end)
S.Answer(true)
S.Run()   -- 13: enable
each(function(s)
    near(s.g.wash._gradient[3].a, 0.18, s.name .. ": enabled, the wash given back")
    near(s.g.edge.glow._gradient[3].a, 0.6, s.name .. ": and the glow")
end)
S.Answer(true)
S.Run()   -- 15: disable, then wash 0.6
each(function(s, k) near(s.g.wash._gradient[3].a, 0.6 * k, s.name .. ": wash set while disabled stays dimmed") end)
S.Answer(true)
S.Run()   -- 17: scenery
check(not R.backdrop:IsShown(), "the backdrop off")
S.Answer(false)
S.Run()   -- 19: the strip
check(R.backdrop:IsShown(), "the backdrop back")
eq(#R.strip, 4, "four gradients in the strip")
eq(R.strip[1].tex._alpha, 0.2, "A: SetAlpha before its gradient")
eq(calls(R.strip[1].tex, "SetAlpha,SetGradient"), "SetAlpha,SetGradient", "in that order")
eq(R.strip[2].tex._file, "Interface\\Buttons\\WHITE8X8", "B: a file texture")
eq(R.strip[3].tex._alpha, nil, "C: no SetAlpha")
eq(calls(R.strip[4].tex, "SetAlpha,SetGradient"), "SetGradient,SetAlpha", "D: SetAlpha after")
check(rec.results[19].detail:find("A GetAlpha 1; B GetAlpha 1", 1, true),
      "the GetAlpha readings are recorded (1 on a gradient texture, as measured)")
S.Answer(true); S.Answer(false); S.Answer(true)
S.Next()   -- 23
eq(rec.status, "done", "the procedure finishes")
for i = 1, rec.count do
    local r = rec.results[i]
    check(r and (r.status == "done" or r.status == "yes" or r.status == "no") and not r.errors,
          "step " .. i .. " completed without an error")
end
check(logHas("STEP r7 START") and logHas("STEP r7 23/23 DONE"), "every step is in the probe's saved log")

-- The board is built fresh: SetEdge marks an edge custom for good.
local old = R.root
fp("lg r7")
check(not old:IsShown() and R.root ~= old and R.root:IsShown(), "lg r7 replaces the board")
check(not R.surfaces[1].g.edge.custom, "with surfaces SetEdge hasn't reached")
fp("lg wash 0.3")
near(R.surfaces[2].g.wash._gradient[3].a, 0.3 * D, "lg wash")
fp("lg disabled off")
near(R.surfaces[2].g.wash._gradient[3].a, 0.3, "lg disabled off")
fp("lg edge 0.2")
eq(R.surfaces[1].g.edge.top._color[4], 0.2, "lg edge")
fp("lg backdrop off")
check(not R.backdrop:IsShown(), "lg backdrop off")
fp("lg hide")
check(not R.root:IsShown() and not C.root:IsShown(), "lg hide closes both boards")

------------------------------------------------------------------------------
-- The #53 fill procedure, end to end
------------------------------------------------------------------------------
fp("steps lg fill")
local frec = ForeverProbeDB.steps.records["LibGlassProbe/fill"]
check(frec and frec.status == "active", "/fp steps lg fill starts the procedure")
eq(frec.results[1].status, "done", "step 1 (which copy) runs on arrival")
S.Run(); shoot()   -- 2: the board
local F = T.F
check(F.root and F.root:IsShown(), "the fill board")
eq(#F.rows, 4, "four bars")
local function fillOf(i) return F.rows[i].bar:GetStatusBarTexture() end
eq(fillOf(1)._alpha, 0.2, "row 1: the 0.2 instance's fill")
eq(fillOf(2)._alpha, 0.6, "row 2: the default")
eq(fillOf(3)._alpha, 1, "row 3: 1.0")
check(F.rows[1].bar.trackColor and fillOf(1)._gradient, "rows 1-3 are coloured, so their fill has a gradient")
check(not F.rows[4].bar.trackColor and not fillOf(4)._gradient, "row 4 has no colour and no gradient yet")
eq(fillOf(4)._alpha, 0.2, "but its fill alpha is set")
check(frec.results[2].detail:find("4 fillAlpha 0.2 GetAlpha 0.2 no colour", 1, true), "the step records each fill")
S.Answer(true); S.Answer(true)
S.Run(); shoot()   -- 5: colour row 4
check(F.rows[4].bar.trackColor and fillOf(4)._gradient, "row 4 coloured: now a gradient too")
S.Answer(true)
S.Run(); shoot()   -- 7: SetFillAlpha 1
check(fillOf(1)._alpha == 1 and fillOf(4)._alpha == 1, "SetFillAlpha reaches rows 1 and 4")
eq(fillOf(2)._alpha, 0.6, "and not the other instances' bars")
S.Run(); shoot()   -- 8: back to 0.2
eq(fillOf(1)._alpha, 0.2, "back to 0.2")
S.Answer(false)
S.Run(); shoot()   -- 10: colour alpha 0.3 on row 3
near(fillOf(3)._gradient[2].a, 0.3, "row 3's colour alpha goes into its gradient")
S.Answer(true)
S.Run(); shoot()   -- 12: the timer
check(logHas("fill: no SetTimerDuration on this client"), "without the client's timer API, the step says so")
S.Answer(false)
S.Next()   -- 14
eq(frec.status, "done", "the fill procedure finishes")
for i = 1, frec.count do
    local r = frec.results[i]
    check(r and (r.status == "done" or r.status == "yes" or r.status == "no") and not r.errors,
          "fill step " .. i .. " completed without an error")
end
local old = F.root
fp("lg fill")
check(not old:IsShown() and F.root ~= old and F.root:IsShown(), "lg fill replaces the board")
eq(fillOf(1)._alpha, 0.2, "with fresh instances")
fp("lg hide")
check(not F.root:IsShown(), "lg hide closes it too")

eq(#frec.results[2].screenshots, 1, "a run step's screenshot is saved on the step")

------------------------------------------------------------------------------
-- The #53 preview: today's fill beside the designed 0.6
------------------------------------------------------------------------------
fp("steps lg preview")
local prec = ForeverProbeDB.steps.records["LibGlassProbe/preview"]
check(prec and prec.status == "active", "/fp steps lg preview starts it")
S.Run(); shoot()   -- 1: the board
local P = T.P
check(P.root and P.root:IsShown(), "the preview board")
eq(#P.bars, 4, "classic and clean, fill 1.0 and 0.6")
local function fillA(i) return P.bars[i].bar:GetStatusBarTexture()._gradient[2].a end
eq(fillA(1), 1, "left: fill 1.0, opaque")
near(fillA(2), 0.6, "right: fill 0.6, drawn in the gradient (r8)")
eq(P.bars[4].glass.STYLE.thinRim, true, "the second row is clean")
eq(P.bars[1].bar._value, 100, "full health first")
S.Run(); shoot()   -- 2: 30%
eq(P.bars[3].bar._value, 30, "then 30%")
eq(P.bars[3].text._text, "30 / 100", "with its label")
S.Run(); shoot()   -- 3: 5%
eq(P.bars[4].bar._value, 5, "then 5%")
S.Answer(true)
S.Next()
eq(prec.status, "done", "the preview procedure finishes")
fp("lg preview 50")
eq(P.bars[2].bar._value, 50, "lg preview 50 sets the health")
fp("lg preview 101")
check(logHas("preview, or preview 0..100"), "out of range is refused")
fp("lg hide")
check(not P.root:IsShown(), "lg hide closes it too")
check(shots >= 9, "every screenshot step took its shot (" .. shots .. ")")

------------------------------------------------------------------------------
-- The r9 procedure: Reflect beside the recipe by hand (#56), own rims (#40)
------------------------------------------------------------------------------
fp("steps lg r9")
local qrec = ForeverProbeDB.steps.records["LibGlassProbe/r9"]
check(qrec and qrec.status == "active", "/fp steps lg r9 starts it")
eq(qrec.results[1].check, "PASS", "step 1 passes on r" .. N)
S.Run(); shoot()   -- 2: the board
local Q = T.Q
check(Q.root and Q.root:IsShown(), "the r9 board")
local L, H = Q.lib, Q.hand
check(L.reflect and L.reflect.header and not H.reflect, "the left shell through Reflect, the right one by hand")
-- The hand-built recipe and Reflect paint the same layers.
local hand = {}
for _, w in ipairs(WoW.widgets) do
    if w._gradient and (w._parent == H.top or w._parent == H.top:GetParent()) and w ~= H.wash and w ~= H.edge.glow then
        hand[#hand + 1] = w
    end
end
eq(#hand, 3, "the hand shell has three gradient layers")
local function sig(w)
    local gr = w._gradient
    return string.format("%s %s %d %.3f,%.3f,%.3f,%.3f %.3f,%.3f,%.3f,%.3f %s", gr[1], w._layer, w._sublevel,
        gr[2].r, gr[2].g, gr[2].b, gr[2].a, gr[3].r, gr[3].g, gr[3].b, gr[3].a, tostring(w._file))
end
local want = {}
for _, k in ipairs({ "rim", "top", "header" }) do want[sig(L.reflect[k])] = true end
for _, w in ipairs(hand) do check(want[sig(w)], "the hand layer matches a Reflect layer: " .. sig(w)) end
for _, f in ipairs({ "rim", "dark", "grain", "shadow" }) do
    eq(L[f]._alpha, H[f]._alpha, "SetSurfaceAlpha draws " .. f .. " as the hand recipe")
end
eq(L.reflect.header._height, 70, "the header at 70 px, as PetStable")
check(qrec.results[2].detail:find("library shell rim 0.120, lit rim 0.520, top 0.580, header 0.105", 1, true),
      "the step records what Reflect painted")
S.Answer(true)
S.Run(); shoot()   -- 4: disable the left shell
near(L.reflect.rim._gradient[3].a, 0.52 * D, "disabled: the lit rim dimmed")
near(L.reflect.header._gradient[3].a, 0.105 * D, "and the header")
near(L.rim._alpha, 0.12 * D, "and the own rim")
S.Answer(true)
S.Run()   -- 6: enable it
near(L.reflect.rim._gradient[3].a, 0.52, "enabled: given back")
eq(L.rim._alpha, 0.12, "the rim at its own alpha")
S.Answer(true)
local red = Q.controls[2].g.rim._vertex
check(red[1] == 1 and red[2] == 0.25 and red[3] == 0.2, "the own-rim controls' rims are red")
eq(Q.controls[2].g.size, "large", "on large controls, so the rim is visible")
S.Answer(true)
S.Run(); shoot()   -- 9: outline 0.2
eq(Q.controls[1].g.rim._alpha, 0.2, "the default control's rim follows SetRimAlpha")
check(Q.controls[2].g.rim._alpha == 1 and Q.controls[3].g.rim._alpha == 1, "the red ones keep their own")
S.Answer(true)
S.Run(); shoot()   -- 11: disable the right control
near(Q.controls[3].g.rim._alpha, D, "the right control dimmed")
S.Answer(true)
S.Run()   -- 13: enable it
eq(Q.controls[3].g.rim._alpha, 1, "back to its own alpha")
S.Answer(true)
S.Next()
eq(qrec.status, "done", "the r9 procedure finishes")
for i = 1, qrec.count do
    local r = qrec.results[i]
    check(r and (r.status == "done" or r.status == "yes" or r.status == "no") and not r.errors,
          "r9 step " .. i .. " completed without an error")
end
local oldQ = Q.root
fp("lg r9")
check(not oldQ:IsShown() and Q.root ~= oldQ and Q.root:IsShown(), "lg r9 replaces the board")
fp("lg shell off")
near(Q.lib.reflect.top._gradient[3].a, 0.035 * D, "lg shell off")
fp("lg outline 0.5")
eq(Q.controls[1].g.rim._alpha, 0.5, "lg outline")
fp("lg outline x")
check(logHas("outline 0.2..1"), "a non-number is refused with the usage")
fp("lg hide")
check(not Q.root:IsShown(), "lg hide closes it too")

-- The own-rim part alone (the first r9 run's gold rims were too faint to judge).
fp("steps lg rim")
local rrec = ForeverProbeDB.steps.records["LibGlassProbe/rim"]
check(rrec and rrec.status == "active", "/fp steps lg rim starts it")
eq(rrec.results[1].check, "PASS", "step 1 passes on r" .. N)
local before = Q.root
S.Run(); shoot()   -- 2: a fresh board
check(Q.root ~= before and Q.root:IsShown(), "a fresh r9 board")
eq(Q.controls[2].g.rim._alpha, 1, "the red rim at its own alpha")
S.Answer(true)
S.Run(); shoot()   -- 4: outline 0.2
check(Q.controls[1].g.rim._alpha == 0.2 and Q.controls[2].g.rim._alpha == 1, "only the default rim fades")
S.Answer(true)
S.Run(); shoot()   -- 6: disable right
near(Q.controls[3].g.rim._alpha, D, "the right control dimmed")
S.Answer(true)
S.Run()   -- 8: enable it
eq(Q.controls[3].g.rim._alpha, 1, "given back")
S.Answer(true)
S.Next()
eq(rrec.status, "done", "the rim procedure finishes")
eq(rrec.count, 10, "ten steps")
for i = 1, rrec.count do
    local r = rrec.results[i]
    check(r and (r.status == "done" or r.status == "yes" or r.status == "no") and not r.errors,
          "rim step " .. i .. " completed without an error")
end
fp("lg hide")

------------------------------------------------------------------------------
-- Nothing went wrong, nothing went to chat, the log clears in place
------------------------------------------------------------------------------
eq(logCount("ERROR"), 0, "no command or step logged an error")
eq(#errors, 0, "nothing reached the error handler")
eq(#chat, 0, "nothing went to chat")
local log = DB.log
fp("lg clear")
check(DB.log == log, "clear empties the saved log in place")
eq(#DB.log, 1, "leaving the one line after it")
check(DB.log[1] and DB.log[1]:find("log cleared", 1, true), "which is that one")

-- Every widget method the probe (and the host, for its panel) called exists
-- on this client: the stub answers any method, so a missing one would pass.
local f = io.open(WoW.DUMP, "r")
if f then
    local widget = {}
    for line in f:lines() do
        local wm = line:match("^(%a+:%a+)%s*$")
        if wm then widget[wm] = true end
    end
    f:close()
    for name in pairs(WoW.methodsCalled) do check(widget[name], "method exists on Forever: " .. name) end
else
    io.write("  (no API dump at " .. WoW.DUMP .. ": methods not checked)\n")
end

done("test_probe")
