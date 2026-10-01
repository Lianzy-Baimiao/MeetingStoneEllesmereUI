-- Presentation of manager/recent/ignore pages. Native controls and list data
-- remain the owners of records, invitations and destructive actions. Narrow
-- behavior fixes: real bulk-select semantics and view-only recent aggregates.
local ADDON, ns = ...
local pages = setmetatable({}, { __mode = "k" })
local Refresh, Deferred
local GAP, EDGE, FOOTER, ROW = 10, 14, 42, 26
local SIDEBAR = 208
local RIGHT_START = SIDEBAR + 12 -- shared by the applicant panel AND its blocker
local function Place(f, relative, x, y, width, height)
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", relative, "TOPLEFT", x, -y)
    f:SetSize(width, height)
end
local function Label(f)
    if not (f and f.SetFont) then return end
    local path, flags = ns.S.GetFont()
    ns.ClaimFont(f)
    f:SetFont(path or STANDARD_TEXT_FONT, ns.Get("labelFontSize"), flags or "")
end
local function Within(f, owner)
    for i = 1, 8 do
        if not f then return false end
        if f == owner then return true end
        f = f.GetParent and f:GetParent()
    end
    return false
end
local function TextChild(p, text, objectType)
    if not p then return end
    for i = 1, select("#", p:GetChildren()) do
        local child = select(i, p:GetChildren())
        if child.GetText and child:GetText() == text
            and (not objectType or child:GetObjectType() == objectType) then return child end
    end
end
local function Heading(p, s, text, main)
    if not s.heading then s.heading = p:CreateFontString(nil, "OVERLAY", "GameFontNormal") end
    Label(s.heading); s.heading:SetText(text)
    s.heading:ClearAllPoints(); s.heading:SetPoint("TOPLEFT", main, "TOPLEFT", EDGE, -36)
end
local function Button(f, main, x, y, width)
    if not f then return end
    Place(f, main, x, y, width, ROW)
    ns.SkinButton(f)
end
-- Description is borrowed from Blizzard. Only its fixed viewport is resized;
-- never change the scrolling EditBox's height, text, focus or input scripts.
local function ReleaseViewport(f, entry)
    if not entry.viewportPoints then return end
    -- A new owner may already have supplied its own anchors. Do not overwrite
    -- those with the anchors from our TitleWidget after a SetParent callback.
    if f:GetParent() == entry.viewportParent then
        f:ClearAllPoints()
        for _, point in ipairs(entry.viewportPoints) do f:SetPoint(unpack(point)) end
    end
    entry.viewportPoints, entry.viewportParent = nil, nil
end
local function SizeViewport(f, entry)
    if not entry.viewportPoints then
        entry.viewportPoints, entry.viewportParent = {}, f:GetParent()
        for i = 1, f:GetNumPoints() do
            entry.viewportPoints[i] = { f:GetPoint(i) }
        end
    end
    local top = math.max(24, ns.Get("labelFontSize") + 10)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", entry.owner, "TOPLEFT", 8, -top)
    f:SetPoint("BOTTOMRIGHT", entry.owner, "BOTTOMRIGHT", -8, 6)
end
local function Input(p, s, f, owner, dropdown, height, textOwner)
    if not f or not owner then return end
    local entry = s.inputs[f]
    if not entry then
        entry = { owner = owner, dropdown = dropdown, height = height }
        s.inputs[f] = entry
        local function changed()
            if not p:IsVisible() or not Within(f, owner) or (textOwner and not Within(textOwner, f)) then
                ReleaseViewport(f, entry)
                ns.SetControlChrome(f, false)
            end
            Deferred(p)
        end
        f:HookScript("OnShow", changed)
        -- ScrollFrames have no OnEnable/OnDisable scripts; their EditBox does.
        local control = textOwner or f
        control:HookScript("OnEnable", changed); control:HookScript("OnDisable", changed)
        if textOwner then hooksecurefunc(textOwner, "SetParent", changed) end
        if not dropdown then hooksecurefunc(f, "SetParent", changed) end
    end
    local active = p:IsVisible() and Within(f, owner) and owner:IsVisible()
        and (not textOwner or Within(textOwner, f))
    if textOwner and active then SizeViewport(f, entry)
    else ReleaseViewport(f, entry) end
    ns.SetControlChrome(f, active, dropdown, height, textOwner)
