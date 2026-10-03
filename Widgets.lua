--[[----------------------------------------------------------------------------
    MeetingStoneEllesmereUI -- Widgets.lua

    One skin function per NetEaseGUI widget class, plus the dispatcher that maps
    an object to the right one.

    Classification goes through LibClass (obj:IsType(class)) rather than field
    sniffing, which is what MeetingStone's own ElvUI/NDui skins do. IsType walks
    the superclass chain, so the dispatch table has to be ordered MOST DERIVED
    FIRST -- a SearchBox is also an InputBox, a DropMenu is also a GridView.
------------------------------------------------------------------------------]]

local ADDON, ns = ...

-- Every visual number now comes from Config.lua so the options panel can move it
-- live. Read through these shorthands rather than caching: a cached value is a
-- setting that silently needs a reload.
local function G(key) return ns.Get(key) end

-- Height of the darker title band. Declared here because ns.Shell and
-- ns.PaintSurface both use it, and both are defined above where it used to sit --
-- which made it a nil global read: SetHeight(nil), and `-nil` aborting
-- PaintSurface right after ClearAllPoints, leaving the backdrop unanchored and
-- therefore invisible.
local TOP_BAR_H = 25

-------------------------------------------------------------------------------
--  Thin wrappers over the EllesmereUI primitives, so every call site is
--  guarded the same way and reads the same.
-------------------------------------------------------------------------------
local function Button(btn, keepKeys)
    if not btn then return end
    ns.S.Button(btn, keepKeys)
    -- Font objects for the size, S.StateButtonLabel for the enabled/disabled
    -- colour. They compose: the widget applies our object on a state change, then
    -- EllesmereUI's hook recolours it, and both land on the same result.
    ns.SetLabelFonts(btn, "labelCenter", "labelCenter", "labelCenterOff")
    ns.S.StateButtonLabel(btn)
end
ns.SkinButton = Button

local function EditBox(eb)
    if not eb then return end
    ns.S.EditBox(eb)
end
ns.SkinEditBox = EditBox

local function Close(btn)
    if not btn then return end
    ns.S.CloseButton(btn)
end
ns.SkinClose = Close

-- Keep the original CheckButton and its label/callbacks; only replace its art.
local function Check(cb)
    if not cb then return end
    ns.SkinSwitch(cb)
    ns.SetLabelFonts(cb, "labelLeft", "labelLeft", "labelLeftOff")
    if cb.SetText and cb.Text and cb.Text.GetText then cb:SetText(cb.Text:GetText()) end
end
ns.SkinCheck = Check

-- S.Panel / S.Inset / S.Shell applied from a panel pass, marked so the descendant
-- walk does not run its generic rules over the same frame afterwards.
function ns.Panel(frame, opts)
    if not frame then return end
    ns.S.Panel(frame, opts)
    ns.Mark(frame)
end

function ns.Inset(frame)
    if not frame then return end
    ns.S.Inset(frame)
    ns.Mark(frame)
end

-- Every window-sized surface goes through here: the main window and the three
-- filter popups, so they cannot drift apart.
--
-- We draw the backdrop rather than calling S.Shell. S.Shell's colour and opacity
-- live in EllesmereUIDB (WSkin.GetModernBG, or the modern_blizz atlas), which is
-- EllesmereUI's data to own -- writing another addon's saved variables is not ours
-- to do, so an opacity slider was impossible for as long as its opaque backdrop
-- sat underneath ours. What stays EllesmereUI's is the part that should: S.Panel
-- with noBg strips the stock art and draws the house pixel-perfect border.
--
-- The backdrop lives on a CHILD frame, never as a region of the skinned frame.
-- S.Panel registers the frame with the window engine, and WSkin.Restrip()
-- re-fades every region of every registered frame -- it fires from a dozen
-- unrelated Blizzard window hooks (Collections, PlayerSpells, Guild, Calendar),
-- and would wipe a backdrop we had put there. A child frame is not registered, so
-- nothing sweeps it, and one frame level down seats it below both the border
-- container and every child the window already owns.
function ns.Shell(frame, opts)
    if not frame then return end
    opts = opts or {}

    ns.S.Panel(frame, { noBg = true, noBorder = opts.noBorder })

    local d = ns.D(frame)
    if not d.bgHost then
        local host = CreateFrame("Frame", nil, frame)
        host:SetAllPoints(frame)
        local lvl = frame:GetFrameLevel() or 1
        host:SetFrameLevel(lvl > 0 and lvl - 1 or 0)
        d.bgHost = host

        -- Body and title strip are laid out as two NON-OVERLAPPING bands, not as a
        -- strip stacked on the backdrop. Stacking composites two translucent
        -- layers, so the strip was always darker than the body by construction --
        -- and the more opaque the window got, the closer it drifted to solid
        -- black. Side by side, each band shows exactly its own colour at exactly
        -- bgAlpha, and nothing accumulates however often a setting is changed.
        d.bg = host:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.bg:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)

        d.topBar = host:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.topBar:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
        d.topBar:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
        d.topBar:SetHeight(TOP_BAR_H)

        ns.Track(ns.surfaces, frame)
    end
    ns.PaintSurface(frame)
    ns.Mark(frame)
end

