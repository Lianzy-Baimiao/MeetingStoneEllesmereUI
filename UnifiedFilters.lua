-- One entry, one scrollable window. Upstream still owns all filter data and
-- callbacks. Only Insets/actions are adopted; old popup shells live under a
-- permanently hidden parent, so native Show/Hide cannot create a second window.
local ADDON, ns = ...
local WIDTH, PAD, GAP = 300, 12, 8
local KEYS = { "BlzFilterPanel", "ExFilterPanel", "AdvFilterPanel" }

local function IsDungeon(p)
    local item = p.ActivityDropdown and p.ActivityDropdown:GetItem()
    return item and item.value == "mplus"
end

-- EX tags seasonal dungeon rows with numeric activity-group IDs. Role keys
-- are strings and the minimum-rating range has no ID: never bulk-edit either.
local function IsDungeonRow(row)
    return type(row.dataValue) == "number" and row.dataValue > 0
        and not row.MinBox and row.Check
end

local function HasDungeonRows(p)
    for _, row in ipairs(p.MD or {}) do
        if IsDungeonRow(row) then return true end
    end
    return false
end

local function SelectDungeons(p, checked)
    if not IsDungeon(p) then return end
    for _, row in ipairs(p.MD or {}) do
        local check = row.Check
        -- Own flags, not IsVisible: the original popup shell is parked hidden.
        if IsDungeonRow(row) and row:IsShown() and check:IsShown()
            and check:IsEnabled() and (not not check:GetChecked()) ~= checked then
            -- Click, don't SetChecked: EX's captured activities table, saving
            -- and label styling all live in the original checkbox callback.
            check:Click()
        end
    end
    -- Like individual dungeon clicks, save now and leave searching to the
    -- existing Apply button. Never send one search per dungeon in this loop.
end

local function Place(frame, parent, x, y, width, height)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    frame:SetSize(width, height)
end

local function Label(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text)
    label:SetJustifyH("LEFT")
    ns.Font(label)
    return label
end

local function SetScroll(u, value)
    local maximum = math.max(0, u.content:GetHeight() - u.scroll:GetHeight())
    u.scroll:SetVerticalScroll(math.max(0, math.min(value, maximum)))
end

local function Layout(u)
    local p, width = u.browse, WIDTH - PAD * 2 - 20
    local height = math.max(300, math.min(540, ns.MainPanel:GetHeight()))
    u.host:SetSize(WIDTH, height)
    Place(u.scroll, u.host, PAD, 38, width, height - 88)
    u.content:SetWidth(width)
    local y = 0
    Place(u.activityTitle, u.content, 0, y, width, 22)
    y = y + 28
    local key = IsDungeon(p) and "BlzFilterPanel" or "ExFilterPanel"
    u.activityTitle:SetText(IsDungeon(p) and "活动条件 · 赛季地下城" or "活动条件 · 组队")
    local active = u.sections[key]
    local bulkShown = not not (active and IsDungeon(p) and HasDungeonRows(p))
    u.dungeonLabel:SetShown(bulkShown)
    u.dungeonAll:SetShown(bulkShown)
    u.dungeonNone:SetShown(bulkShown)
    if bulkShown then
        Place(u.dungeonLabel, u.content, 4, y, 44, 24)
        Place(u.dungeonAll, u.content, 56, y, 92, 24)
        Place(u.dungeonNone, u.content, 156, y, 92, 24)
        y = y + 32
    end
    u.empty:SetShown(not active)
    if not active then
        Place(u.empty, u.content, 4, y, width - 8, 36)
        y = y + 44
    end
    for _, activityKey in ipairs({ "BlzFilterPanel", "ExFilterPanel" }) do
        local section = u.sections[activityKey]
        if section then
            section.inset:SetShown(section == active)
            if section == active then
                Place(section.inset, u.content, 0, y, width, section.height)
                y = y + section.height + GAP
            end
        end
    end
    if u.roll then
        u.roll:SetShown(not not (active and IsDungeon(p)))
        if active and IsDungeon(p) then
            Place(u.roll, u.content, 4, y, 112, 24)
            y = y + 32
        end
    end
    u.advancedY = y
    Place(u.advancedTitle, u.content, 0, y, width, 24)
    u.advancedTitle:SetText(u.expanded and "高级条件 · 范围" or "高级条件 · 已折叠")
    u.advancedToggle:SetText((u.expanded and "收起" or "展开") .. "高级条件")
    y = y + 30
    local advanced = u.sections.AdvFilterPanel
    if advanced then
        advanced.inset:SetShown(u.expanded)
        if u.expanded then
            Place(advanced.inset, u.content, 0, y, width, advanced.height)
            y = y + advanced.height + GAP
        end
    end
    u.content:SetHeight(math.max(1, y))
    SetScroll(u, u.scroll:GetVerticalScroll())
