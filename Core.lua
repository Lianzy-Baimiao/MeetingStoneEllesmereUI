--[[----------------------------------------------------------------------------
    MeetingStoneEllesmereUI -- Core.lua

    Boot and shared plumbing for the MeetingStone (集合石) skin.

    Everything except the RegisterSkin call itself resolves lazily inside the
    skin callback, which EllesmereUI fires at PLAYER_LOGIN. That means load
    order against MeetingStone never matters and a missing/disabled MeetingStone
    costs one table lookup.

    House rules, taken from EllesmereUI's own window engine
    (EllesmereUIBlizzardSkin_WindowEngine.lua):
      * art removal is alpha-only -- we never Hide()/SetParent()/EnableMouse
        someone else's frame, and we never touch behaviour
      * per-object skin state lives in a weak-keyed EXTERNAL table, never as a
        field written onto a MeetingStone frame, so a MeetingStone update can
        never collide with us
      * every skin function is idempotent, so refresh hooks re-call them freely
------------------------------------------------------------------------------]]

local ADDON, ns = ...

-- The one thing that must happen at file scope. If EllesmereUI is absent or its
-- Blizz UI Enhanced child is disabled, the stub is either missing (this returns)
-- or an inert queue (the callback simply never fires).
if not (EllesmereUI and EllesmereUI.RegisterSkin) then return end

ns.addonName = ADDON

EllesmereUI.RegisterSkin(ADDON, function(S)
    if ns.Boot then ns.Boot(S) end
end)

-------------------------------------------------------------------------------
--  Error isolation. EllesmereUI already pcalls our top-level callback, but a
--  single bad field name inside a per-row refresh hook would otherwise spam the
--  error handler once per frame. Report each distinct error once, then stay
--  quiet -- and never let it stop the rest of the skin.
-------------------------------------------------------------------------------
local reported = {}
function ns.Safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if ok then return err end
    if err and not reported[err] then
        reported[err] = true
        geterrorhandler()(err)
    end
end

-------------------------------------------------------------------------------
--  Per-object skin state (external, weak-keyed).
-------------------------------------------------------------------------------
local state = setmetatable({}, { __mode = "k" })
function ns.D(obj)
    local d = state[obj]
    if not d then d = {}; state[obj] = d end
    return d
end

-- Frames we must not touch: Blizzard widgets MeetingStone borrows and reparents
-- into its own panels (EllesmereUI's Group Finder pack already skins those), and
-- art collages we deliberately leave alone.
ns.skip = setmetatable({}, { __mode = "k" })
function ns.Skip(...)
    for i = 1, select("#", ...) do
        local f = select(i, ...)
        if f then ns.skip[f] = true end
    end
end

-------------------------------------------------------------------------------
--  Drawing helpers.
-------------------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8X8"
ns.WHITE = WHITE

function ns.Tex(parent, layer, r, g, b, a, sublevel)
    local t = parent:CreateTexture(nil, layer, nil, sublevel)
    t:SetColorTexture(r, g, b, a)
    return t
end

-- Alpha a texture out without caring whether it exists.
function ns.Hide(...)
    for i = 1, select("#", ...) do
        local t = select(i, ...)
        if t and t.SetAlpha then t:SetAlpha(0) end
    end
end

-- Alpha out a button's four state textures. Buttons hand these out through
-- getters rather than as named regions, so GetRegions() sweeps can miss them.
local STATE_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }
function ns.HideStates(btn, keep)
    for i = 1, #STATE_GETTERS do
        local getter = btn[STATE_GETTERS[i]]
        local t = getter and getter(btn)
        if t and not (keep and keep[t]) then t:SetAlpha(0) end
    end
end

-------------------------------------------------------------------------------
--  Accent-coloured elements. EllesmereUI's primitives track the user's live
--  accent colour on their own; anything WE draw has to be re-coloured by hand
--  when the accent changes, which is what S.OnLooksChanged is for.
-------------------------------------------------------------------------------
local accents = setmetatable({}, { __mode = "k" })   -- texture -> alpha
function ns.Accent(tex, alpha)
    if not tex then return end
    accents[tex] = alpha or 1
    local r, g, b = ns.S.GetAccentColor()
    tex:SetColorTexture(r, g, b, alpha or 1)
end

function ns.RefreshAccents()
    local r, g, b = ns.S.GetAccentColor()
    for tex, alpha in pairs(accents) do
        tex:SetColorTexture(r, g, b, alpha)
    end
end

local FONT_MIN = 8

local issecretvalue = issecretvalue or function() return false end