function ns.PaintSurface(frame)
    local d = ns.D(frame)
    if not d.bg then return end

    local r, g, b = ns.GetColor("bgColor")
    local a = G("bgAlpha")
    local on = G("topBar") and true or false

    d.bg:SetColorTexture(r, g, b, a)
    -- Re-seat the body's top edge so the two bands stay flush and never overlap.
    d.bg:ClearAllPoints()
    d.bg:SetPoint("TOPLEFT", d.bgHost, "TOPLEFT", 0, on and -TOP_BAR_H or 0)
    d.bg:SetPoint("BOTTOMRIGHT", d.bgHost, "BOTTOMRIGHT", 0, 0)

    if d.topBar then
        d.topBar:SetShown(on)
        if on then d.topBar:SetColorTexture(ns.ShadeOf("topBarShade")) end
    end
end

function ns.ApplySurfaces()
    for frame in pairs(ns.surfaces) do ns.Safe(ns.PaintSurface, frame) end
end

-- A contrasting shade of the window colour, at the window's OWN opacity.
--
-- Every secondary strip (title band, list column headers) resolves through this, so
-- the single 背景不透明度 slider governs all of them.
--
-- It LIGHTENS, and that is the whole point. Darkening was the obvious idea and it
-- does not work: the default window colour is 0.06, so multiplying it by 0.6 gives
-- 0.036 -- a 0.024 difference that is invisible, because you cannot make
-- near-black meaningfully darker. Blending toward white gives real separation at
-- any base colour (0.06 -> 0.15 at t=0.10).
function ns.ShadeOf(shadeKey)
    local r, g, b = ns.GetColor("bgColor")
    local t = G(shadeKey) or 0
    return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t, G("bgAlpha")
end

-- Repaint a widget's own highlight slot as a flat white wash.
--
-- Reusing the slot rather than adding a HIGHLIGHT-layer texture matters on list
-- rows: a DataGridView's per-column child buttons steal the mouse, and
-- DataGridViewGridItem:OnEnter relays hover by calling parent:LockHighlight(),
-- which only drives the highlight slot.
--
-- Anchored to the frame with an explicit inset rather than SetAllPoints on
-- another texture -- texture-to-texture anchoring is not reliable and an error
-- here would abort the rest of the caller's setup.
local function Hover(frame, alpha, topInset)
    if not frame.SetHighlightTexture then return end
    local hl = frame.GetHighlightTexture and frame:GetHighlightTexture()
    if not hl then
        hl = frame:CreateTexture(nil, "HIGHLIGHT")
        frame:SetHighlightTexture(hl)
    end
    -- SetColorTexture, not SetTexture + SetVertexColor: the alpha lands in one
    -- call and cannot be reset by a later SetTexture. This is the form
    -- WSkin.SolidTex uses for every wash EllesmereUI draws.
    hl:SetColorTexture(1, 1, 1, alpha or 0.10)
    hl:SetBlendMode("BLEND")
    -- Texture-level alpha multiplies the colour alpha above, and a stock
    -- highlight may arrive pre-dimmed; pin it so only the colour decides.
    hl:SetAlpha(1)
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(topInset or 0))
    hl:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    return hl
end
ns.Hover = Hover

-------------------------------------------------------------------------------
--  Dropdown. S.Dropdown draws the house arrow on the right; NetEaseGUI's own
--  MenuButton child keeps its ChatIcon-ScrollDown art, which would sit on top
--  of it, so that gets alphaed out separately (the button stays clickable --
--  alpha is not hit-testing).
-------------------------------------------------------------------------------
-- The dropdown wrapper lives in Controls.lua (also used by the homepage).

-------------------------------------------------------------------------------
--  Single-line inputs: InputBox and its subclasses NumericBox / SearchBox.
--  S.EditBox fades EVERY region unconditionally, which includes SearchBox's
--  magnifier, so that gets restored afterwards. (S.EditBox does not register the
--  frame for re-stripping, so nothing fades it again later.)
-------------------------------------------------------------------------------
function ns.SkinInputBox(ib)
    local d = ns.D(ib)
    if d.done then return end
    d.done = true

    EditBox(ib)

    if ib.SearchIcon then ib.SearchIcon:SetAlpha(1) end
    ns.Font(ib.Prompt)
    ns.Font(ib.Label)

    -- NumericBox spinner arrows: keep them (they are the control), just take the
    -- Blizzard gold off so they read as neutral chrome.
    for _, key in ipairs({ "PlusButton", "MinusButton" }) do
        local b = ib[key]
        if b and b.Texture then b.Texture:SetVertexColor(0.9, 0.9, 0.9) end
    end
end

-- The multi-line GUI EditBox widget (a Frame wrapping a ScrollFrame): nine
-- Common-Input-Border slices as direct regions, so S.EditBox clears them all.
function ns.SkinMultiEditBox(box)
    local d = ns.D(box)
    if d.done then return end
    d.done = true

    EditBox(box)
    ns.Font(box.Prompt)

    local sf = box.ScrollFrame
    if sf and sf.ScrollBar then ns.SkinScrollBar(sf.ScrollBar) end
end

