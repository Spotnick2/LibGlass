-- LibGlass-1.0: the "liquid glass" material, as an embedded LibStub library.
--
-- Lifted from GlassUnitFrames' Glass.lua v3 (@ 09b6f0d); the look is
-- unchanged. Full write-up, parameters and the reasoning behind each layer:
-- docs/GLASS-MATERIAL.md. It knows nothing about units, events or secure
-- frames, and needs only the textures in Media\.
--
--   local Glass = LibStub("LibGlass-1.0"):New(opts?)   -- one instance per addon
--   LibStub("LibGlass-1.0"):New({ preset = "pearl" })  -- r11: the suite's Pearl material
--   local g = Glass.Apply(frame, "large")              -- dot-called, as before
--   local d = Glass.Disc(square, "disc")               -- r2: the round variant
--   Glass.SetSurfaceTint(g, r, g, b, a)                -- r3: one surface's own tint
--   Glass.SetSurfaceEnabled(g, false)                  -- r3: its disabled look
--   Glass.SetWash(g, 0.1)                              -- r7: its wash (SetAlpha doesn't reach it)
--   Glass.SetSurfaceRim(g, r, g, b, a?)                -- r9: its rim's colour and alpha
--   Glass.SetSurfaceAlpha(g, "dark", 0.5)              -- r9: one region's alpha (rim, dark, grain, shadow)
--   local rf = Glass.Reflect(g, frame, { header = 70 }) -- r9: the reflective shell's lit layers
--   local pill, g = Glass.Pill(button)                 -- r5: a small glass button behind a symbol
--
-- Layer stack on a host frame, bottom to top:
--   shadow -> tint -> grain -> wash      (on the host, masked to a rounded rect)
--   ...caller's content frames...        (host level + 2)
--   dark rim -> sheen -> rim -> text     (on g.top, host level + 10)
--   optional edge: top line + glow, bottom line (on g.top; off by default)
--   optional reflection (r9, Reflect): a header glow over the wash; a lit
--   rim and a top highlight on g.top
-- A disc (Glass.Disc) has the same stack on a square host, every layer
-- unsliced and round, and no edge.
--
-- Several addons embed copies and the newest one loaded wins (LibStub), so an
-- instance made by an older copy must run this copy's code. Hence the rules:
-- - Everything installed once (instance functions, TUNABLES[i].set, the bar
--   hooks) is a thin closure that looks up lib.impl.<name> WHEN IT RUNS. Never
--   let one capture an implementation function: it would run old code forever.
-- - lib.impl, lib.instances and every public table keep their identity across
--   upgrades (X = X or {}, filled in place).
-- - An upgrade fills only missing STYLE/EDGE keys and adds missing functions
--   and TUNABLES; it never repaints or rebuilds what an older copy built.
-- - lib.ready = MINOR is the last line: New refuses a half-loaded copy.

local MAJOR, MINOR = "LibGlass-1.0", 11
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end   -- an equal or newer copy is already loaded

-- The addon this copy is embedded in, passed by the client to every file its
-- XML loads. The winning copy's folder holds the textures its code names.
local HOST = ...
lib.MEDIA = HOST and ("Interface\\AddOns\\" .. HOST .. "\\Libs\\LibGlass-1.0\\Media\\")
    or "Interface\\AddOns\\LibGlass-1.0\\Media\\"
-- What an instance reads through to the library (see lib.instanceMT below).
-- MEDIA goes in here in the same step, so builders and instances can't
-- disagree about the folder even if this copy throws later in its load.
lib.shared = lib.shared or {}
lib.shared.MEDIA = lib.MEDIA
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"

lib.impl = lib.impl or {}
lib.instances = lib.instances or {}

-- Copy `src` into `dst` in place, so a table a consumer holds stays current.
local function fill(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            fill(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

-- Copy only the keys `dst` lacks: an upgrade must keep an instance's overrides.
local function fillMissing(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = type(v) == "table" and fill({}, v) or v
        elseif type(v) == "table" and type(dst[k]) == "table" then
            fillMissing(dst[k], v)
        end
    end
    return dst
end

--------------------------------------------------------------------------------
-- Shared, read-only data
--------------------------------------------------------------------------------

-- Texture sets. Slice margins are in texture pixels and must match the
-- generator; "small" is for anything under ~40px tall. `inset` is where
-- content (bars) starts inside the bevel.
-- The disc sets (r2, Glass.Disc only) are never sliced: no margins. Their
-- textures stretch with the host, so `inset` is the bevel at the texture's
-- own size (256 / 64 px; scale it by host size / texture size), and the shadow is outset on every side by
-- `shadowOutset` times the host's size, so the texture's disc lines up with
-- the host at any size. "disc" from ~96px up, "disc_small" below.
-- The thin sets (r3) are the rect sets with a thinner, subtler rim (opt-in:
-- the shared look stays rim5) and the inset that follows its bevel.
lib.SIZES = fill(lib.SIZES or {}, {
    large = { mask = "body_mask", maskMargin = 16, rim = "rim5", dark = "rim_dark5", rimMargin = 16,
              shadow = "shadow", shadowMargin = 48, shadowPad = { -22, 20, 22, -26 }, inset = 6 },
    small = { mask = "body_mask_small", maskMargin = 8, rim = "rim5_small", dark = "rim_dark5_small", rimMargin = 8,
              shadow = "shadow_small", shadowMargin = 24, shadowPad = { -12, 10, 12, -14 }, inset = 3 },
    disc = { shape = "disc", mask = "disc_mask", rim = "disc_rim", dark = "disc_rim_dark",
             shadow = "disc_shadow", shadowOutset = 0.125, inset = 6 },
    disc_small = { shape = "disc", mask = "disc_mask_small", rim = "disc_rim_small", dark = "disc_rim_dark_small",
                   shadow = "disc_shadow_small", shadowOutset = 0.125, inset = 4 },
    thin = { mask = "body_mask", maskMargin = 16, rim = "rim_thin", dark = "rim_dark_thin", rimMargin = 16,
             shadow = "shadow", shadowMargin = 48, shadowPad = { -22, 20, 22, -26 }, inset = 4 },
    thin_small = { mask = "body_mask_small", maskMargin = 8, rim = "rim_thin_small", dark = "rim_dark_thin_small",
                   rimMargin = 8, shadow = "shadow_small", shadowMargin = 24, shadowPad = { -12, 10, 12, -14 },
                   inset = 2 },
})

-- Client-shipped fonts only. Arial Narrow runs small, so it gets a point more.
lib.FONTS = fill(lib.FONTS or {}, {
    arial = { file = "Fonts\\ARIALN.TTF",   bump = 1 },
    friz  = { file = "Fonts\\FRIZQT__.TTF", bump = 0 },
})

-- Bar levels: the track's clip frame at bar + 1; callers' overlays over the
-- fill at + 2 and + 3 (GlassUnitFrames: health loss, heal prediction); the
-- gloss, shade and edge on bar.overlay at + 4, so all of them sit UNDER the
-- glass layers, like the fill itself.
lib.TRACK_LEVEL = 1
lib.OVERLAY_LEVEL = 4

-- The defaults every instance copies. The settled look: probe style 4
-- (GlassUnitFrames docs/FOREVER-PROBE.md, third run) with the thinner, dimmer
-- rim5 from the outside review.
lib.defaults = lib.defaults or {}
lib.defaults.STYLE = {
    tint = { 0.13, 0.16, 0.22, 0.24 },   -- cool, light: glass, not smoked plastic
    grain = 0.45,                        -- faint frost; cannot track the scene behind
    thinRim = false,                     -- r6: map large/small to thin/thin_small, including Inset
    shadowAlpha = 1,                     -- r6: body shadow strength; Pill still hides its shadow
    wash = 0.18,                         -- top-down white gradient inside the body
    gloss = 0.45,                        -- ADD highlight on bars
    innerShadow = 0.35,                  -- bottom shade on bars
    rimAlpha = 0.7,                      -- outer rim, softened (owner-picked; 1.0 read as bulky)
    fillAlpha = 0.60,                    -- bar fill opacity: the scene shows through, text stays opaque
    fillEnd = 1.0,                       -- optional left-to-right fade of the fill (1 = none, as the mockup)
    trackTop = 0.75,                     -- the missing part: the bar's colour fading to clear across the bar
    trackLength = 0,                     -- r10: 0 = that ramp across the whole bar; a fraction = only its fade,
                                         -- from the fill's moving edge over that much of the bar (SetTrackLength)
    frost = 0.10,                        -- plus a white frost, 0 at the bottom to this at the top
    sheenAlpha = 0.8,
    edge = 0,                            -- the optional directional edge's top line (0 = off; GlassChat ships 0.45)
    disabledAlpha = 0.25,                -- r3: SetSurfaceEnabled(g, false) scales the body, rims and edge by this
                                         -- (r4: 0.25; r3's 0.4 was subtle at button size in game)
}
-- The directional edge, as fractions of its top line (GlassChat's owner-tuned
-- values: top 0.45, glow 0.12, bottom 0.35), and the glow's depth.
lib.defaults.EDGE = { glow = 0.12 / 0.45, bottom = 0.35 / 0.45, glowh = 4 }
lib.defaults.fontKey = "arial"

-- The live-tunable material knobs, in one place for anything that exposes
-- them (GlassUnitFrames: /glass <key>, the options panel). Each instance gets
-- its own copy, with `set` bound to it and `default` its STYLE value at New
-- (the shipped value plus the addon's overrides, before any saved setting).
lib.defaults.TUNABLES = {
    { key = "fill",  style = "fillAlpha", fn = "SetFillAlpha",  min = 0.2, max = 1,
      label = "Bar fill opacity",     help = "bar fill opacity; text stays opaque" },
    { key = "rim",   style = "rimAlpha",  fn = "SetRimAlpha",   min = 0.2, max = 1,
      label = "Glass outline",        help = "brightness of the glass outline" },
    { key = "track", style = "trackTop",  fn = "SetTrackAlpha", min = 0,   max = 1,
      label = "Empty bar colour",     help = "how strongly a bar's empty part shows its colour" },
    { key = "fade",  style = "fillEnd",   fn = "SetFillEnd",    min = 0,   max = 1,
      label = "Fill fade (1 = none)", help = "how far a bar's fill fades towards its edge, 1 = none" },
    { key = "edge",  style = "edge",      fn = "SetEdgeAlpha",  min = 0,   max = 1,
      label = "Edge highlight",       help = "a fine bright top line and dark bottom line, 0 = off" },
}

-- What an instance reads through to the library: no function, so nothing an
-- older copy installed here can go stale. Filled in place on every upgrade.
lib.shared.SIZES = lib.SIZES
lib.shared.FONTS = lib.FONTS
lib.shared.TRACK_LEVEL = lib.TRACK_LEVEL
lib.shared.OVERLAY_LEVEL = lib.OVERLAY_LEVEL
lib.instanceMT = lib.instanceMT or {}
lib.instanceMT.__index = lib.shared

-- The instance functions, each dispatched to lib.impl[name](inst, ...).
-- Public, so filled in place: new names are appended to the table an older
-- copy made (r1 replaced it wholesale; from r2 it keeps its identity).
lib.FUNCTIONS = lib.FUNCTIONS or {}
do
    local have = {}
    for _, name in ipairs(lib.FUNCTIONS) do have[name] = true end
    for _, name in ipairs({ "Apply", "Bar", "Mask", "Font", "Sheen", "SetBar", "Smooth", "Inset", "ContentLevel",
                            "SetFillAlpha", "SetRimAlpha", "SetTrackAlpha", "SetFillEnd", "SetEdgeAlpha", "SetEdge",
                            "SetFont", "Disc", "SetSurfaceTint", "SetSurfaceEnabled", "Pill", "RelevelPill",
                            "SetWash", "SetSurfaceRim", "SetSurfaceAlpha", "Reflect", "SetTrackLength" }) do
        if not have[name] then
            table.insert(lib.FUNCTIONS, name)
            have[name] = true
        end
    end
end

--------------------------------------------------------------------------------
-- Helpers (called only from impl functions, never captured by a closure that
-- outlives the call)
--------------------------------------------------------------------------------

local function rectSize(inst, size)
    size = size or "large"
    if inst.STYLE.thinRim then
        if size == "large" then return "thin" end
        if size == "small" then return "thin_small" end
    end
    return size
end

local function slice(tex, m)
    tex:SetTextureSliceMargins(m, m, m, m)
    local modes = Enum and Enum.UITextureSliceMode
    tex:SetTextureSliceMode((modes and modes.Stretched) or 0)
end

-- Range check that also rejects NaN (it fails every comparison).
local function inRange(a, lo, hi)
    return type(a) == "number" and a >= lo and a <= hi
end

-- Dim a region to `dim` times the alpha it had (kept on it as glassBase while
-- dimmed, so a consumer's own alpha survives), or with a nil `dim` give that
-- alpha back. Dimming twice keeps the first base.
local function dimRegion(r, dim)
    if not r then return end
    if dim then
        if r.glassBase == nil then r.glassBase = r:GetAlpha() end
        r.glassDim = dim
        r:SetAlpha(r.glassBase * dim)
    elseif r.glassBase ~= nil then
        r:SetAlpha(r.glassBase)
        r.glassBase, r.glassDim = nil, nil
    end
end

-- Give a region a new alpha of its own: on a disabled surface it becomes the
-- base that enabling gives back, and the region stays dimmed until then.
local function setBase(r, a)
    if r.glassBase ~= nil then
        r.glassBase = a
        r:SetAlpha(a * r.glassDim)
    else
        r:SetAlpha(a)
    end
end

-- A gradient texture ignores SetAlpha on Forever (measured on the wash, #47;
-- porting guide section 3), so the wash and the edge's glow carry their alpha
-- in the gradient: white, clear at the bottom to glassPeak at the top, times
-- glassDim while their surface is disabled.
local function paintGradient(r)
    r:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, r.glassPeak * (r.glassDim or 1)))
end

-- dimRegion for a gradient region: the dim goes through the gradient.
-- `peak` stands in for the record a region built by an older copy lacks.
-- Without either, the dim is still recorded or cleared, so the next setter
-- that supplies a peak (SetEdge) paints it right; only the repaint waits.
-- Enabling gives back the alpha an older copy's dimRegion lowered.
local function dimGradient(r, dim, peak)
    if not r then return end
    if r.glassPeak == nil then r.glassPeak = peak end
    if dim then
        r.glassDim = dim
    elseif r.glassDim ~= nil or r.glassBase ~= nil then
        if r.glassBase ~= nil then r:SetAlpha(r.glassBase) end
        r.glassBase, r.glassDim = nil, nil
    else
        return
    end
    if r.glassPeak ~= nil then paintGradient(r) end
end

-- Paint an edge: the top line's alpha, the glow's peak, the bottom line's, the
-- glow's depth. Hidden at 0, so an unused edge costs nothing to draw. A
-- disabled surface's glow stays dimmed.
local function paintEdge(e, top, glow, bottom, glowh)
    e.top:SetColorTexture(1, 1, 1, top)
    e.glow.glassPeak = glow
    paintGradient(e.glow)
    e.glow:SetHeight(math.max(1, glowh))
    e.bottom:SetColorTexture(0, 0, 0, bottom)
    e.top:SetShown(top > 0)
    e.glow:SetShown(glow > 0)
    e.bottom:SetShown(bottom > 0)
end

-- The reflective shell's layers (r9, #56), as GlassRaidFrames' click-casting
-- editor and PetStable draw them (matched by the owner in game; References\
-- LIBGLASS-WINDOW-STYLING.md): orientation, then the first and second colour
-- (bottom then top for VERTICAL, left then right for HORIZONTAL).
local REFLECT = {
    rim = { "VERTICAL", { 0.55, 0.65, 0.75, 0.035 }, { 0.84, 0.88, 0.91, 0.52 } },
    top = { "HORIZONTAL", { 0.88, 0.91, 0.93, 0.58 }, { 0.65, 0.73, 0.8, 0.035 } },
    header = { "VERTICAL", { 0.77, 0.81, 0.85, 0 }, { 0.77, 0.81, 0.85, 0.105 } },
}
local REFLECT_KEYS = { "rim", "top", "header" }

-- Paint a reflection layer from its own gradient record, times glassDim
-- while its surface is disabled (its alpha is in the gradient, #47).
local function paintStops(r)
    local s, d = r.glassStops, r.glassDim or 1
    r:SetGradient(s[1], CreateColor(s[2][1], s[2][2], s[2][3], s[2][4] * d),
        CreateColor(s[3][1], s[3][2], s[3][3], s[3][4] * d))
end

local function paintSharedEdge(inst, e)
    local a, E = inst.STYLE.edge, inst.EDGE
    paintEdge(e, a, a * E.glow, a * E.bottom, E.glowh)
end

-- The fill: the bar's colour at STYLE.fillAlpha, (optionally) fading to
-- STYLE.fillEnd at its moving edge (the gradient spans the fill quad). A
-- gradient texture ignores SetAlpha, before or after (measured, #53), so the
-- fill's opacity is in its gradient (r8; until r7 every coloured fill drew
-- opaque). SetAlpha stays for a fill with no gradient: before its first
-- colour, or if SetGradient fails. No arithmetic on the colour beyond the
-- caller's own (plain) alpha. The bar's own instance's STYLE.
local function paintFill(inst, bar)
    local c, st = bar.trackColor, inst.STYLE
    local fill = bar:GetStatusBarTexture()
    fill:SetAlpha(st.fillAlpha)
    if not c then return end
    local a = c[4] * st.fillAlpha
    pcall(fill.SetGradient, fill, "HORIZONTAL",
        CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], a * st.fillEnd))
end

-- Re-applied after every colour change: the fill, and the track in the bar's
-- colour at STYLE.trackTop over its horizontal ramp.
local function tintTrack(inst, bar)
    local c, st = bar.trackColor, inst.STYLE
    if not c then return end
    paintFill(inst, bar)
    if bar.track then   -- a bar from older code may lack it
        pcall(bar.track.SetVertexColor, bar.track, c[1], c[2], c[3], st.trackTop)
    end
end

-- track_fade: alpha 1 over the first 30% of its width, smoothstep to 0 at 85%.
local TRACK_FADE_FROM, TRACK_FADE_TO = 0.30, 0.85

-- Where the track's ramp lies (r10). A trackLength of 0: across the whole bar,
-- the texture whole (as built until r9). A fraction: from the fill's moving
-- edge, the texture's fade part only, over that fraction of the bar's width,
-- kept by an OnSizeChanged hook installed the first time (a bar is sized by
-- its anchors). Its clip still ends it at the bar's end.
local function placeTrack(inst, bar)
    local t, state = bar.track, bar.glassState
    if not (t and state) then return end   -- a bar from older code may lack them
    local len = inst.STYLE.trackLength or 0
    t:ClearAllPoints()
    if len > 0 then
        local fill = bar:GetStatusBarTexture()
        t:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
        t:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
        t:SetTexCoord(TRACK_FADE_FROM, TRACK_FADE_TO, 0, 1)
        state.trackLength = len
        if not state.sizeHooked then
            state.sizeHooked = true
            bar:HookScript("OnSizeChanged", function(self, w) lib.impl.OnBarSize(self, w) end)
        end
        lib.impl.OnBarSize(bar, bar:GetWidth())
    else
        state.trackLength = nil
        t:SetAllPoints(bar)
        t:SetTexCoord(0, 1, 0, 1)
    end
end

--------------------------------------------------------------------------------
-- Builders
--------------------------------------------------------------------------------

-- A 9-sliced rounded mask owned by `host`, covering `anchor` (default: host)
-- inset by `inset` px. A mask masks textures of its own frame: give a child
-- its own mask anchored to the shape it must follow. A nil `margin` (r2)
-- means unsliced, stretched over the box: the disc masks.
function lib.impl.Mask(inst, host, file, margin, inset, anchor)
    local m = host:CreateMaskTexture()
    m:SetTexture(lib.MEDIA .. file, MASK_WRAP, MASK_WRAP)
    inset = inset or 0
    anchor = anchor or host
    m:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -inset)
    m:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset, inset)
    if margin ~= nil then slice(m, margin) end
    return m
end

-- A fine bright line along the top with a short sheen fading under it, and a
-- dark line along the bottom: a thinner, lit-from-above edge than the rim
-- alone (GlassChat, after an outside critique). Straight lines, kept off the
-- rounded corners by the mask's slice margin.
local function makeEdge(inst, g, host, S)
    local inset = S.maskMargin - 2
    local e = {}
    e.top = g.top:CreateTexture(nil, "OVERLAY", nil, 7)
    e.top:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -1)
    e.top:SetPoint("TOPRIGHT", host, "TOPRIGHT", -inset, -1)
    e.top:SetHeight(1)
    e.glow = g.top:CreateTexture(nil, "OVERLAY", nil, 5)
    e.glow:SetColorTexture(1, 1, 1, 1)
    e.glow:SetPoint("TOPLEFT", e.top, "BOTTOMLEFT", 0, 0)
    e.glow:SetPoint("TOPRIGHT", e.top, "BOTTOMRIGHT", 0, 0)
    e.bottom = g.top:CreateTexture(nil, "OVERLAY", nil, 7)
    e.bottom:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", inset, 1)
    e.bottom:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, 1)
    e.bottom:SetHeight(1)
    paintSharedEdge(inst, e)
    table.insert(inst._edges, e)
    return e
