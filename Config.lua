--[[----------------------------------------------------------------------------
    MeetingStoneEllesmereUI -- Config.lua

    Saved settings, plus the registries that let a setting change repaint what is
    already on screen instead of demanding a reload.

    Every value that used to be a hardcoded constant in Widgets.lua lives here.
    Nothing in this file touches a widget: it owns the numbers and the "who needs
    repainting when this key changes" map, and delegates the painting itself to
    the Apply* functions in Widgets.lua.
------------------------------------------------------------------------------]]

local ADDON, ns = ...

-------------------------------------------------------------------------------
--  Defaults. These are exactly the values the 1.0 release shipped hardcoded, so
--  a fresh install looks identical to what it replaced.
-------------------------------------------------------------------------------
local DEFAULTS = {
    -- Window / popup backdrop. Ours as of 1.1: EllesmereUI's S.Shell owns its own
    -- colour and opacity in EllesmereUIDB, which we cannot (and should not) write
    -- to, so a transparency slider was impossible while we used it. We now draw
    -- the backdrop and keep only EllesmereUI's border.
    bgColor      = { 0.06, 0.06, 0.06 },
    bgAlpha      = 0.92,
    topBar       = true,          -- 25px darker band behind the title row
    topBarShade  = 0.10,          -- contrast vs bgColor (0 = same, 1 = white)

    -- Fonts.
    --
    -- The three absolute sizes cover everything driven by a font object (list
    -- cells, tab labels, and button/checkbox/dropdown labels). fontDelta covers
    -- the remaining plain FontStrings and is RELATIVE, so MeetingStone's own size
    -- hierarchy (headings large, footnotes small) survives.
    --
    -- 12 across the board is the stock Blizzard body size; 1.0 shipped these two
    -- points smaller, which read as too small once every string had moved onto one
    -- face. fontDelta now defaults to no change for the same reason.
    fontDelta     = 0,
    listFontSize  = 12,
    tabFontSize   = 12,
    labelFontSize = 12,

    -- Column header strip on every DataGridView (活动列表, 申请列表, ...).
    --
    -- Deliberately NOT given its own opacity: bgAlpha is meant to be the one
    -- global transparency, so the header takes its alpha from there and earns its
    -- contrast from ns.ShadeOf instead -- which lightens, because a near-black
    -- window colour cannot be made visibly darker (see the note there).
    headerShade  = 0.14,

    -- Stop MeetingStone re-opening a filter popup every time the activity type is
    -- restored (which includes the automatic restore right after login).
    noAutoFilterPopup = false,

    -- Mirror MeetingStoneEX's 缺职责/已有职责 filters onto the main bottom bar.
    -- Proxies only -- they click the real checkboxes. Off means they are never
    -- built; turning it off after the fact is reload-bound.
    roleFilterBar = true,

    -- 成员 column icon scaling. OFF by default and deliberately so: the column is a
    -- Blizzard LFGListGroupDataDisplayTemplate with a fixed header width, and
    -- scaling it up can overflow into the neighbouring column. Opt in and look.
    memberIconScale = false,

    -- List rows
    skinRows     = true,          -- turning OFF is reload-bound: the stock row art
                                  -- is already alpha'd out and we keep no original to restore
    zebra        = true,
    zebraAlpha   = 0.12,
    hoverAlpha   = 0.04,
    selectAlpha  = 0.08,
    selectBar    = true,
    barWidth     = 2,

    -- Bottom tab plate. Separate from bgColor on purpose: the tab row sits
    -- OUTSIDE the window, over the game world, so it usually wants to be opaque
    -- even when the window itself is not.
    tabColor     = { 0.06, 0.06, 0.06 },
    tabAlpha     = 1,
}
ns.DEFAULTS = DEFAULTS

-------------------------------------------------------------------------------
--  Accessors
-------------------------------------------------------------------------------
function ns.DB()
    MeetingStoneEllesmereUIDB = MeetingStoneEllesmereUIDB or {}
    return MeetingStoneEllesmereUIDB