-------------------------------------------------------------------------------
--  Scroll bars. S.ScrollBar cannot be used here: it expects the modern
--  MinimalScrollBar shape (sb.Back / sb.Forward / sb.Track.Thumb), while
--  NetEaseGUI's ScrollBar is Slider.UIPanelScrollBarTemplate. Hand-rolled to
--  the same result -- no arrows, a slim white thumb strip.
-------------------------------------------------------------------------------
function ns.SkinScrollBar(sb)
    if not sb or not sb.GetObjectType then return end
    local d = ns.D(sb)
    if d.done then return end
    d.done = true

    for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
        local b = sb[key]
        if b then
            ns.HideStates(b)
            ns.S.FadeRegions(b)
        end
    end

    -- Fade the track art FIRST: the thumb is a region of the slider too, so it
    -- gets caught by this sweep and has to be repainted afterwards.
    ns.S.FadeRegions(sb)

    local thumb = sb.GetThumbTexture and sb:GetThumbTexture()
    if thumb then
        thumb:SetColorTexture(1, 1, 1, 0.3)
        thumb:SetAlpha(1)
        -- Slim, but still grabbable: the thumb texture IS the drag target on a
        -- Slider, so this cannot go all the way down to EUI's 4px.
        thumb:SetWidth(6)
    end
end

-- PageScrollBar is not a scroll bar at all -- it is a prev/next pager built from
-- the spellbook page arrows, so it maps straight onto S.PageButton.
function ns.SkinPageScrollBar(sb)
    local d = ns.D(sb)
    if d.done then return end
    d.done = true

    if sb.ScrollUpButton then ns.S.PageButton(sb.ScrollUpButton, "<") end
    if sb.ScrollDownButton then ns.S.PageButton(sb.ScrollDownButton, ">") end
end

-------------------------------------------------------------------------------
--  DataGridView column headers. Values match WSkin.SortHeaderBar so these read
--  identically to the sort headers on Blizzard's own ScrollBox lists.
-------------------------------------------------------------------------------
function ns.SkinSortButton(btn)
    local d = ns.D(btn)
    if d.done then return end
    d.done = true

    -- The sort arrow is a direct region, so it has to be kept out of the sweep.
    local keep = {}
    if btn.Arrow then keep[btn.Arrow] = true end
    ns.S.FadeRegions(btn, keep)
    ns.HideStates(btn, keep)

    d.bg = ns.Tex(btn, "BACKGROUND", 0, 0, 0, 0)
    d.bg:SetAllPoints(btn)
    ns.Track(ns.headers, btn)
    ns.PaintHeader(btn)

    Hover(btn, 0.10)

    -- Header labels are button labels, so they take a font object like every other
    -- one. Justified left because the sort arrow sits after the text.
    ns.SetLabelFonts(btn, "listLeft")
    if btn.Arrow then btn.Arrow:SetVertexColor(1, 1, 1) end
end

-- Same treatment as the title band, so the one 背景不透明度 slider moves the
-- header strips too.
function ns.PaintHeader(btn)
    local d = ns.D(btn)
    if not d.bg then return end
    d.bg:SetColorTexture(ns.ShadeOf("headerShade"))
end

function ns.ApplyHeaders()
    for btn in pairs(ns.headers) do ns.Safe(ns.PaintHeader, btn) end
end

-------------------------------------------------------------------------------
--  Tabs. S.Tab is unusable here: it resolves selection from
--  parent.selectedTabID / tab.isSelected / PanelTemplates_GetSelectedTab, and
--  NetEaseGUI's tab buttons have none of those -- the accent underline would
--  never light. SetStatus('SELECTED'|'NORMAL'|'DISABLED') is the authoritative
--  signal instead, so the visual is driven from there.
--
--  Re-applied on EVERY SetStatus call, because SetStatus re-shows the art
--  slices, re-anchors the label, swaps the disabled font object (which resets
--  our font) and re-widths the button.
-------------------------------------------------------------------------------
local TAB_SLICES = { "tLeft", "tRight", "tMid", "tActiveLeft", "tActiveRight", "tActiveMid" }
local TAB_TOP_INSET = 2   -- active art is 3px taller; seat every tab the same

-- Every widget LABEL goes through this registry.
--
-- Labels are driven by FONT OBJECTS, not by the FontString: the widget re-applies
-- its normal/highlight/disabled object on every state change. SetFont on the
-- string is therefore undone by the first mouseover, and it takes the string's
-- measured width with it -- which is what clipped "Bug反馈" to "Bug反" and ate the
-- last character of dungeon names in 1.0, and what made an alpha'd-out tab label
-- come back gold on top of our own.
--
-- So anything whose size a setting controls gets an object of OURS instead:
-- tabs, list cells, dropdowns, checkboxes, buttons. The objects are shared and
-- mutated in place, so one rebuild after a settings change (or a live
-- EllesmereUI font change) repaints every widget referencing them.
--
-- Colours are baked into the object because that is the only way they survive the
-- widget's own state switching.
local FONT_SPECS = {
    tabNormal      = { "tabFontSize",   nil,      1,   1,   1,   0.75 },
    tabActive      = { "tabFontSize",   nil,      1,   1,   1,   1    },
    tabDisabled    = { "tabFontSize",   nil,      1,   1,   1,   0.4  },

    listLeft       = { "listFontSize",  "LEFT",   1,   1,   1,   1    },
    listRight      = { "listFontSize",  "RIGHT",  1,   1,   1,   1    },
    listCenter     = { "listFontSize",  "CENTER", 1,   1,   1,   1    },

    labelCenter    = { "labelFontSize", "CENTER", 1,   1,   1,   1    },
    labelCenterOff = { "labelFontSize", "CENTER", 0.5, 0.5, 0.5, 1    },
    labelLeft      = { "labelFontSize", "LEFT",   1,   1,   1,   1    },
    labelLeftOff   = { "labelFontSize", "LEFT",   0.5, 0.5, 0.5, 1    },
}

local Fonts = {}
ns.Fonts = Fonts