end

-- The body both builders share, after the shadow and mask: tint, grain and
-- wash under g.mask, then g.top with the dark rim and the rim (registered in
-- the instance's rim list). Sliced by S.rimMargin; discs have none.
local function buildBody(inst, host, g, S)
    local st = inst.STYLE
    local tint = host:CreateTexture(nil, "BACKGROUND", nil, -6)
    tint:SetAllPoints(host)
    local alpha = st.bodyAlpha
    if alpha == nil then alpha = st.tint[4] end
    tint:SetColorTexture(st.tint[1], st.tint[2], st.tint[3], alpha)
    tint:AddMaskTexture(g.mask)
    tint.glassColor = { st.tint[1], st.tint[2], st.tint[3], alpha }   -- r3: SetSurfaceTint(g) goes back to it
    g.tint = tint

    local grain = host:CreateTexture(nil, "BACKGROUND", nil, -5)
    grain:SetAllPoints(host)
    grain:SetTexture(lib.MEDIA .. "grain", "REPEAT", "REPEAT")
    grain:SetHorizTile(true)
    grain:SetVertTile(true)
    grain:SetAlpha(st.grain)
    grain:AddMaskTexture(g.mask)
    g.grain = grain

    local wash = host:CreateTexture(nil, "BACKGROUND", nil, -4)
    wash:SetAllPoints(host)
    wash:SetColorTexture(1, 1, 1, 1)
    wash.glassPeak = st.wash   -- r7: SetWash and SetSurfaceEnabled repaint from it
    paintGradient(wash)
    wash:AddMaskTexture(g.mask)
    g.wash = wash

    local top = CreateFrame("Frame", nil, host)
    top:SetAllPoints(host)
    top:SetFrameLevel(host:GetFrameLevel() + 10)
    g.top = top

    local dark = top:CreateTexture(nil, "OVERLAY", nil, 4)
    dark:SetTexture(lib.MEDIA .. S.dark)
    dark:SetAllPoints(top)
    if S.rimMargin then slice(dark, S.rimMargin) end
    g.dark = dark

    local rim = top:CreateTexture(nil, "OVERLAY", nil, 6)
    rim:SetTexture(lib.MEDIA .. S.rim)
    rim:SetAllPoints(top)
    if S.rimMargin then slice(rim, S.rimMargin) end
    rim:SetAlpha(st.rimAlpha)
    table.insert(inst._rims, rim)
    g.rim = rim
end

-- Apply the material to `host`. Returns a table of the regions it made:
-- g.top is the frame to parent text and anything that must sit above the rim.
-- Reads the instance's STYLE now, so a caller may change it between Applies.
function lib.impl.Apply(inst, host, size)
    size = rectSize(inst, size)
    local S = lib.SIZES[size]
    if S and S.shape == "disc" then
        -- Level 3: the consumer's line. The instance wrapper tail-calls us,
        -- and level 2 would be that lost frame (no position).
        error(MAJOR .. ": " .. size .. ' is a disc size: use Glass.Disc(host, "' .. size .. '")', 3)
    end
    local g = { size = size }

    local sh = host:CreateTexture(nil, "BACKGROUND", nil, -8)
    sh:SetTexture(lib.MEDIA .. S.shadow)
    sh:SetPoint("TOPLEFT", host, "TOPLEFT", S.shadowPad[1], S.shadowPad[2])
    sh:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", S.shadowPad[3], S.shadowPad[4])
    slice(sh, S.shadowMargin)
    g.shadow = sh
    local shadowAlpha = inst.STYLE.shadowAlpha
    if shadowAlpha ~= nil and shadowAlpha ~= 1 then sh:SetAlpha(shadowAlpha) end

    g.mask = inst.Mask(host, S.mask, S.maskMargin)

    buildBody(inst, host, g, S)

    g.edge = makeEdge(inst, g, host, S)

    return g
end

-- The round variant (r2): the same material on a square host, as a circle.
-- Its own builder, not Apply with a flag: nothing is sliced (a circle has no
-- straight run to stretch, so it works at any size, where a sliced mask on a
-- box small in both directions fails), there is no edge (g.edge is nil), and
-- the shadow is a symmetric outset proportional to the host. Returns the
-- same fields as Apply. The host must be square and sized before the call;
-- resize a disc later with SetScale, not SetSize (the shadow's outset is
-- computed here). Content on a child frame needs its own mask:
-- Glass.Mask(child, "disc_mask", nil, inset, host).
function lib.impl.Disc(inst, host, size)
    size = size or "disc"
    local S = lib.SIZES[size]
    if not S or S.shape ~= "disc" then
        error(MAJOR .. ': Disc takes "disc" or "disc_small", got ' .. tostring(size), 3)
    end
    local w, h = host:GetWidth(), host:GetHeight()
    if type(w) ~= "number" or type(h) ~= "number" or not (w > 0) or math.abs(w - h) > 0.01 then
        error(MAJOR .. ": Disc needs a square host, sized before the call (got "
            .. tostring(w) .. "x" .. tostring(h) .. ")", 3)
    end
    local g = { size = size }

    local out = w * S.shadowOutset
    local sh = host:CreateTexture(nil, "BACKGROUND", nil, -8)
    sh:SetTexture(lib.MEDIA .. S.shadow)
    sh:SetPoint("TOPLEFT", host, "TOPLEFT", -out, out)
    sh:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", out, -out)
    g.shadow = sh
    local shadowAlpha = inst.STYLE.shadowAlpha
    if shadowAlpha ~= nil and shadowAlpha ~= 1 then sh:SetAlpha(shadowAlpha) end

    g.mask = inst.Mask(host, S.mask, nil)

    buildBody(inst, host, g, S)

    return g
end

-- The small glass button behind a symbol (r5): GlassChat's buttons beside
-- the chat and AltStable's portrait toggle, which sits among them. The
-- material goes on a child frame (the pill) one level under `button`, with
-- g.top moved down to the pill's level: Apply puts the rims at host + 10,
-- where they would draw over the button's own art (its symbol). No grain
-- (noise at 24 px) and no shadow (it spills onto the next button), both at
-- alpha 0. The button's highlight is softened, not removed, so hovering
-- still shows: set any highlight texture before the call.
-- opts: size (a rect size, default "small"), side (px: a square centred on
-- the button; nil covers the button), highlight (its alpha, default 0.4;
-- false leaves it alone). Returns pill, g. The symbol stays the caller's.
-- Everything is checked before anything is built, so a bad call leaves no
-- half-built surface registered with the instance.
-- When the button's level changes, call RelevelPill(pill).
local PILL_HIGHLIGHT = 0.4

local function levelPill(pill, top)
    local level = math.max(0, pill:GetParent():GetFrameLevel() - 1)
    pill:SetFrameLevel(level)
    top:SetFrameLevel(level)
end

function lib.impl.Pill(inst, button, opts)
    if type(button) ~= "table" or type(button.GetFrameLevel) ~= "function" then
        error(MAJOR .. ": Pill takes a button frame, got " .. tostring(button), 3)
    end
    if opts ~= nil and type(opts) ~= "table" then
        error(MAJOR .. ": Pill takes an options table ({ size = ... }), got " .. tostring(opts), 3)
    end
    opts = opts or {}
    local size = opts.size or "small"
    local S = lib.SIZES[size]
    if not S or S.shape == "disc" then
        error(MAJOR .. ": Pill takes a rect size (\"small\", \"thin_small\", ...), got " .. tostring(size), 3)
    end
    local hl = opts.highlight
    if hl ~= nil and hl ~= false and not inRange(hl, 0, 1) then
        error(MAJOR .. ": Pill's highlight is an alpha in 0..1 or false, got " .. tostring(hl), 3)
    end
    local pill = CreateFrame("Frame", nil, button)
    if opts.side then
        pill:SetSize(opts.side, opts.side)
        pill:SetPoint("CENTER", button, "CENTER", 0, 0)
    else
        pill:SetAllPoints(button)
    end
    local g = inst.Apply(pill, size)
    pill.glassPill = g   -- what RelevelPill needs, on the frame
    levelPill(pill, g.top)
    g.grain:SetAlpha(0)
    g.shadow:SetAlpha(0)
    if hl ~= false then
        local h = button.GetHighlightTexture and button:GetHighlightTexture()
        if h then h:SetAlpha(hl or PILL_HIGHLIGHT) end
    end
    return pill, g
end

-- Put a pill (and its rims) back one level under its button, after the
-- button's level changed. False for a frame Pill didn't build.
function lib.impl.RelevelPill(inst, pill)
    local g = type(pill) == "table" and pill.glassPill
    if not g then return false end
    levelPill(pill, g.top)
    return true
end

-- The reflective shell (r9, #56): three static layers that light a rect
-- surface from above. A second rim, its gradient bright along the top and
-- almost clear at the bottom; a 1 px highlight along the top, bright on the
-- left; and, with opts.header (px), a soft reflection over that much of the
-- body's top, fading to clear (fit it to the window's header, so it is gone
-- before dense content starts). Returns g.reflect = { rim, top, header }
-- (header nil without opts.header). Once per surface; no new texture, no
-- OnUpdate. The layers' opacity is in their gradients, so SetAlpha does
-- nothing to them (#47): hide one with SetShown. SetSurfaceEnabled dims them,
-- repainting from the gradient built here, and a surface disabled before the
-- call gets them dimmed. The rest of the surface is the caller's: the shells
-- that use it also turn the edge off (SetEdge(g, 0, 0, 0)), lower the rim
-- (SetSurfaceAlpha) and add a backing (LIBGLASS-WINDOW-STYLING.md).
function lib.impl.Reflect(inst, g, host, opts)
    local S = type(g) == "table" and g.top and g.mask and lib.SIZES[g.size]
    if not S or S.shape == "disc" then
        error(MAJOR .. ": Reflect takes a rect surface from Apply, got " .. tostring(g), 3)
    end
    if type(host) ~= "table" or type(host.CreateTexture) ~= "function" then
        error(MAJOR .. ": Reflect takes the surface's host frame, got " .. tostring(host), 3)
    end
    if opts ~= nil and type(opts) ~= "table" then
        error(MAJOR .. ": Reflect takes an options table ({ header = ... }), got " .. tostring(opts), 3)
    end
    local header = opts and opts.header
    if header ~= nil and not (type(header) == "number" and header >= 0 and header < math.huge) then
        error(MAJOR .. ": Reflect's header is a height in px, 0 or more, got " .. tostring(header), 3)
    end
    if g.reflect then error(MAJOR .. ": this surface already has its reflection", 3) end
    local dim = g.rim and g.rim.glassDim
    local function layer(r, key)
        r.glassStops = fill({}, REFLECT[key])
        r.glassDim = dim
        paintStops(r)
        return r
    end
    local rf = {}

    local rim = g.top:CreateTexture(nil, "OVERLAY", nil, 6)
    rim:SetTexture(lib.MEDIA .. S.rim)
    rim:SetAllPoints(g.top)
    slice(rim, S.rimMargin)
    rf.rim = layer(rim, "rim")

    local top = g.top:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetColorTexture(1, 1, 1, 1)
    top:SetPoint("TOPLEFT", host, "TOPLEFT", S.maskMargin, -1)
    top:SetPoint("TOPRIGHT", host, "TOPRIGHT", -S.maskMargin, -1)
    top:SetHeight(1)
    rf.top = layer(top, "top")

    if header and header > 0 then
        local h = host:CreateTexture(nil, "BACKGROUND", nil, -3)
        h:SetColorTexture(1, 1, 1, 1)
        h:AddMaskTexture(g.mask)
        h:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
        h:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
        h:SetHeight(header)
        rf.header = layer(h, "header")
    end
    g.reflect = rf
    return rf
end

-- A content frame level for things drawn between the body and the rim.
function lib.impl.ContentLevel(inst, host)
    return host:GetFrameLevel() + 2
end

-- Content inset (px) inside the bevel for this material size.
function lib.impl.Inset(inst, size)
    return lib.SIZES[rectSize(inst, size)].inset
end

-- A glass StatusBar: masked rounded fill, ADD gloss, inner shadow, thin edge.
-- Colour it with bar:SetStatusBarColor(r, g, b). Values may be secret:
-- SetMinMaxValues/SetValue take them without Lua touching them.
function lib.impl.Bar(inst, parent, height)
    local st = inst.STYLE
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local mask = inst.Mask(bar, "bar_mask", 8)
    bar.glassMask = mask

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.15)
    bg:AddMaskTexture(mask)

    local frost = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
    frost:SetAllPoints(bar)
    frost:SetColorTexture(1, 1, 1, 1)
    frost:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, st.frost))
    frost:AddMaskTexture(mask)

    bar:SetStatusBarTexture(lib.MEDIA .. "bar_fill")
    bar:GetStatusBarTexture():AddMaskTexture(mask)
    -- Translucent fill: the texture's own alpha, so SetStatusBarColor (which
    -- sets vertex colour) never resets it. Text lives on the host's g.top,
    -- not on the bar, so it stays fully opaque.
    bar:GetStatusBarTexture():SetAlpha(st.fillAlpha)
    table.insert(inst._bars, bar)

    -- (After the fill exists: the clip anchors to its moving edge.)
    -- The missing health/power, as in the mockup: the bar's own colour, full
    -- over the first 30% of the bar, easing to clear glass by 85%. The ramp
    -- spans the whole bar but lives in a clip frame that starts at the fill's
    -- moving edge, so it only shows past the fill: a full bar stays even, and
    -- the ramp never doubles up under the translucent fill.
    local trackClip = CreateFrame("Frame", nil, bar)
    trackClip:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    trackClip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    trackClip:SetClipsChildren(true)
    trackClip:SetFrameLevel(bar:GetFrameLevel() + lib.TRACK_LEVEL)
    local track = trackClip:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(bar)
    track:SetTexture(lib.MEDIA .. "track_fade")
    track:SetVertexColor(1, 1, 1, 0)
    track:AddMaskTexture(inst.Mask(trackClip, "bar_mask", 8, 0, bar))
    bar.track, bar.trackClip = track, trackClip
    -- What the hooks need, on the bar rather than in their closures, so they
    -- can dispatch to whichever copy of the library is newest when they run.
    bar.glassState = { inst = inst, clip = trackClip }
    hooksecurefunc(bar, "SetStatusBarColor", function(self, r, g, b, a)
        lib.impl.OnBarColor(self, r, g, b, a)
    end)
    if (st.trackLength or 0) > 0 then placeTrack(inst, bar) end

    local over = CreateFrame("Frame", nil, bar)
    over:SetAllPoints(bar)
    over:SetFrameLevel(bar:GetFrameLevel() + lib.OVERLAY_LEVEL)
    bar.overlay = over
    bar.glassState.over = over
    local omask = inst.Mask(over, "bar_mask", 8)

    local gloss = over:CreateTexture(nil, "OVERLAY", nil, 1)
    gloss:SetAllPoints(bar)
    gloss:SetTexture(lib.MEDIA .. "gloss")
    gloss:SetBlendMode("ADD")
    gloss:SetAlpha(st.gloss)
    gloss:AddMaskTexture(omask)

    local inner = over:CreateTexture(nil, "OVERLAY", nil, 2)
    inner:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
    inner:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
    inner:SetHeight(math.max(3, math.floor(height * 0.45)))
    bar.glassState.inner = inner
    -- Keep the shade at 45% when the bar is resized later (the player's
    -- bars shrink while its inside cast row shows).
    hooksecurefunc(bar, "SetHeight", function(self, h)
        lib.impl.OnBarHeight(self, h)
    end)
    inner:SetColorTexture(1, 1, 1, 1)
    inner:SetGradient("VERTICAL", CreateColor(0, 0, 0, st.innerShadow), CreateColor(0, 0, 0, 0))
    inner:AddMaskTexture(omask)

    local edge = over:CreateTexture(nil, "OVERLAY", nil, 3)
    edge:SetAllPoints(bar)
    edge:SetTexture(lib.MEDIA .. "bar_edge")
    slice(edge, 8)

    -- Keep the overlay and the track's clip at their offsets when the caller moves the bar.
    hooksecurefunc(bar, "SetFrameLevel", function(self, level)
        lib.impl.OnBarLevel(self, level)
    end)
    return bar