end

function ns.Get(key)
    local db = MeetingStoneEllesmereUIDB
    local v = db and db[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

-- Colours are stored as {r, g, b}; returns three numbers so call sites read like
-- every other colour call in the addon.
function ns.GetColor(key)
    local c = ns.Get(key)
    if type(c) ~= "table" then c = DEFAULTS[key] end
    return c[1] or 0, c[2] or 0, c[3] or 0
end

function ns.IsDefault(key)
    local db = MeetingStoneEllesmereUIDB
    return not (db and db[key] ~= nil)
end

-------------------------------------------------------------------------------
--  Which repaint does a key need? Anything not listed repaints everything, which
--  is cheap enough (it is a handful of table walks) and keeps the map honest --
--  a new key that nobody remembered to wire still takes effect.
-------------------------------------------------------------------------------
local REFRESH = {
    bgColor      = "RefreshAll",     -- tints the header strip as well
    bgAlpha      = "RefreshAll",     -- the one global opacity: headers follow it
    topBar       = "ApplySurfaces",
    topBarShade  = "ApplySurfaces",

    fontDelta     = "ApplyFonts",
    listFontSize  = "ApplyListFont",
    tabFontSize   = "ApplyTabFont",
    labelFontSize = "ApplyLabelFonts",

    headerShade     = "ApplyHeaders",
    memberIconScale = "ApplyMemberIcons",
    roleFilterBar   = "RefreshAll",
    -- Hooking is one-shot; turning it off again is reload-bound.
    noAutoFilterPopup = "RefreshAll",

    zebra        = "ApplyRows",
    zebraAlpha   = "ApplyRows",
    hoverAlpha   = "ApplyRows",
    selectAlpha  = "ApplyRows",
    selectBar    = "ApplyRows",
    barWidth     = "ApplyRows",

    tabColor     = "ApplyTabs",
    tabAlpha     = "ApplyTabs",
}

function ns.RefreshAll()
    ns.Safe(ns.ApplySurfaces)
    ns.Safe(ns.ApplyFonts)
    ns.Safe(ns.ApplyListFont)
    ns.Safe(ns.ApplyTabFont)
    ns.Safe(ns.ApplyLabelFonts)
    ns.Safe(ns.ApplyRows)
    ns.Safe(ns.ApplyTabs)
    ns.Safe(ns.ApplyHeaders)
    ns.Safe(ns.ApplyMemberIcons)
end

function ns.Set(key, value)
    ns.DB()[key] = value
    local fn = REFRESH[key]
    if fn then
        ns.Safe(ns[fn])
    else
        ns.RefreshAll()
    end
    if ns.OnSettingChanged then ns.Safe(ns.OnSettingChanged, key) end
end

function ns.ResetAll()
    local db = ns.DB()
    for key in pairs(DEFAULTS) do db[key] = nil end
    ns.RefreshAll()
    if ns.OnSettingChanged then ns.Safe(ns.OnSettingChanged) end
end

-------------------------------------------------------------------------------
--  Registries. Weak-keyed: a setting change walks these to repaint what already
--  exists, so nothing needs a reload that does not genuinely need one.
-------------------------------------------------------------------------------
local function WeakSet() return setmetatable({}, { __mode = "k" }) end

ns.surfaces = WeakSet()   -- frames carrying our backdrop
ns.rows     = WeakSet()   -- skinned list rows
ns.tabs     = WeakSet()   -- skinned tab buttons
ns.fonted   = WeakSet()   -- FontStrings we re-sized (fontDelta)
ns.grids    = WeakSet()   -- DataGridView cells + their extra FontStrings
ns.headers  = WeakSet()   -- DataGridView column-header buttons
ns.members  = WeakSet()   -- MemberDisplay role/count widgets

function ns.Track(set, obj)
    if obj then set[obj] = true end
end