-- Re-font a FontString in the user's UI font, shifted by the fontDelta setting.
--
-- Two hard rules live here, both learned the hard way:
--
-- 1. NEVER SetFont a widget's own label (frame:GetFontString()). Buttons and
--    EditBoxes re-apply their normal/highlight/disabled FONT OBJECT on every
--    state change, so the first mouseover throws our face and size away and
--    restores Blizzard's. The string then re-measures at a different width, and
--    anything clipped loses its tail -- "Bug反馈" renders as "Bug反", a dungeon
--    name loses its last character, and the leftover advance shows as a leading
--    gap. EllesmereUI's own engine has the same policy ("label font stays
--    Blizzard's, colour only"). Labels that DO need re-sizing get a font object
--    of ours instead (tabs, list cells).
--    Colour is still safe, and it is what the callers want.
--
-- 2. The ORIGINAL size is remembered, and the delta is always applied from that
--    base rather than from the current size. Otherwise re-running would compound
--    (-2 then -4 then -6), and the fontDelta setting could never be raised again.
--
-- Safe on zhCN: EllesmereUI's ResolveFontName maps glyph-restricted locales to
-- the system glyph font (EllesmereUI.lua:3907-3936), so Chinese never boxes out.
function ns.Font(fs, r, g, b)
    if not (fs and fs.GetFont) then return end

    local d = ns.D(fs)
    if d.claimed then return end

    if ns.IsWidgetLabel(fs) then
        if r then fs:SetTextColor(r, g, b or r) end
        return
    end

    if d.baseSize then
        if r then fs:SetTextColor(r, g, b or r) end
        return ns.ResizeFont(fs)
    end

    ns.S.Font(fs, r, g, b)

    -- S.Font re-faces at the string's existing size; that is our base.
    local path, size, flag = fs:GetFont()
    if not (path and size) or issecretvalue(size) then return end
    d.baseSize, d.fontPath, d.fontFlag = size, path, flag or ""
    ns.Track(ns.fonted, fs)
    ns.ResizeFont(fs)
end

-- Re-apply the current fontDelta to a string we have already claimed.
function ns.ResizeFont(fs)
    local d = ns.D(fs)
    if not d.baseSize then return end
    local target = d.baseSize + (ns.Get("fontDelta") or 0)
    if target < FONT_MIN then target = FONT_MIN end
    local path, size = fs:GetFont()
    if size == target and path == d.fontPath then return end
    fs:SetFont(d.fontPath or path, target, d.fontFlag or "")
end

-- Live re-apply of the fontDelta setting across every string we claimed.
function ns.ApplyFonts()
    for fs in pairs(ns.fonted) do ns.Safe(ns.ResizeFont, fs) end
end

-- Is this FontString the label its parent widget drives through font objects?
function ns.IsWidgetLabel(fs)
    local parent = fs.GetParent and fs:GetParent()
    if not (parent and parent.GetFontString) then return false end
    local ok, label = pcall(parent.GetFontString, parent)
    return ok and label == fs
end

-- Claim a FontString so ns.Font/FontAll leave it alone entirely. For the labels
-- whose size comes from a font object of ours instead (tabs, list cells).
function ns.ClaimFont(fs)
    if fs then ns.D(fs).claimed = true end
end