end

-- The bar hooks' bodies. Only re-tint on an actual change: painters recolour
-- on every health and power event. A 4th (alpha) argument is honoured.
function lib.impl.OnBarColor(bar, r, g, b, a)
    local state = bar.glassState
    if not state then return end
    a = a or 1
    local c = bar.trackColor
    if c and c[1] == r and c[2] == g and c[3] == b and c[4] == a then return end
    bar.trackColor = { r, g, b, a }
    tintTrack(state.inst, bar)
end

function lib.impl.OnBarHeight(bar, h)
    local state = bar.glassState
    if state and state.inner and type(h) == "number" then
        state.inner:SetHeight(math.max(3, math.floor(h * 0.45)))
    end
end

-- r10: the edge ramp's width follows the bar's (plain) width.
function lib.impl.OnBarSize(bar, w)
    local state = bar.glassState
    local len = state and state.trackLength
    if len and bar.track and type(w) == "number" then
        bar.track:SetWidth(math.max(1, w * len))
    end
end

function lib.impl.OnBarLevel(bar, level)
    local state = bar.glassState
    if not state then return end
    if state.over then state.over:SetFrameLevel(level + lib.OVERLAY_LEVEL) end
    if state.clip then state.clip:SetFrameLevel(level + lib.TRACK_LEVEL) end