end
local function Release(s)
    for f, entry in pairs(s.inputs) do
        ReleaseViewport(f, entry)
        ns.SetControlChrome(f, false)
    end
end
-- Header widths and already-created cell anchors must change together. Changing
-- only a SortButton leaves pooled rows at the old column coordinates.
local COLUMN_WIDTHS = {
    ApplicantPanel = { Icon=24, Name=100, Role=32, Class=32, FactionGroup=32, Level=112, ItemLevel=44, Option=136 },
    RecentPanel = { Flag=30, Name=160, Class=50, Role=50, ItemLevel=54, Activity=150, Time=140 },
    IgnoreListPanel = { ["@"]=32, Leader=210, Time=180 },
}
local FLEX_COLUMN = { ApplicantPanel="Msg", RecentPanel="Notes", IgnoreListPanel="Dep" }
local function Columns(view, kind)
    local headers = view.sortButtons
    if type(headers) ~= "table" or #headers == 0 then return end
    local width = view:GetWidth() - (view.ScrollBar and 16 or 0)
    if width <= 0 then return end
    local wanted, flexible = COLUMN_WIDTHS[kind], FLEX_COLUMN[kind]
    local fixed, flex, actionWidth = 0, nil, 0
    for _, h in ipairs(headers) do
        local d = ns.D(h)
        d.tableWidth = d.tableWidth or h.width or h:GetWidth()
        if h.key == flexible then flex = h
        else fixed = fixed + (wanted[h.key] or d.tableWidth) end
        -- Native invite/decline controls plus their pending spinner use 134px.
        -- Keep that geometry even when text columns must shrink.
        if kind == "ApplicantPanel" and h.key == "Option" then actionWidth = wanted.Option end
    end
    -- For unexpected narrow windows, scale columns instead of putting action
    -- buttons outside the table. Normal 922-unit windows keep readable widths.
    local ratio = math.max(0, math.min(1, (width - actionWidth) / (fixed - actionWidth + (flex and 64 or 0))))
    local x = 0
    for _, h in ipairs(headers) do
        local w
        if h == flex then w = math.max(24, width - actionWidth - (fixed - actionWidth) * ratio)
        elseif actionWidth > 0 and h.key == "Option" then w = actionWidth
        else w = (wanted[h.key] or ns.D(h).tableWidth) * ratio end
        h.width = w
        Place(h, view, x, -ROW, w, ROW)
        ns.Safe(ns.SkinSortButton, h)
        for _, row in ipairs(view.buttons or {}) do
            local cell = row[h.key]
            if cell and cell.ClearAllPoints then
                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
                cell:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, 0)
                cell:SetWidth(w)
            end
        end
        x = x + w
    end
    ns.SkinListSelections(view)
end
local function Table(p, view, kind, y)
    if not view then return end
    Place(view, p, 0, y or 0, p:GetWidth(), p:GetHeight() - (y or 0))
    local d = ns.D(view)
    if not d.tableHooks then
        d.tableHooks = true
        if view.UpdateItems then
            hooksecurefunc(view, "UpdateItems", function() Columns(view, kind) end)
        end
    end
    Columns(view, kind)
end
local function Page(p, main, top)
    Place(p, main, EDGE, top, main:GetWidth() - 2 * EDGE, math.max(80, main:GetHeight() - top - FOOTER))
end
-- Recent's native Update returns early when code is nil. Add view-only
-- aggregate filters; keep actual RecentPlayer objects and their owning managers
-- so notes, class/role/search, sorting and confirmed deletion remain native.
local function CurrentSeasonGroups()
    local filters = Enum and Enum.LFGListFilter
    if not (filters and filters.CurrentSeason and filters.PvE and bit and bit.bor
        and C_LFGList and C_LFGList.GetAvailableActivityGroups) then return end
    local groups = C_LFGList.GetAvailableActivityGroups(2, bit.bor(filters.CurrentSeason, filters.PvE))
    if type(groups) ~= "table" then return end
    local result = {}
    for _, id in ipairs(groups) do result[id] = true end
    return result