-- Re-font every FontString a frame owns. Called for each frame the walk visits,
-- so the whole window ends up on one face instead of a mix.
function ns.FontAll(frame)
    if not frame.GetRegions then return end
    for i = 1, select("#", frame:GetRegions()) do
        local r = select(i, frame:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("FontString") then
            ns.Safe(ns.Font, r)
        end
    end
end

-- Mark an object as handled, so a later dispatcher pass leaves it alone. Needed
-- wherever a panel pass applies an EllesmereUI primitive directly: the walk
-- visits the same frame afterwards, and re-skinning is not always harmless --
-- S.Inset fades every region with no keep set, which would erase the very
-- backdrop S.Panel had just laid down.
function ns.Mark(obj)
    if obj then ns.D(obj).done = true end
end

-------------------------------------------------------------------------------
--  Class registries. MeetingStone keeps TWO of them and they are not
--  interchangeable: NetEaseGUI's own widget classes, and the LibClass registry
--  hanging off the AceAddon object for MeetingStone's bespoke widgets.
-------------------------------------------------------------------------------
function ns.GetClass(name)                      -- NetEaseGUI widgets
    if not ns.GUI then return end
    local ok, c = pcall(ns.GUI.GetClass, ns.GUI, name)
    return ok and c or nil
end

function ns.MSClass(name)                       -- MeetingStone widgets
    if not (ns.MS and ns.MS.GetClass) then return end
    local ok, c = pcall(ns.MS.GetClass, ns.MS, name)
    return ok and c or nil
end

function ns.Module(name)
    if not (ns.MS and ns.MS.GetModule) then return end
    local ok, m = pcall(ns.MS.GetModule, ns.MS, name, true)
    return ok and m or nil
end

-- MeetingStone's namespace table (Libs/Env/Env.lua). Needed for the objects that
-- are not AceAddon modules at all, e.g. PlayerInfoDialog.
--
-- The table's __index falls through to _G, so a miss returns the same-named
-- GLOBAL rather than nil. Every lookup therefore has to be validated.
function ns.EnvGet(name)
    local env = ns.MSEnv
    if not env then return end
    local ok, v = pcall(function() return env[name] end)
    if not ok then return end
    if ns.Class and ns.Class:IsWidget(v) then return v end
end

-------------------------------------------------------------------------------
--  Class-method hooks. The only way to reach widgets MeetingStone pools or
--  creates lazily. Modelled on MeetingStone/Skin/ElvUI_Wind.lua:21
--  (SkinViaRawHook).
--
--  everyCall = true re-runs fn on every call. Needed where the original method
--  re-applies layout or fonts that we have to override again afterwards --
--  BottomTabButton:SetStatus does exactly that.
-------------------------------------------------------------------------------
function ns.HookClass(className, method, fn, everyCall)
    local cls = ns.GetClass(className) or ns.MSClass(className)
    if not cls then return end
    -- Read through the metatable chain on purpose: hooking the level that
    -- actually owns the method means every subclass inherits the hook.
    local orig = cls[method]
    if type(orig) ~= "function" then return end
    cls[method] = function(self, ...)
        orig(self, ...)
        if everyCall then
            ns.Safe(fn, self, ...)
        else
            local d = ns.D(self)
            local key = "hook:" .. method
            if not d[key] then
                d[key] = true
                ns.Safe(fn, self, ...)
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Constructor hooks: catch every NetEaseGUI widget built AFTER login (drop
--  menus, autocomplete frames, pooled list rows, dialogs).
--
--  LibClass runs the whole chain -- Constructor(super) then Constructor(class),
--  each fetched with rawget -- so we install at the class level and defer the
--  actual skinning by one frame. Deferring matters: at the moment InputBox's
--  constructor returns, a SearchBox has not created its SearchIcon yet, and the
--  dispatcher must see the finished, most-derived object.
-------------------------------------------------------------------------------
local pending = {}
function ns.Queue(obj)
    if pending[obj] then return end
    pending[obj] = true
    C_Timer.After(0, function()
        pending[obj] = nil
        ns.Safe(ns.SkinObject, obj)
    end)
end

function ns.HookConstructor(className)
    local cls = ns.GetClass(className) or ns.MSClass(className)
    if not cls then return end
    local d = ns.D(cls)
    if d.ctorHooked then return end
    d.ctorHooked = true
    -- rawget, not cls.Constructor: LibClass fetches each level's own ctor with
    -- rawget, so an inherited one must not be copied down (it would run twice).
    local orig = rawget(cls, "Constructor")
    rawset(cls, "Constructor", function(self, ...)
        if orig then orig(self, ...) end
        ns.Queue(self)
    end)
end

-------------------------------------------------------------------------------
--  Descendant walk. Covers everything that existed before our callback ran,
--  plus the plain CreateFrame widgets no class hook can ever see.
-------------------------------------------------------------------------------
local MAX_DEPTH = 10

function ns.Walk(frame, depth)
    depth = depth or 0
    if not frame or depth > MAX_DEPTH then return end
    if type(frame) ~= "table" then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    if ns.skip[frame] then return end

    ns.Safe(ns.SkinObject, frame)
    ns.Safe(ns.FontAll, frame)

    if not frame.GetChildren then return end
    for i = 1, select("#", frame:GetChildren()) do
        ns.Walk(select(i, frame:GetChildren()), depth + 1)
    end
end

-- Re-walk a root, debounced to one pass per frame. Hung off panel OnShow so
-- lazily built plain frames get picked up without any polling.
local queuedWalk = {}
function ns.QueueWalk(frame)
    if not frame or queuedWalk[frame] then return end
    queuedWalk[frame] = true
    C_Timer.After(0, function()
        queuedWalk[frame] = nil
        ns.Safe(ns.Walk, frame)
    end)
end