end

-- The client eases a StatusBar to its new value itself (secret values
-- included: Lua never sees the in-between). Enum names are not in the API
-- dump, so fall back to an instant change when they are missing.
function lib.impl.Smooth(inst)
    local e = Enum and Enum.StatusBarInterpolation
    return e and e.ExponentialEaseOut or nil
end

-- Set a bar's range and value, eased unless `snap`. Both calls take the same
-- interpolation, so a max change doesn't jump the fill and then slide. If the
-- client rejects the eased call, fall back to an instant one rather than
-- leaving the bar frozen.
function lib.impl.SetBar(inst, bar, maxValue, value, snap)
    local interp = (not snap) and inst.Smooth() or nil
    if interp and pcall(bar.SetMinMaxValues, bar, 0, maxValue, interp)
        and pcall(bar.SetValue, bar, value, interp) then return end
    bar:SetMinMaxValues(0, maxValue)
    bar:SetValue(value)
end

-- A diagonal highlight that sweeps across the body once per Play(). Clipped
-- by its own mask on g.top, which stays put while the texture translates.
-- Returns the AnimationGroup; call :Stop() then :Play() to sweep.
function lib.impl.Sheen(inst, g, host, width, height)
    local S = lib.SIZES[g.size]
    local mask = inst.Mask(g.top, S.mask, S.maskMargin)
    local s = g.top:CreateTexture(nil, "OVERLAY", nil, 5)
    s:SetTexture(lib.MEDIA .. "sheen2")
    s:SetSize(math.floor(width * 0.5), height + 20)
    s:SetPoint("RIGHT", g.top, "LEFT", 0, 0)
    s:SetBlendMode("ADD")
    s:SetAlpha(0)
    s:AddMaskTexture(mask)

    local ag = s:CreateAnimationGroup()
    local move = ag:CreateAnimation("Translation")
    move:SetOffset(width + math.floor(width * 0.5), 0)
    move:SetDuration(0.9)
    move:SetSmoothing("IN_OUT")
    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(inst.STYLE.sheenAlpha)
    fadeIn:SetDuration(0.25)
    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(inst.STYLE.sheenAlpha)
    fadeOut:SetToAlpha(0)
    fadeOut:SetStartDelay(0.65)
    fadeOut:SetDuration(0.25)
    return ag