end

local function AdoptSection(u, key)
    local panel = u.browse[key]
    if not (panel and panel.Inset) then return end
    if u.sections[key] and u.sections[key].panel == panel then return end
    local inset = panel.Inset
    local rows = key == "BlzFilterPanel" and u.browse.MD
        or key == "AdvFilterPanel" and u.browse.filters
    if not rows then
        rows = {}
        -- Party rows are anonymous, created in display order by MeetingStoneEX.
        for _, child in ipairs({ inset:GetChildren() }) do
            if child.Check then rows[#rows + 1] = child end
        end
        table.sort(rows, function(a, b)
            local _, _, _, _, ay = a:GetPoint()
            local _, _, _, _, by = b:GetPoint()
            return (ay or 0) > (by or 0)
        end)
    end
    local y, width = 8, WIDTH - PAD * 2 - 20
    for _, row in ipairs(rows) do
        local height = math.max(26, row:GetHeight())
        Place(row, inset, 8, y, width - 16, height)
        y = y + height
    end
    u.sections[key] = { panel = panel, inset = inset, height = y + 8 }
    -- Keep the original shells and callbacks alive but incapable of popping up.
    panel:SetParent(u.parking)
    inset:SetParent(u.content)
    ns.Inset(inset)
    if key == "BlzFilterPanel" then
        for _, button in ipairs({ panel:GetChildren() }) do
            local text = button.GetText and button:GetText()
            if text == "搜索更多队伍" or text == "搜索队伍" then
                u.dungeonApply = button -- includes the captured minimumRating save
            elseif text == "查看Roll币池" or text == "查看R币池" then
                u.roll = button
                button:SetParent(u.content)
                ns.SkinButton(button)
            end
        end
    end
end

local function Build(p)
    local u = { browse = p, sections = {}, expanded = false }
    u.parking = CreateFrame("Frame", nil, p)
    u.parking:Hide()
    u.host = CreateFrame("Frame", nil, p)
    u.host:Hide()
    u.host:SetPoint("TOPLEFT", ns.MainPanel, "TOPRIGHT", 0, 0)
    u.host:SetFrameLevel(p:GetFrameLevel() + 20)
    u.host:SetClampedToScreen(true)
    u.host:EnableMouse(true)
    ns.Shell(u.host)
    u.title = Label(u.host, "筛选")
    u.title:SetPoint("TOPLEFT", PAD, -10)
    u.close = CreateFrame("Button", nil, u.host, "UIPanelCloseButton")
    u.close:SetPoint("TOPRIGHT", -2, -2)
    u.close:SetScript("OnClick", function() u.host:Hide() end)
    ns.SkinClose(u.close)

    u.scroll = CreateFrame("ScrollFrame", nil, u.host, "UIPanelScrollFrameTemplate")
    u.content = CreateFrame("Frame", nil, u.scroll)
    u.scroll:SetScrollChild(u.content)
    u.scroll:EnableMouseWheel(true)
    u.scroll:SetScript("OnMouseWheel", function(_, delta)
        SetScroll(u, u.scroll:GetVerticalScroll() - delta * 40)
    end)
    u.activityTitle = Label(u.content, "活动条件")
    u.dungeonLabel = Label(u.content, "副本")
    u.dungeonAll = CreateFrame("Button", nil, u.content, "UIPanelButtonTemplate")
    u.dungeonAll:SetText("全选")
    u.dungeonAll:SetScript("OnClick", function() SelectDungeons(p, true) end)
    ns.SkinButton(u.dungeonAll)
    u.dungeonNone = CreateFrame("Button", nil, u.content, "UIPanelButtonTemplate")
    u.dungeonNone:SetText("全不选")
    u.dungeonNone:SetScript("OnClick", function() SelectDungeons(p, false) end)
    ns.SkinButton(u.dungeonNone)
    u.empty = Label(u.content, "当前没有可用的活动条件")
    u.advancedTitle = Label(u.content, "高级条件")
    -- Keep the advanced entry visible even with many seasonal dungeon rows.
    u.advancedToggle = CreateFrame("Button", nil, u.host, "UIPanelButtonTemplate")
    u.advancedToggle:SetPoint("TOPRIGHT", u.host, "TOPRIGHT", -38, -4)
    u.advancedToggle:SetSize(144, 26)
    ns.SkinButton(u.advancedToggle)
    u.advancedToggle:SetScript("OnClick", function()
        u.expanded = not u.expanded
        Layout(u)
        -- Make the newly expanded controls reachable immediately, even with a
        -- long season dungeon list; the header remains above the first row.
        if u.expanded then
            SetScroll(u, u.advancedY)
        end
    end)
    p.AdvButton:SetText("筛选")
    if p.AdvButton.SetTooltip then p.AdvButton:SetTooltip("活动条件与高级条件") end
    p.AdvButton:SetScript("OnClick", function()
        u.host:SetShown(not u.host:IsShown())
    end)
    u.host:HookScript("OnShow", function() Layout(u) end)

    -- Reuse the original footer objects. The reset closure only clears the five
    -- advanced ranges. Applying dungeon filters MUST use EX's save-and-search
    -- closure (minimumRating is not persisted by its edit callback alone).
    local reset, apply = p.ResetFilterButton, p.RefreshFilterButton
    reset:SetParent(u.host)
    reset:ClearAllPoints()
    reset:SetPoint("BOTTOMLEFT", u.host, "BOTTOMLEFT", PAD, 12)
    reset:SetSize(112, 26)
    reset:SetText("重置高级")
    apply:SetParent(u.host)
    apply:ClearAllPoints()
    apply:SetPoint("BOTTOMRIGHT", u.host, "BOTTOMRIGHT", -PAD, 12)
    apply:SetSize(148, 26)
    apply:SetText("应用并刷新")
    local refreshClick = apply:GetScript("OnClick")
    apply:SetScript("OnClick", function(button, ...)
        if p.RefreshButton and not p.RefreshButton:IsEnabled() then return end
        if IsDungeon(p) and u.dungeonApply then
            if u.dungeonApply:IsEnabled() then u.dungeonApply:Click() end
        elseif refreshClick then
            refreshClick(button, ...)
        end
    end)
    ns.SkinButton(reset)
    ns.SkinButton(apply)
    return u
end

-- Safe to repeat on browse OnShow and late EX_INIT. No changes to SavedVariables
-- or replacement of upstream dropdown callbacks / category search behavior.
function ns.SetupUnifiedFilters(p)
    if not (ns.MainPanel and p.AdvButton and p.AdvFilterPanel
        and p.ResetFilterButton and p.RefreshFilterButton) then return end
    local d = ns.D(p)
    if not d.unifiedFilters then d.unifiedFilters = Build(p) end
    local u = d.unifiedFilters
    for _, key in ipairs(KEYS) do AdoptSection(u, key) end
    if p.ExSearchButton then
        p.ExSearchButton:SetParent(u.parking)
        p.ExSearchButton:Hide()
    end
    p.AdvButton:ClearAllPoints()
    p.AdvButton:SetPoint("TOPRIGHT", ns.MainPanel, "TOPRIGHT", -10, -38)
    if p.RefreshButton then
        p.RefreshButton:ClearAllPoints()
        -- Independent anchors avoid a cycle when late EX_INIT temporarily
        -- anchors AdvButton back to RefreshButton before our post-hook runs.
        p.RefreshButton:SetPoint("TOPRIGHT", ns.MainPanel, "TOPRIGHT",
            -(10 + p.AdvButton:GetWidth() + GAP), -38)
    end
    Layout(u)
    ns.QueueWalk(u.host)
end

function ns.SyncUnifiedFilters(p)
    local u = ns.D(p).unifiedFilters
    if not u then return false end
    local item = p.ActivityDropdown and p.ActivityDropdown:GetItem()
    local category = item and item.categoryId
    if u.category ~= category then
        u.category = category
        if p.UpdateFilters then p:UpdateFilters() end
        SetScroll(u, 0)
    end
    Layout(u)
    return true
end