local function PaintFont(name)
    local spec = FONT_SPECS[name]
    local f = Fonts[name]
    if not (spec and f) then return end
    local path, flag = ns.S.GetFont()
    f:SetFont(path or STANDARD_TEXT_FONT, G(spec[1]), flag or "")
    if spec[2] then f:SetJustifyH(spec[2]) end
    f:SetTextColor(spec[3], spec[4], spec[5], spec[6])
end

local function BuildFonts()
    for name in pairs(FONT_SPECS) do
        if not Fonts[name] then
            Fonts[name] = CreateFont("MeetingStoneEllesmereUIFont_" .. name)
        end
        PaintFont(name)
    end
end
ns.ApplyLabelFonts = BuildFonts
ns.ApplyTabFont    = BuildFonts

-- Font objects cover the cell LABELS; the extra FontStrings some cells own
-- (SummaryGrid's 说明 text) are plain strings and need repainting by hand.
function ns.ApplyListFont()
    BuildFonts()
    ns.Safe(ns.ApplyMemberIcons)   -- icons scale off the list size
    for obj in pairs(ns.grids) do
        if obj.SetFont and obj.IsObjectType and obj:IsObjectType("FontString") then
            ns.Safe(ns.PaintListFontString, obj)
        end
    end
end

-- Hand a widget our objects for all three states, and claim its label so the
-- blanket FontAll sweep leaves it alone.
function ns.SetLabelFonts(widget, normal, highlight, disabled)
    if not (widget and widget.SetNormalFontObject) then return end
    if not Fonts[normal] then BuildFonts() end
    widget:SetNormalFontObject(Fonts[normal])
    if highlight and widget.SetHighlightFontObject then
        widget:SetHighlightFontObject(Fonts[highlight])
    end
    if disabled and widget.SetDisabledFontObject then
        widget:SetDisabledFontObject(Fonts[disabled])
    end
    ns.ClaimFont(widget.GetFontString and widget:GetFontString())
end

-- Tab plate colour/opacity is ours (the row sits outside the window), so it gets
-- its own setting rather than following bgColor.
function ns.ApplyTabs()
    local r, g, b = ns.GetColor("tabColor")
    local a = G("tabAlpha")
    for tab in pairs(ns.tabs) do
        local d = ns.D(tab)
        if d.bg then d.bg:SetColorTexture(r, g, b, a) end
    end
end

function ns.SkinTab(tab, status)
    local d = ns.D(tab)

    if not Fonts.tabNormal then BuildFonts() end

    if not d.done then
        d.done = true

        local tr, tg, tb = ns.GetColor("tabColor")
        d.bg = ns.Tex(tab, "BACKGROUND", tr, tg, tb, G("tabAlpha"))
        d.bg:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -TAB_TOP_INSET)
        d.bg:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)

        Hover(tab, 0.06, TAB_TOP_INSET)

        d.underline = ns.Tex(tab, "OVERLAY", 1, 1, 1, 1)
        d.underline:SetHeight(1)
        d.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
        d.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
        ns.Accent(d.underline, 1)
        d.underline:Hide()

        ns.Track(ns.tabs, tab)
        ns.SetLabelFonts(tab, "tabNormal", "tabActive")

        -- Keep the walk's blanket re-font off it: the font object owns the size.
        ns.ClaimFont(tab:GetFontString())
    end

    -- The dispatcher can reach a tab with no status (the login walk). Remember
    -- the last real one so a re-skin never drops the underline off the tab that
    -- is actually selected.
    if status then d.status = status end
    status = status or d.status or "NORMAL"

    -- SetStatus Show()s the slices again. Show() does not reset alpha, but
    -- re-asserting is a handful of lookups and immune to a MeetingStone change
    -- that starts setting alpha itself.
    for i = 1, #TAB_SLICES do
        local t = tab[TAB_SLICES[i]]
        if t then t:SetAlpha(0) end
    end

    local selected = (status == "SELECTED")
    if d.underline then d.underline:SetShown(selected) end

    -- SetStatus disables the button for both SELECTED and DISABLED and picks a
    -- Blizzard disabled font per case; override with ours for the same split.
    tab:SetDisabledFontObject(selected and Fonts.tabActive or Fonts.tabDisabled)

    -- SetStatus sized the tab from the PREVIOUS font's metrics (it runs before
    -- this hook). Re-run its own formula now that our font is in place.
    if tab.GetTextWidth and tab.SetWidth then
        tab:SetWidth(tab:GetTextWidth() + 30)
    end
end

-- LeftTabPanel's big portrait tabs (bluemenu art).
function ns.SkinLeftTabItem(item)
    local d = ns.D(item)
    if d.done then return end
    d.done = true

    local keep = {}
    if item.Icon then keep[item.Icon] = true end
    ns.S.FadeRegions(item, keep)

    local pr, pg, pb, pa = ns.S.GetPanelColor()
    d.bg = ns.Tex(item, "BACKGROUND", pr, pg, pb, pa)
    d.bg:SetAllPoints(item)

    ns.SkinRowStates(item)
    if item.Icon then ns.S.SquareIcon(item.Icon, item) end

    local fs = item:GetFontString()
    if fs then
        ns.Font(fs)
        ns.S.White(fs)
    end
end