end

-- A FontString in the instance's glass font, tracked so SetFont can restyle
-- every one of them later.
function lib.impl.Font(inst, parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", nil, 7)
    local f = lib.FONTS[inst.fontKey] or lib.FONTS.arial
    fs:SetFont(f.file, size + f.bump, "")
    -- Opaque, slightly longer shadow: at a 0.64 UI scale a 1-unit offset is
    -- under a pixel, and pale bars (a friendly target's green) washed it out.
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1.5, -1.5)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    table.insert(inst._fontStrings, { fs = fs, size = size })
    return fs
end

--------------------------------------------------------------------------------
-- Live setters: each touches only the surfaces its own instance built
--------------------------------------------------------------------------------

-- Live-tune how far the fill fades towards its edge (1 = no fade).
function lib.impl.SetFillEnd(inst, a)
    if not inRange(a, 0, 1) then return false end
    inst.STYLE.fillEnd = a
    for _, bar in ipairs(inst._bars) do tintTrack(inst, bar) end
    return true
end

-- Live-tune how strongly the missing part shows the bar's colour (top alpha).
function lib.impl.SetTrackAlpha(inst, a)
    if not inRange(a, 0, 1) then return false end
    inst.STYLE.trackTop = a
    for _, bar in ipairs(inst._bars) do tintTrack(inst, bar) end
    return true
end

-- Live: where every bar's track ramp lies (r10). 0 = across the whole bar
-- (the default); a fraction in 0.01..1 = from the fill's moving edge, fading
-- to clear over that fraction of the bar.
function lib.impl.SetTrackLength(inst, len)
    if len ~= 0 and not inRange(len, 0.01, 1) then return false end
    inst.STYLE.trackLength = len
    for _, bar in ipairs(inst._bars) do placeTrack(inst, bar) end
    return true
end

-- Live-tune the bright rim's opacity on every glass surface built so far
-- (a disabled surface's rim takes it as its base and stays dimmed), except
-- the rims given their own alpha (r9: SetSurfaceRim, SetSurfaceAlpha).
function lib.impl.SetRimAlpha(inst, a)
    if not inRange(a, 0.2, 1) then return false end
    inst.STYLE.rimAlpha = a
    for _, rim in ipairs(inst._rims) do
        if not rim.glassOwnAlpha then setBase(rim, a) end
    end
    return true
end

-- Live-tune the bar fill opacity on every glass bar built so far: through
-- the fill's gradient (r8, #53), and its alpha for a bar with no colour yet.
function lib.impl.SetFillAlpha(inst, a)
    if not inRange(a, 0.2, 1) then return false end
    inst.STYLE.fillAlpha = a
    for _, bar in ipairs(inst._bars) do paintFill(inst, bar) end
    return true
end

-- Live-tune the directional edge on every glass surface built so far (its top
-- line; the glow and bottom line keep their ratios). 0 hides it.
function lib.impl.SetEdgeAlpha(inst, a)
    if not inRange(a, 0, 1) then return false end
    inst.STYLE.edge = a
    for _, e in ipairs(inst._edges) do
        if not e.custom then paintSharedEdge(inst, e) end
    end
    return true
end

-- One host's own edge values (GlassChat's /gchat tune); SetEdgeAlpha leaves
-- it alone from then on.
function lib.impl.SetEdge(inst, g, top, glow, bottom, glowh)
    if not g.edge then return end   -- a surface from older code may lack it
    g.edge.custom = true
    paintEdge(g.edge, top, glow, bottom, glowh or inst.EDGE.glowh)
end

-- One surface's own body tint (r3): an accent on one button, a near-opaque
-- dialog. A nil alpha keeps the surface's built one; no colour at all goes
-- back to the colour it was built with (an older copy's surface: STYLE.tint).
-- Only this setter repaints g.tint's colour; no instance setter touches it.
-- Plain numbers only: they are range-checked.
function lib.impl.SetSurfaceTint(inst, g, r, gg, b, a)
    if type(g) ~= "table" or not g.tint then return false end
    local built = g.tint.glassColor or inst.STYLE.tint
    if r == nil then
        r, gg, b = built[1], built[2], built[3]
    end
    if a == nil then a = built[4] end
    if not (inRange(r, 0, 1) and inRange(gg, 0, 1) and inRange(b, 0, 1) and inRange(a, 0, 1)) then
        return false
    end
    g.tint:SetColorTexture(r, gg, b, a)
    return true
end

-- One surface's own rim (r9, #40): its colour, as vertex RGB (the texture
-- keeps its shading), and optionally its alpha. A nil alpha keeps the current
-- one. An alpha makes it the surface's own: SetRimAlpha leaves it alone from
-- then on, as SetEdgeAlpha does a host's own edge. SetSurfaceRim(g) with
-- nothing else is the built look again: white, at the instance's rimAlpha,
-- following SetRimAlpha. A disabled rim stays dimmed, the alpha its base.
-- No colour with an alpha is white. Plain numbers only: they are range-checked.
function lib.impl.SetSurfaceRim(inst, g, r, gg, b, a)
    if type(g) ~= "table" or not g.rim then return false end
    if r == nil and gg == nil and b == nil and a == nil then
        g.rim:SetVertexColor(1, 1, 1, 1)
        g.rim.glassOwnAlpha = nil
        setBase(g.rim, inst.STYLE.rimAlpha)
        return true
    end
    if r == nil then r, gg, b = 1, 1, 1 end
    if not (inRange(r, 0, 1) and inRange(gg, 0, 1) and inRange(b, 0, 1) and (a == nil or inRange(a, 0, 1))) then
        return false
    end
    g.rim:SetVertexColor(r, gg, b, 1)
    if a ~= nil then
        g.rim.glassOwnAlpha = true
        setBase(g.rim, a)
    end
    return true
end

-- One surface's own alpha for one of its plain regions (r9, #40): "rim",
-- "dark", "grain" or "shadow". What a consumer's own g.dark:SetAlpha(...)
-- does, without fighting the library: on a disabled surface it becomes the
-- alpha enabling gives back (the region stays dimmed until then), and a rim
-- set here is the surface's own, which SetRimAlpha leaves alone (until
-- SetSurfaceRim(g)). The tint's alpha is SetSurfaceTint's, the wash's
-- SetWash's, the edge's SetEdge's. Plain numbers in 0..1.
local SURFACE_ALPHA = { rim = true, dark = true, grain = true, shadow = true }