end
local function RecentFilters(p, s)
    if s.recentFilters then return end
    local recent, dd = ns.Module("Recent"), p.ActivityDropdown
    if not (recent and type(recent.managers) == "table" and p.Update and dd
        and dd.GetMenuTable and dd.SetMenuTable) then return end
    local state = {}
    s.recentFilters = state
    local function checked(item, owner) return owner:GetValue() == item.value end
    state.all = { text="全部活动", value=0, checkable=true, checked=checked }
    state.season = { text="赛季地下城", value="mplus", checkable=true, checked=checked }
    state.dungeons = { text="全部地下城（含历史）", value="2-0-0-0", checkable=true, checked=checked }
    state.separator = { isSeparator=true }
    state.nativeUpdate = p.Update
    p.Update = function(self, ...)
        local code = self.code
        if code ~= 0 and code ~= "mplus" then return state.nativeUpdate(self, ...) end
        local groups = code == "mplus" and CurrentSeasonGroups()
        local list = {}
        for _, manager in pairs(recent.managers) do
            if code == 0 or (groups and manager:GetCategoryID() == 2 and groups[manager:GetGroupID()]) then
                for _, player in manager:IteratePlayers() do list[#list + 1] = player end
            end
        end
        self.MemberList:SetItemList(list)
        self.MemberList:Refresh()
    end
    local function menuChanged(self, original)
        if state.busy then return end
        state.busy = true
        -- Never insert into MeetingStone's shared/cached native menu table.
        local menu = { state.all, state.season, state.dungeons, state.separator }
        for _, item in ipairs(original or {}) do
            if item ~= state.all and item ~= state.season and item ~= state.dungeons
                and item ~= state.separator then menu[#menu + 1] = item end
        end
        self:SetMenuTable(menu)
        state.busy = nil
        if p.code == nil or p.code == 0 then self:SetItem(state.all) end
    end
    hooksecurefunc(dd, "SetMenuTable", menuChanged)
    menuChanged(dd, dd:GetMenuTable())
    -- Availability/season data may arrive after login or after opening the page.
    if p.LFG_LIST_AVAILABILITY_UPDATE then
        hooksecurefunc(p, "LFG_LIST_AVAILABILITY_UPDATE", function()
            if p.code == "mplus" then p:Refresh() end
        end)
    end
end
local function Recent(p, s, main)
    RecentFilters(p, s)
    local labelHeight = ns.Get("labelFontSize") + 2
    local inputTop = 34 + labelHeight + 6
    Page(p, main, inputTop + ROW + GAP + ROW)
    local x = EDGE
    local keys = { "ActivityDropdown", "ClassDropdown", "RoleDropdown", "SearchInput" }
    local widths = { 180, 100, 100, math.min(260, main:GetWidth() - 2 * EDGE - 440 - 122) }
    for i, key in ipairs(keys) do
        local f = p[key]
        if f then
            if not s.labels[key] then
                local _, label = f:GetPoint(1)
                if label and label.GetObjectType and label:GetObjectType() == "FontString" then s.labels[key] = label end
            end
            local label = s.labels[key]
            if label then
                Label(label); Place(label, main, x, 34, widths[i], labelHeight)
            end
            Place(f, main, x, inputTop, widths[i], ROW)
            Input(p, s, f, p, i < 4)
            x = x + widths[i] + GAP
        end
    end
    Button(p.BatchDeleteButton, main, main:GetWidth() - EDGE - 112, inputTop, 112)
    Table(p, p.MemberList, "RecentPanel")
end
local function Ignore(p, s, main)
    Page(p, main, 88)
    Heading(p, s, "屏蔽玩家列表 · 勾选后批量移除", main)
    s.remove = s.remove or TextChild(p, "移除勾选玩家", "Button")
    s.select = s.select or TextChild(p, "全选/取消全选", "Button")
    if s.select and not s.selectFixed then
        s.selectFixed = true
        -- EX's label says select-all, but its original callback inverts each
        -- entry. Mixed state must become ALL, not a different mixed state.
        s.select:SetScript("OnClick", function()
            local list = MEETINGSTONE_UI_DB and MEETINGSTONE_UI_DB.IGNORE_LIST
            if type(list) ~= "table" then return end
            local selectAll = false
            for _, entry in ipairs(list) do
                if not entry.selected then selectAll = true; break end
            end
            for _, entry in ipairs(list) do entry.selected = selectAll end
            p.IgnoreList:Refresh()
        end)
    end
    Button(s.select, main, EDGE, main:GetHeight() - 34, 140)
    Button(s.remove, main, main:GetWidth() - EDGE - 140, main:GetHeight() - 34, 140)
    Table(p, p.IgnoreList, "IgnoreListPanel")
end
local function Manager(p, s, main)
    Page(p, main, 64)
    -- The tab already names this page. Reserve the left toolbar for the native
    -- auto-invite switch instead of a duplicate heading that pushes it right.
    if p.RefreshButton then
        local button = p.RefreshButton
        ns.SkinButton(button)
        -- This is a labelled RefreshButton, not a 28px icon-only control.
        -- Remove the old icon AND its 8px label offset; Hide survives the
        -- native OnEnable/OnDisable alpha updates without replacing handlers.
        if button.Icon then button.Icon:Hide() end
        local label = button.GetFontString and button:GetFontString()
        local width = 76
        if label then
            label:ClearAllPoints()
            label:SetPoint("CENTER", button, "CENTER", 0, 0)
            label:SetWordWrap(false)
            width = math.max(width, math.ceil(label:GetStringWidth()) + 24)
        end
        Place(button, main, main:GetWidth() - EDGE - width, 32,
            width, math.max(28, ns.Get("labelFontSize") + 8))
    end
    local create = ns.Module("CreatePanel")
    if p.ApplicantListBlocker and create then
        Place(p.ApplicantListBlocker, p, RIGHT_START, 0, math.max(1, p:GetWidth() - RIGHT_START), p:GetHeight())
    end
end
local function Card(w)
    if not w then return end
    ns.SetControlChrome(w, true, false)
    if w.Text then
        Label(w.Text)
        w.Text:ClearAllPoints(); w.Text:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -6)
    end
end
local function HideDivider(p, s)
    -- CreatePanel's local decorative VerticalLine is a NetEaseGUI class, not
    -- an input or blocker. Match its type, never a file path/ID or exact float
    -- width (client scaling may return 12.000001 rather than 12).
    if not s.nativeDivider then
        local class = ns.GetClass and ns.GetClass("VerticalLine")
        if not class then return end
        for i = 1, select("#", p:GetChildren()) do
            local child = select(i, p:GetChildren())
            if child.IsType then
                local ok, matches = pcall(child.IsType, child, class)
                if ok and matches then
                    s.nativeDivider = child
                    -- A native refresh must not bring decorative art back.
                    -- Hook rather than replace its Show method or scripts.
                    child:HookScript("OnShow", function(self) self:Hide() end)
                    break
                end
            end
        end
    end
    if s.nativeDivider then s.nativeDivider:Hide() end
    -- No replacement line: the existing 12-unit column gap is the separator.
end
local function Create(p, s, main)
    local manager = ns.Module("ManagerPanel")
    if not manager then return end
    Place(p, manager, 0, 0, SIDEBAR, manager:GetHeight())
    HideDivider(p, s)
    local activity = p.ActivityType and p.ActivityType:GetParent()
    local form = p.CreateWidget
    s.title = s.title or TextChild(form, "活动标题")
    s.summary = s.summary or TextChild(form, "活动说明")
    local voice = p.ItemLevel and p.ItemLevel:GetParent()
    if activity then
        Place(activity, form or p, 0, 0, p:GetWidth(), 84); Card(activity)
        Place(p.ActivityType, activity, 8, 26, p:GetWidth() - 16, ROW)
        Place(p.GeneralPlaystyle, activity, 8, 54, p:GetWidth() - 16, ROW)
        Input(p, s, p.ActivityType, activity, true)
        Input(p, s, p.GeneralPlaystyle, activity, true)
    end
    if s.title then
        Place(s.title, form, 0, 88, p:GetWidth(), 56); Card(s.title)
        Input(p, s, p.TitleBox, s.title, false)
    end
    if voice then
        local top = p:GetHeight() - 106
        Place(voice, form or p, 0, top, p:GetWidth(), 106); Card(voice)
        Place(p.ItemLevel, voice, 84, 6, 112, 24)
        Place(p.Score, voice, 84, 32, 112, 24)
        for _, f in ipairs({ p.ItemLevel, p.Score }) do
            if f then
                Label(f.Label)
                Input(p, s, f, voice, false)
            end
        end
        -- Keep native title/voice anchors and all input callbacks. Description
        -- below borrows viewport anchors only; release font/art/geometry on hide.
        Input(p, s, p.VoiceBox, voice, false, 24)
        Place(p.PrivateGroup, voice, 8, 80, 22, 22)
        Place(p.CrossFactionGroup, voice, 108, 80, 22, 22)
        if p.PrivateGroup then ns.SkinSwitch(p.PrivateGroup) end
        if p.CrossFactionGroup then ns.SkinSwitch(p.CrossFactionGroup) end
        if s.summary then
            Place(s.summary, form, 0, 148, p:GetWidth(), math.max(36, top - 152)); Card(s.summary)
            local edit = p.SummaryBox
            local viewport = edit and edit:GetParent()
            if viewport and (viewport.EditBox == edit
                or (viewport.GetScrollChild and viewport:GetScrollChild() == edit)) then
                Input(p, s, viewport, s.summary, false, nil, edit)
            end
        end
    end
    -- Existing view-board sections inherit the widened left column. Do not fade
    -- its role/loot icons or rewrite any informational strings.
    if p.InfoWidget then p.InfoWidget:SetWidth(p:GetWidth()) end
    for _, w in ipairs({ p.InfoWidget, p.MemberWidget, p.MiscWidget }) do
        if w and w.GetRegions then
            for i = 1, select("#", w:GetRegions()) do
                local r = select(i, w:GetRegions())
                if r.GetObjectType and r:GetObjectType() == "FontString" then Label(r) end
            end
        end
    end
    s.auto = s.auto or TextChild(p, "自动邀请(需开语言过滤)", "CheckButton")
    if s.auto then
        Place(s.auto, main, EDGE, 32, 24, 24)
        ns.Safe(ns.SkinCheck, s.auto)
    end
    Button(p.CreateButton, main, main:GetWidth() - EDGE - 250, main:GetHeight() - 34, 120)
    Button(p.DisbandButton, main, main:GetWidth() - EDGE - 120, main:GetHeight() - 34, 120)
end
local function Applicant(p, s, main)
    local manager = ns.Module("ManagerPanel")
    if not manager then return end
    Place(p, manager, RIGHT_START, ROW, math.max(1, manager:GetWidth() - RIGHT_START), math.max(1, manager:GetHeight() - ROW))
    Table(p, p.ApplicantList, "ApplicantPanel")
end
local layouts = { ManagerPanel=Manager, CreatePanel=Create, ApplicantPanel=Applicant,
    RecentPanel=Recent, IgnoreListPanel=Ignore }
Refresh = function(p)
    local s = pages[p]
    if not s or s.busy then return end
    s.busy = true
    local ok, err = pcall(function()
        if not p:IsVisible() then Release(s); return end
        local main = ns.MainPanel
        if main and main:GetWidth() > 0 then layouts[s.kind](p, s, main) end
    end)
    s.busy = nil
    if not ok then error(err) end
end
Deferred = function(p)
    local s = pages[p]
    if not s or s.busy or s.pending then return end
    s.pending = true
    C_Timer.After(0, function() s.pending = nil; ns.Safe(Refresh, p) end)
end
function ns.ApplyTablePanels()
    -- Parent first: applicant/create dimensions depend on manager dimensions.
    for _, kind in ipairs({ "ManagerPanel", "CreatePanel", "ApplicantPanel", "RecentPanel", "IgnoreListPanel" }) do
        local p = ns.Module(kind)
        if p and pages[p] then ns.Safe(Refresh, p) end
    end
end
function ns.SkinTablePanel(p, kind)
    if not p or not layouts[kind] then return end
    if not pages[p] then
        pages[p] = { kind=kind, inputs={}, labels={} }
        ns.D(p).tablePanel = pages[p]
        p:HookScript("OnShow", function() ns.Safe(Refresh, p); Deferred(p) end)
        p:HookScript("OnHide", function() Release(pages[p]) end)
        p:HookScript("OnSizeChanged", function() Deferred(p) end)
    end
    local main = ns.MainPanel
    if main and not ns.D(main).tablePanelHooks then
        ns.D(main).tablePanelHooks = true
        main:HookScript("OnSizeChanged", ns.ApplyTablePanels)
        hooksecurefunc(main, "SetScale", ns.ApplyTablePanels)
        if ns.S.OnLooksChanged then ns.S.OnLooksChanged(ns.ApplyTablePanels) end
    end
    Refresh(p); Deferred(p)
end