-------------------------------------------------------------------------------
--  Popup menus. DropMenu and AutoCompleteFrame both paint their own chrome --
--  DropMenu through SetBackdrop, AutoCompleteFrame through nine UI-Frame slices
--  plus a marble fill -- so both get cleared before S.Panel takes over.
-------------------------------------------------------------------------------
function ns.SkinMenu(menu)
    local d = ns.D(menu)
    if d.done then return end
    d.done = true

    if menu.SetBackdrop then menu:SetBackdrop(nil) end
    ns.S.Panel(menu, { inset = true })
end

function ns.SkinDropMenuItem(item)
    local d = ns.D(item)
    if d.done then return end
    d.done = true

    -- DropMenuItem is a CheckButton even for navigation-only parent entries.
    -- Its native checkbox texture already represents checkable options. A
    -- full-row checked texture would turn any parent click into fake selection.
    Hover(item, G("hoverAlpha"))
    if item.SetCheckState then
        hooksecurefunc(item, "SetCheckState", function(self)
            if not self.checkable then self:SetChecked(false) end
        end)
        if not item.checkable then item:SetChecked(false) end
    end

    if item.Arrow then
        item.Arrow:SetTexture("Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-arrow-right.png")
        item.Arrow:SetSize(10, 10)
        item.Arrow:SetVertexColor(1, 1, 1, 0.9)
    end
    if item.Separator then
        item.Separator:SetColorTexture(0.25, 0.25, 0.25, 1)
        item.Separator:SetHeight(1)
    end
    ns.Font(item.Text)
end

-------------------------------------------------------------------------------
--  List rows.
--
--  Selection is the checked slot plus an accent bar down the left edge. The bar
--  needs a state hook because there is no "checked" draw layer. SetChecked is
--  read back rather than trusted from the argument: ItemButton:OnClick calls it
--  with a computed value and nil/false normalise differently.
-------------------------------------------------------------------------------
function ns.SkinRowStates(row)
    local d = ns.D(row)
    if d.states then return end
    d.states = true
    ns.Track(ns.rows, row)

    Hover(row, G("hoverAlpha"))

    if not row.SetCheckedTexture then return end

    local ck = row.GetCheckedTexture and row:GetCheckedTexture()
    if not ck then
        ck = row:CreateTexture(nil, "ARTWORK")
        row:SetCheckedTexture(ck)
    end
    ck:SetBlendMode("BLEND")
    ck:ClearAllPoints()
    ck:SetAllPoints(row)
    ck:SetAlpha(1)
    d.selFill = ck
    ns.Accent(ck, G("selectAlpha"))

    d.selBar = ns.Tex(row, "OVERLAY", 1, 1, 1, 1)
    d.selBar:SetWidth(G("barWidth"))
    d.selBar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    d.selBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    ns.Accent(d.selBar, 1)
    d.selBar:Hide()

    local function reflect()
        if not d.selBar then return end
        d.selBar:SetShown(G("selectBar") and row:GetChecked() and true or false)
    end
    hooksecurefunc(row, "SetChecked", reflect)
    reflect()
end

-- Chrome plates on a row always live in BACKGROUND/BORDER; icons and labels live
-- in ARTWORK/OVERLAY. Fading by draw layer therefore strips the plate art
-- without touching a single piece of row content, which a blanket FadeRegions
-- would (FollowItem's status icon, MallItem's item art).
--
-- bg/Bg are MeetingStone's own flat colour washes -- applicant grouping, recent-
-- player class colour. Those carry information, so they stay.
local ROW_KEEP_KEYS = { "bg", "Bg", "Icon", "IconBorder" }