function lib.impl.SetSurfaceAlpha(inst, g, part, a)
    if type(g) ~= "table" or not SURFACE_ALPHA[part] or not g[part] or not inRange(a, 0, 1) then return false end
    if part == "rim" then g.rim.glassOwnAlpha = true end
    setBase(g[part], a)
    return true
end

-- One surface's disabled look (r3): the alphas of its tint, grain, wash,
-- dark rim, rim and edge scaled by STYLE.disabledAlpha, so an inactive
-- control reads as inactive; enabling gives each region back the alpha it
-- had (a consumer's own included). Region alpha only, so it composes with
-- SetSurfaceTint, SetEdge and SetEdgeAlpha, which set colours; SetRimAlpha
-- keeps a disabled rim dimmed. Text on g.top is the caller's to dim.
-- The wash and the edge's glow ignore SetAlpha (#47): r7 dims them through
-- their gradients, from the peak SetWash, SetEdge or SetEdgeAlpha last set
-- (for a region an older copy built: the instance's STYLE). r9: Reflect's
-- layers too, through their gradients.
-- `enabled` is truth-tested: pass a plain value.
function lib.impl.SetSurfaceEnabled(inst, g, enabled)
    if type(g) ~= "table" or not g.tint then return false end
    local dim = (not enabled) and inst.STYLE.disabledAlpha or nil
    dimRegion(g.tint, dim)
    dimRegion(g.grain, dim)
    dimGradient(g.wash, dim, inst.STYLE.wash)
    dimRegion(g.dark, dim)
    dimRegion(g.rim, dim)
    if g.edge then
        dimRegion(g.edge.top, dim)
        dimGradient(g.edge.glow, dim, (not g.edge.custom) and inst.STYLE.edge * inst.EDGE.glow or nil)
        dimRegion(g.edge.bottom, dim)
    end
    if type(g.reflect) == "table" then
        for _, key in ipairs(REFLECT_KEYS) do
            local r = g.reflect[key]
            if r and r.glassStops and (dim or r.glassDim ~= nil) then
                r.glassDim = dim
                paintStops(r)
            end
        end
    end
    return true
end

-- One surface's wash (r7): the peak of its top-down white gradient, 0 hides
-- it. The way to change a wash: SetAlpha has no effect on a gradient texture
-- (#47), and SetSurfaceEnabled repaints the wash from the peak recorded here,
-- so a wash repainted with the consumer's own SetGradient would be overwritten
-- on a disable. A disabled surface's wash stays dimmed. Plain numbers only.
function lib.impl.SetWash(inst, g, top)
    if type(g) ~= "table" or not g.wash or not inRange(top, 0, 1) then return false end
    g.wash.glassPeak = top
    paintGradient(g.wash)
    g.wash:SetShown(top > 0)
    return true
end

function lib.impl.SetFont(inst, key)
    local f = lib.FONTS[key]
    if not f then return false end
    inst.fontKey = key
    for _, e in ipairs(inst._fontStrings) do e.fs:SetFont(f.file, e.size + f.bump, "") end
    return true
end

--------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------

-- Give `inst` whatever this copy defines and it lacks: functions, STYLE/EDGE
-- keys, TUNABLES entries, registries. Never overwrites, never repaints. Run
-- by New, and on every older instance when this copy upgrades the library.
function lib.impl.Migrate(inst)
    inst.STYLE = fillMissing(inst.STYLE or {}, lib.defaults.STYLE)
    inst.EDGE = fillMissing(inst.EDGE or {}, lib.defaults.EDGE)
    if inst.fontKey == nil then inst.fontKey = lib.defaults.fontKey end
    inst._rims = inst._rims or {}
    inst._edges = inst._edges or {}
    inst._bars = inst._bars or {}
    inst._fontStrings = inst._fontStrings or {}
    for _, name in ipairs(lib.FUNCTIONS) do
        if rawget(inst, name) == nil then
            inst[name] = function(...) return lib.impl[name](inst, ...) end
        end
    end
    inst.TUNABLES = inst.TUNABLES or {}
    local have = {}
    for _, t in ipairs(inst.TUNABLES) do
        if type(t) == "table" and t.key ~= nil then have[t.key] = true end   -- tolerate a consumer's own entries
    end
    for _, d in ipairs(lib.defaults.TUNABLES) do
        if not have[d.key] then
            local t = {}
            for k, v in pairs(d) do if k ~= "fn" then t[k] = v end end
            t.set = inst[d.fn]
            t.default = inst.STYLE[d.style]
            table.insert(inst.TUNABLES, t)
        end
    end
    setmetatable(inst, lib.instanceMT)
    return inst
end

-- The presets: construction recipes over the defaults (docs/GLASS-MATERIAL.md
-- section 4). "classic" (r11) is the defaults alone, as with no preset. r6's
-- clean: thin rims, no grain, softer bars and shadow, neutral empty tracks.
-- r11's pearl: clean with a softer upper light (wash, bar gloss and frost),
-- keeping the bar's rounded fill and its inner shade. Private to this copy:
-- the winning copy's New uses its own, and a built surface is never restyled.
local PRESETS = {
    classic = {},
    clean = { grain = 0, gloss = 0.25, innerShadow = 0.15, trackTop = 0, shadowAlpha = 0.30, thinRim = true },
}
PRESETS.pearl = fill(fill({}, PRESETS.clean), { wash = 0.10, gloss = 0.15, frost = 0.06 })

-- A per-addon instance: its own STYLE (defaults, opts.preset, opts.style,
-- then opts.bodyAlpha as an independent body opacity), EDGE,
-- fontKey (opts.font), TUNABLES and surfaces. Shared read-only: MEDIA, SIZES,
-- FONTS, TRACK_LEVEL, OVERLAY_LEVEL. inst.preset (r11) is the preset asked
-- for, "classic" without one; an instance an older copy made has none (nil:
-- unknown), and an upgrade never sets it.
function lib:New(opts)
    if self ~= lib then
        error(MAJOR .. ': call it as LibStub("LibGlass-1.0"):New(opts), with a colon', 2)
    end
    local _, active = LibStub:GetLibrary(MAJOR)
    if lib.ready ~= active then
        error(MAJOR .. ": the loaded copy (MINOR " .. tostring(active) .. ") did not finish loading"
            .. " (ready = " .. tostring(lib.ready) .. "); see the first error this session", 2)
    end
    opts = opts or {}
    if opts.preset ~= nil and not PRESETS[opts.preset] then
        error(MAJOR .. ": unknown preset " .. tostring(opts.preset) .. ' (use "classic", "clean" or "pearl", or omit it)', 2)
    end
    if opts.bodyAlpha ~= nil and not inRange(opts.bodyAlpha, 0, 1) then
        error(MAJOR .. ": bodyAlpha must be a plain number in 0..1", 2)
    end
    if opts.font ~= nil and not lib.FONTS[opts.font] then
        error(MAJOR .. ": unknown font " .. tostring(opts.font) .. " (see FONTS)", 2)
    end
    local inst = { STYLE = fill({}, lib.defaults.STYLE), fontKey = opts.font, preset = opts.preset or "classic" }
    -- Opt-in only. Explicit style overrides win; opacity is independent of
    -- the preset and applied last so a caller can keep its own tint RGB.
    fill(inst.STYLE, PRESETS[inst.preset])
    if opts.style then fill(inst.STYLE, opts.style) end
    if opts.bodyAlpha ~= nil then inst.STYLE.bodyAlpha = opts.bodyAlpha end
    lib.impl.Migrate(inst)
    table.insert(lib.instances, inst)
    return inst
end

-- Upgrading in place: older instances get what this copy adds, nothing else.
for _, inst in ipairs(lib.instances) do lib.impl.Migrate(inst) end

-- Test-only internals.
lib._test = { fill = fill, fillMissing = fillMissing, inRange = inRange }

lib.ready = MINOR