function ns.SkinRow(row)
    if not G("skinRows") then return end
    local d = ns.D(row)
    if d.done then return end
    d.done = true

    local keep = {}
    for i = 1, #ROW_KEEP_KEYS do
        local r = row[ROW_KEEP_KEYS[i]]
        if r and r.GetDrawLayer then keep[r] = true end
    end

    for i = 1, select("#", row:GetRegions()) do
        local r = select(i, row:GetRegions())
        if r and not keep[r] and r.IsObjectType and r:IsObjectType("Texture") then
            local layer = r.GetDrawLayer and r:GetDrawLayer()
            if layer == "BACKGROUND" or layer == "BORDER" then r:SetAlpha(0) end
        end
    end
    -- Row plates set through SetNormalTexture/SetNormalAtlas rather than as named
    -- regions (AutoCompleteItem's _search-rowbg) need the state getters too.
    ns.HideStates(row, keep)

    d.zebra = ns.Tex(row, "BACKGROUND", 0, 0, 0, G("zebraAlpha"), 1)
    d.zebra:SetAllPoints(row)
    d.zebra:Hide()

    ns.SkinRowStates(row)
end

-- Per-column cell inside a DataGridView row. Nothing to strip -- the point here
-- is the font SIZE, which is what "活动列表的字号" asks for.
--
-- Same reason as the tabs: the cell label is a button label driven by a font
-- object (DataGridViewGridItem's StyleHelper sets SetNormalFontObject per column
-- style), so SetFont on the string would be undone by the first mouseover. We
-- hand it a font object of ours instead, one per justification because that is
-- what the column styles differ by.
local LIST_BY_JUSTIFY = { LEFT = "listLeft", RIGHT = "listRight", CENTER = "listCenter" }

function ns.SkinGridItem(cell)
    local d = ns.D(cell)
    if d.done then return end
    d.done = true

    local label = cell.GetFontString and cell:GetFontString()
    if label then
        local just = (label.GetJustifyH and label:GetJustifyH()) or "LEFT"
        -- NORMAL only, mirroring what DataGridViewGridItem itself sets. Adding
        -- highlight/disabled objects would introduce an extra font-object switch
        -- on mouseover, and that would reset the per-row colours
        -- DataGridView:OnItemFormatted writes (class colours, score colours).
        ns.SetLabelFonts(cell, LIST_BY_JUSTIFY[just] or "listLeft")
    end

    -- Cells with their OWN extra FontStrings: the 说明 column is a SummaryGrid
    -- whose text lives on .Summary / .ExpirationTime / .PendingLabel rather than
    -- on the button label, and OperationGrid carries .StatusText. Those are not
    -- driven by a font object, so they take the size directly -- but from
    -- listFontSize, not the global fontDelta, since they ARE list text.
    for i = 1, select("#", cell:GetRegions()) do
        local r = select(i, cell:GetRegions())
        if r and r ~= label and r.IsObjectType and r:IsObjectType("FontString") then
            ns.ListFontString(r)
        end
    end

    -- 成员 column: a Blizzard LFGListGroupDataDisplayTemplate holding the role
    -- icons and their counts. Its internals are laid out by Blizzard's own
    -- updater, so scaling the container is the only safe way to make the icons
    -- track the list font size -- resizing the pieces would be undone.
    if cell.DataDisplay then
        ns.Track(ns.members, cell.DataDisplay)
        ns.PaintMemberIcons(cell.DataDisplay)
    end

    ns.Track(ns.grids, cell)
end

-- Both list actions use the same restrained red X. The icon lives on a
-- mouse-transparent child so EUI's later re-strip cannot erase it with the old
-- atlas. Keep all native click/enable scripts, tooltips and visibility intact.
local function DestructiveAction(button)
    Button(button)
    ns.Mark(button)
    local host = CreateFrame("Frame", nil, button)
    host:SetAllPoints(button)
    host:EnableMouse(false)
    ns.Mark(host)
    local icon = host:CreateTexture(nil, "OVERLAY")
    icon:SetAtlas("uitools-icon-close")
    icon:SetDesaturated(true)
    icon:SetSize(12, 12)
    icon:SetPoint("CENTER", host, "CENTER", 0, 0)
    local hovered = false
    local function reflect()
        local enabled = button:IsEnabled()
        host:SetAlpha(enabled and 1 or .4)
        if enabled and hovered then
            icon:SetVertexColor(1, .5, .5, 1)
        else
            icon:SetVertexColor(.95, .28, .28, 1)
        end
    end
    button:HookScript("OnEnter", function() hovered = button:IsEnabled(); reflect() end)
    button:HookScript("OnLeave", function() hovered = false; reflect() end)
    button:HookScript("OnHide", function() hovered = false; reflect() end)
    button:HookScript("OnEnable", reflect)
    button:HookScript("OnDisable", function() hovered = false; reflect() end)
    reflect()
    return { host=host, icon=icon }
end

-- SummaryGrid is created lazily for the browse list's final column. A generic
-- font-only cell pass misses its cancel action (or strips its only icon later).
function ns.SkinSummaryGrid(cell)
    ns.SkinGridItem(cell)
    local d, cancel = ns.D(cell), cell.CancelButton
    if d.cancelAction or not cancel then return end
    -- Compact square, vertically centered, with a 5px gap from the native
    -- countdown ending 35px from the right. Do not move labels or the spinner.
    cancel:SetSize(22, 22)
    cancel:ClearAllPoints()
    cancel:SetPoint("RIGHT", cell, "RIGHT", -8, 0)
    d.cancelAction = DestructiveAction(cancel)
end

-- OperationGrid creates plain child Buttons after its base constructor. The
-- deferred class dispatch must skin those children explicitly: a font-only cell
-- pass cannot flatten actions in rows created after the panel's initial walk.
function ns.SkinOperationGrid(cell)
    ns.SkinGridItem(cell)
    local d = ns.D(cell)
    if d.operationActions then return end
    local invite, decline = cell.InviteButton, cell.DeclineButton
    if not (invite and decline) then return end
    Button(invite)
    ns.Mark(invite)
    d.operationActions = DestructiveAction(decline)
end

-- Scale relative to 12, the stock body size, and clamped: the column header width
-- is fixed, so an unbounded scale would spill into the next column.
function ns.PaintMemberIcons(display)
    if not display.SetScale then return end
    local scale = 1
    if G("memberIconScale") then
        scale = (G("listFontSize") or 12) / 12
        if scale < 0.85 then scale = 0.85 elseif scale > 1.25 then scale = 1.25 end
    end
    display:SetScale(scale)
end

function ns.ApplyMemberIcons()
    for display in pairs(ns.members) do ns.Safe(ns.PaintMemberIcons, display) end
end

-- A plain (non-label) FontString that belongs to the list and should follow
-- listFontSize. Tracked so the setting can move it live.
function ns.ListFontString(fs)
    if not (fs and fs.SetFont) then return end
    ns.ClaimFont(fs)
    ns.Track(ns.grids, fs)
    ns.PaintListFontString(fs)
end

function ns.PaintListFontString(fs)
    local path, flag = ns.S.GetFont()
    fs:SetFont(path or STANDARD_TEXT_FONT, G("listFontSize"), flag or "")
end

-- Live re-apply for everything on a list row that a setting can move.
function ns.ApplyRows()
    local hoverA  = G("hoverAlpha")
    local selA    = G("selectAlpha")
    local barW    = G("barWidth")
    local barOn   = G("selectBar") and true or false
    local zebraOn = G("zebra") and true or false
    local zebraA  = G("zebraAlpha")

    for row in pairs(ns.rows) do
        local d = ns.D(row)
        local hl = row.GetHighlightTexture and row:GetHighlightTexture()
        if hl then hl:SetColorTexture(1, 1, 1, hoverA) end
        if d.selFill then ns.Accent(d.selFill, selA) end
        if d.selBar then
            d.selBar:SetWidth(barW)
            d.selBar:SetShown(barOn and row.GetChecked and row:GetChecked() and true or false)
        end
        if d.zebra then
            d.zebra:SetColorTexture(0, 0, 0, zebraA)
            if not zebraOn then d.zebra:Hide() end
        end
    end
end

-------------------------------------------------------------------------------
--  Containers and chrome.
-------------------------------------------------------------------------------
function ns.SkinTitleWidget(w)
    local d = ns.D(w)
    if d.done then return end
    d.done = true

    if w.Bg then
        local pr, pg, pb, pa = ns.S.GetPanelColor()
        w.Bg:SetColorTexture(pr, pg, pb, pa)
    end
    ns.Font(w.Text)
end

function ns.SkinTitlePanel(p)
    local d = ns.D(p)
    if d.done then return end
    d.done = true

    if p.SetBackdrop then p:SetBackdrop(nil) end
    ns.S.Panel(p)
    Close(p.CloseButton)
    if p.Title then ns.Font(p.Title, 1, 1, 1) end
end

function ns.SkinCover(c)
    local d = ns.D(c)
    if d.done then return end
    d.done = true

    if c.Background then c.Background:SetColorTexture(0, 0, 0, 0.6) end
    ns.Font(c.Text)
end

-------------------------------------------------------------------------------
--  Dispatch. Ordered most derived first: the first IsType hit wins.
--
--  PanelBlocker is deliberately absent. The announcement and help screens are
--  full-frame art collages (GLUES credits tiles, the MeetingStone logo) whose
--  pieces are unnamed locals, so there is no way to strip the chrome without
--  also erasing the artwork. Both are transient splash screens; they stay stock
--  and only their buttons and text get skinned, through the walk.
-------------------------------------------------------------------------------
local ORDER

local SPEC = {
    -- inputs (SearchBox and NumericBox both derive from InputBox)
    { "SearchBox",             "SkinInputBox"       },
    { "NumericBox",            "SkinInputBox"       },
    { "InputBox",              "SkinInputBox"       },
    { "InputBox2",             "SkinEditBox"        },
    { "EditBox",               "SkinMultiEditBox"   },
    { "Dropdown",              "SkinDropdown"       },
    -- scrolling (PageScrollBar is a pager, not a bar)
    { "PageScrollBar",         "SkinPageScrollBar"  },
    { "ScrollBar",             "SkinScrollBar"      },
    -- ItemButton subclasses, ahead of the generic row rule
    { "BottomTabButton",       "SkinTab"            },
    { "InTabButton",           "SkinTab"            },
    { "LeftTabItem",           "SkinLeftTabItem"    },
    { "DropMenuItem",          "SkinDropMenuItem"   },
    { "AutoCompleteItem",      "SkinRow"            },
    -- DataGridViewGridItem derives from Button, not ItemButton
    { "RoleItem",              "SkinGridItem", true },
    { "SummaryGrid",           "SkinSummaryGrid", true },
    { "OperationGrid",         "SkinOperationGrid", true },
    { "MemberDisplay",         "SkinGridItem", true },
    { "DataGridViewGridItem",  "SkinGridItem"       },
    { "ItemButton",            "SkinRow"            },
    -- views (DropMenu/AutoCompleteFrame derive from GridView)
    { "DropMenu",              "SkinMenu"           },
    { "AutoCompleteFrame",     "SkinMenu"           },
    -- chrome
    { "CheckBox",              "SkinCheck"          },
    { "SortButton",            "SkinSortButton"     },
    { "TitleWidget",           "SkinTitleWidget"    },
    { "TitlePanel",            "SkinTitlePanel"     },
    { "Cover",                 "SkinCover",    true },
}

function ns.BuildDispatch()
    ORDER = {}
    for i = 1, #SPEC do
        local name, fnName, isMSClass = SPEC[i][1], SPEC[i][2], SPEC[i][3]
        local cls = isMSClass and ns.MSClass(name) or ns.GetClass(name)
        local fn = ns[fnName]
        if cls and fn then
            ORDER[#ORDER + 1] = { cls = cls, fn = fn, name = name }
        end
    end
end

-- Memoised per class, not per object: the walk and the list refresh hook both
-- run this over hundreds of objects, and a linear IsType scan per row on every
-- list refresh would be wasteful. false = "no skin for this class".
local resolved = {}

local function Resolve(obj)
    if not (ORDER and obj.GetType and obj.IsType) then return end
    local ok, cls = pcall(obj.GetType, obj)
    if not (ok and cls) then return end

    local cached = resolved[cls]
    if cached ~= nil then return cached or nil end

    for i = 1, #ORDER do
        local e = ORDER[i]
        local hit
        ok, hit = pcall(obj.IsType, obj, e.cls)
        if ok and hit then
            resolved[cls] = e.fn
            return e.fn
        end
    end
    resolved[cls] = false
end

-- Plain CreateFrame widgets, which no class hook can ever see. Deliberately
-- conservative: only shapes we can identify without guessing.
local function Generic(f)
    local ot = f.GetObjectType and f:GetObjectType()
    if not ot then return end

    if ot == "CheckButton" then
        -- Raw CheckButtons with Blizzard's checkbox art: FilterBox.Check,
        -- CreatePanel.PrivateGroup, MeetingStoneEX's CheckBox.Check.
        if ns.IsSwitchCheckbox(f) then return Check(f) end
    elseif ot == "EditBox" then
        return EditBox(f)
    elseif ot == "Slider" then
        -- Scroll bars only. An options slider has neither button and must NOT be
        -- flattened -- it would lose its track and gain a 6px thumb.
        if f.ScrollUpButton and f.ScrollDownButton then return ns.SkinScrollBar(f) end
    elseif ot == "Button" then
        -- UIPanelButtonTemplate carries Left/Middle/Right; UIMenuButtonStretch-
        -- Template carries the separators. Bare Buttons get no backdrop -- they are
        -- icon buttons, and flattening one erases its only visual.
        if f.Left or f.LeftSeparator then return Button(f) end
        -- ...but a bare button WITH a label is a text link (MainPanel's
        -- [更新地址] / [Bug反馈]), and its size should still follow the setting.
        -- Font object only, no art touched. Embedded |cff..| codes in the text
        -- keep their own colour regardless of the object's.
        local fs = f.GetFontString and f:GetFontString()
        if fs and (fs:GetText() or "") ~= "" then
            return ns.SetLabelFonts(f, "labelCenter", "labelCenter", "labelCenterOff")
        end
    elseif ot == "Frame" then
        -- InsetFrameTemplate. Only ever a nested content well, never a frame we
        -- have already given a backdrop to -- S.Inset fades every region with no
        -- keep set, so running it over a painted panel erases the paint.
        if f.Bg and f.NineSlice then return ns.S.Inset(f) end
    end
end

function ns.SkinObject(obj)
    if type(obj) ~= "table" or ns.skip[obj] then return end
    if obj.IsForbidden and obj:IsForbidden() then return end

    -- One dispatch per object, ever. The walk revisits frames the panel passes
    -- already handled, and a second pass is not always idempotent: a panel that
    -- S.Panel just gave a backdrop still looks like an InsetFrameTemplate to the
    -- generic rules below, and S.Inset would strip that backdrop straight off
    -- again (this is what left the advanced-filter popup see-through).
    --
    -- `dispatched` is deliberately a different key from the `done` each skin
    -- function keeps: SkinTab is also called directly from the SetStatus hook and
    -- relies on `done` to tell first-time setup from a per-call refresh.
    local d = ns.D(obj)
    if d.dispatched or d.done then return end
    d.dispatched = true

    local fn = Resolve(obj)
    if fn then return fn(obj) end
    return Generic(obj)
end

-------------------------------------------------------------------------------
--  Class hooks. Installed once at boot.
-------------------------------------------------------------------------------
local CTOR_CLASSES = {
    "SearchBox", "NumericBox", "InputBox", "InputBox2", "EditBox",
    "Dropdown", "ScrollBar", "PageScrollBar", "SortButton", "CheckBox",
    "BottomTabButton", "InTabButton", "LeftTabItem",
    "DropMenu", "DropMenuItem", "AutoCompleteFrame", "AutoCompleteItem",
    "DataGridViewGridItem", "ItemButton",
    "TitleWidget", "TitlePanel",
}

-- Row buttons are pooled: View:GetButton creates them on demand, and UpdateItems
-- is the one place that knows a button's slot index -- which is also its visual
-- row position, since buttons are anchored in slot order. So that is where the
-- zebra stripe is set.
local function StripeRows(view)
    local buttons = view.buttons
    if type(buttons) ~= "table" then return end
    for i = 1, #buttons do
        local row = buttons[i]
        if row then
            local d = ns.D(row)
            if not d.done then ns.Safe(ns.SkinObject, row) end
            if d.zebra then
                d.zebra:SetShown(G("zebra") and (i % 2 == 0) and true or false)
            end
        end
    end
end

function ns.InstallHooks()
    for i = 1, #CTOR_CLASSES do
        ns.HookConstructor(CTOR_CLASSES[i])
    end

    -- DataGridView inherits ListView.UpdateItems, so hooking ListView covers it.
    ns.HookClass("ListView", "UpdateItems", StripeRows, true)
    ns.HookClass("GridView", "UpdateItems", StripeRows, true)

    -- SetStatus is the tab selection signal; re-run every call (it re-shows the
    -- art slices and swaps the disabled font object).
    ns.HookClass("BottomTabButton", "SetStatus", ns.SkinTab, true)
    ns.HookClass("InTabButton", "SetStatus", ns.SkinTab, true)

    -- Drop menus are lazily created and pooled per level; the constructor hook
    -- only catches the ones built after login.
    ns.HookClass("DropMenu", "Open", function(self, level)
        local menu = self.menuList and self.menuList[level or 1]
        if menu then ns.Safe(ns.SkinMenu, menu) end
    end, true)

    ns.HookClass("InputBox", "OpenAutoCompleteMenu", function(self)
        local menu = self.AutoCompleteMenu
        if menu then ns.Safe(ns.SkinMenu, menu) end
    end, true)

    -- DataGridView builds its header buttons through AddHeader.
    ns.HookClass("DataGridView", "AddHeader", function(self)
        local list = self.sortButtons
        if type(list) ~= "table" then return end
        for i = 1, #list do ns.Safe(ns.SkinSortButton, list[i]) end
    end, true)
end
