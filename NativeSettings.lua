-- Native SettingPanel presentation. AceConfig option definitions remain the
-- authority for storage, dependencies and confirmations; no upstream edits.
local ADDON, ns = ...
-- AceConfigRegistry requires a versioned caller identity (e.g. MyLib-1.0),
-- including when the registered options table has already been validated.
-- This is the adapter identity, not the release version from the TOC.
local UI_NAME = ADDON .. "-1.0"
local L = ns.SettingsLayout
local PAD, NAV, ROW = L.PAD, L.NAV, L.ROW
local Place, Label = L.Place, L.Label
local GROUPS = {
    { "常规与交互", "入口、悬浮窗与申请提醒", { "minimap", "panel", "panelLock", "globalPanelPos", "sound" } },
    { "图标与信息", "职业标识与队伍信息；依赖项随原版规则显示", { "showclassico", "showspecico", "showSmRoleIco", "classIcoMsOnly", "enableLeaderColor", "enableRaiderIO" } },
    { "界面与兼容", "窗口缩放与第三方插件兼容", { "uiScale", "showWindClassIco", "useWindSkin", "useNDuiSkin" } },
    { "屏蔽与过滤", "活动类型、同标题屏蔽与关键词规则", { "packedPvp", "enableIgnoreTitle", "spamWord", "spamLengthEnabled", "spamLength" } },
    { "快捷键与维护", "按键绑定与历史记录管理", { "key", "clearhistory" } },
}
-- Short captions keep the grid aligned. The original name/description is also
-- available on hover, and all behavior comes from the original definition.
local COPY = {
    minimap = { "小地图按钮", "显示集合石的小地图入口" },
    panel = { "显示悬浮窗", "也可通过 /ms 或 /meetingstone 打开集合石" },
    panelLock = { "锁定悬浮窗", "关闭悬浮窗时，此项不可用" },
    globalPanelPos = { "全角色共用悬浮窗位置", "账号通用 · 修改后按原版提示重载界面" },
    sound = { "活动申请提示音", "收到活动申请时播放提醒" },
    packedPvp = { "整合 PvP 活动", "在活动类型过滤器中整合 PvP 分类" },
    enableIgnoreTitle = { "同标题屏蔽", "使用原版的同标题活动屏蔽规则" },
    showclassico = { "显示职业图标", "启用后显示下方图标选项 · 需要重载界面" },
    showspecico = { "显示专精图标", "跟随原版职业图标设置" },
    showSmRoleIco = { "显示小职责图标", "跟随原版职业图标设置" },
    classIcoMsOnly = { "职业图标仅用于集合石", "修改后按原版提示重载界面" },
    enableLeaderColor = { "队长职业颜色", "以职业颜色显示队长" },
    enableRaiderIO = { "RaiderIO 数据", "仅在 RaiderIO 可用时显示此项" },
    showWindClassIco = { "Wind 职业图标", "需要 ElvUI WindTools · 需要重载界面" },
    useWindSkin = { "使用 Wind 皮肤", "需要 ElvUI WindTools · 需要重载界面" },
    useNDuiSkin = { "使用 NDui 皮肤增强", "需要 NDui Plus · 需要重载界面" },
    uiScale = { "集合石窗口缩放", "百分比 · 50%–200%，每次调整 10%" },
    spamWord = { "关键词过滤", "按下方词库过滤活动列表" },
    spamLengthEnabled = { "活动说明字数过滤", "超过设定字数的活动将被屏蔽" },
    spamLength = { "活动说明字数上限", "启用字数过滤后生效" },
    key = { "打开 / 关闭集合石", "点击后按键；Esc 清除，再次点击取消录入" },
    clearhistory = { "清理创建与搜索历史", "需要确认；不会重置其他设置" },
}



-- Nil, not false, means inherit. Supports method-name handlers as AceConfig
-- does, but never changes the registry table or installs global AceGUI hooks.
local function Read(row, field, ...)
    local value = row.option[field]
    if value == nil then value = row.root[field] end
    if type(value) == "function" then return value(row.info, ...) end
    local handler = row.option.handler or row.root.handler
    if type(value) == "string" and handler and type(handler[value]) == "function"
        and field ~= "name" and field ~= "desc" then
        return handler[value](handler, row.info, ...)
    end
    return value
end

local function StopEditing(u)
    for _, row in ipairs(u.rows) do
        if row.editing then row.control:ClearFocus() end
    end
end

local function StopCapture(u)
    local row = u.byKey.key
    local w = row and row.widget
    if w and w.waitingForKey then
        w.waitingForKey = nil
        w.button:EnableKeyboard(false)
        w.button:EnableMouseWheel(false)
        w.button:UnlockHighlight()
        w.msgframe:Hide()
    end
end

local function Scroll(u, value)
    local limit = math.max(0, u.content:GetHeight() - u.scroll:GetHeight())
    u.scroll:SetVerticalScroll(math.max(0, math.min(value, limit)))
end

local Refresh
local function Commit(u, row, value)
    if u.loading then return end
    if Read(row, "disabled") or Read(row, "hidden") then Refresh(u); return end
    local function apply()
        -- A confirmation may outlive changes made in another options window.
        if not Read(row, "disabled") and not Read(row, "hidden") then
            if row.option.type == "execute" then Read(row, "func")
            else Read(row, "set", value) end
        end
        Refresh(u)
    end
    local question = Read(row, "confirm", value)
    if question then
        StopCapture(u)
        ns.GUI:CallMessageDialog(type(question) == "string" and question or ("确认修改：" .. (Read(row, "name") or row.key) .. "？"), function(result)
            if result then apply() else Refresh(u) end
        end)
    else
        apply()
    end
end

local function Tooltip(row, owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(Read(row, "name") or row.key)
    local desc = Read(row, "desc")
    if desc and desc ~= "" then GameTooltip:AddLine(desc, 1, 1, 1, true) end
    GameTooltip:Show()
end

local function BuildRow(u, key, option, root, app, category)
    local kind = option.type
    if kind ~= "toggle" and kind ~= "range" and kind ~= "keybinding" and kind ~= "execute" then return end
    local row = { key = key, option = option, root = root, category = category,
        info = { key, [0] = app, options = root, appName = app, arg = option.arg, uiType = "dialog", uiName = UI_NAME } }
    row.frame = CreateFrame("Frame", nil, u.content)
    ns.Inset(row.frame)
    local copy = COPY[key] or { Read(row, "name") or key, "" }
    row.label = Label(row.frame, copy[1])
    row.hint = Label(row.frame, copy[2], true)
    row.frame:EnableMouse(true)
    row.frame:SetScript("OnEnter", function(self) Tooltip(row, self) end)
    row.frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    if kind == "toggle" then
        row.control = ns.GUI:GetClass("CheckBox"):New(row.frame)
        row.control:SetText("")
        ns.SkinSwitch(row.control)
        row.control:SetScript("OnClick", function(self) Commit(u, row, not not self:GetChecked()) end)
    elseif kind == "range" then
        row.factor = key == "uiScale" and 100 or 1
        row.control = ns.GUI:GetClass("NumericBox"):New(row.frame)
        row.control:SetMinMaxValues(option.min * row.factor, option.max * row.factor)
        row.control:SetValueStep((option.step or 1) * row.factor)
        -- InputBox's enabled-state handlers expect a Label, even when the
        -- presentation uses a separate caption. Create it through the public API.
        row.control:SetLabel(" ")
        row.control:SetLabel("")
        row.control:EnableControl()
        local function saveNumber(value)
            if u.loading or row.editing then return end
            local step, low, high = option.step or 1, option.min, option.max
            value = value / row.factor
            value = math.max(low, math.min(high, low + math.floor((value - low) / step + .5) * step))
            if value ~= Read(row, "get") then Commit(u, row, value)
            else Refresh(u) end
        end
        row.control:SetCallback("OnValueChanged", function(_, value) saveNumber(value) end)
        -- Do not replace the first digit with the clamped minimum while typing
        -- 150%. Native NumericBox still supplies bounds and spinner behavior.
        row.control:HookScript("OnEditFocusGained", function() row.editing = true end)
        row.control:HookScript("OnEditFocusLost", function(self)
            row.editing = nil
            saveNumber(self:GetNumber())
        end)
        row.control:SetScript("OnEscapePressed", function(self)
            row.editing = nil
            Refresh(u)
            self:ClearFocus()
        end)
        if row.factor == 100 then row.unit = Label(row.frame, "%", true) end
    elseif kind == "keybinding" then
        local w = u.ace:Create("Keybinding")
        w.frame:SetParent(row.frame)
        w:SetLabel("")
        w:SetCallback("OnKeyChanged", function(_, _, keyValue) Commit(u, row, keyValue) end)
        row.widget, row.control = w, w.button
        ns.SkinButton(w.button)
        w.frame:Show()
    else
        row.control = CreateFrame("Button", nil, row.frame, "UIPanelButtonTemplate")
        row.control:SetText("清理历史")
        row.control:SetScript("OnClick", function() Commit(u, row) end)
        ns.SkinButton(row.control)
    end
    -- Preserve AceGUI's existing hover callbacks (notably keybinding capture).
    row.control:HookScript("OnEnter", function(self) Tooltip(row, self) end)
    row.control:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    u.byKey[key] = row
    u.rows[#u.rows + 1] = row
end

local function Layout(u)
    local w, height = L.Page(u, u.panel, u.footer)
    if not w then return end
    Place(u.originalButton, u.nav, 8, height - 2 * PAD - 34, NAV - 16, 26)
    local y = 0
    for _, row in ipairs(u.rows) do
        local shown = row.category == u.selected and not Read(row, "hidden")
        row.frame:SetShown(shown)
        if shown then
            local kind = row.option.type
            L.Row(row, u.content, y, w, kind == "range" and "number" or kind == "execute" and "action" or kind)
            y = y + ROW + 4
        end
    end
    u.compatNote:SetShown(u.selected == 3)
    if u.selected == 3 then
        Place(u.compatNote, u.content, 12, y + 6, w - 24, 38)
        y = y + 52
    end
    if u.keyword then
        u.keyword:SetShown(u.selected == 4)
        if u.selected == 4 then
            Place(u.keyword, u.content, 0, y + 4, w, 240)
            y = y + 252
        end
    else
        u.keywordNote:SetShown(u.selected == 4)
        if u.selected == 4 then
            Place(u.keywordNote, u.content, 12, y + 8, w - 24, 42)
            y = y + 60
        end
    end
    u.content:SetHeight(math.max(1, y))
    Scroll(u, u.scroll:GetVerticalScroll())
end

Refresh = function(u)
    if u.loading then return end
    u.loading = true
    for _, row in ipairs(u.rows) do
        local disabled = not not Read(row, "disabled")
        local value = Read(row, "get")
        if row.widget then
            row.widget:SetKey(value or "")
            row.widget:SetDisabled(disabled)
        else
            row.control:SetEnabled(not disabled)
            if row.option.type == "toggle" then row.control:SetChecked(not not value)
            elseif row.option.type == "range" and not row.editing then
                row.control:SetNumber(math.floor((tonumber(value) or row.option.min) * row.factor + .5))
            end
        end
        row.label:SetTextColor(disabled and .45 or .88, disabled and .49 or .91, disabled and .52 or .94)
    end
    u.loading = false
    u.title:SetText(GROUPS[u.selected][1])
    u.subtitle:SetText(GROUPS[u.selected][2])
    Layout(u)
end

local function AdoptKeywords(u, p)
    local list = p.SpamWordList
    local inset = list and list:GetParent()
    local widget = inset and inset:GetParent()
    if not widget or widget:GetParent() ~= p then return end
    u.keyword = widget
    widget:SetParent(u.content)
    ns.Inset(widget)
    widget.Text:ClearAllPoints()
    widget.Text:SetPoint("TOPLEFT", widget, "TOPLEFT", 12, -10)
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", widget, "TOPLEFT", 8, -38)
    inset:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", -8, 40)
    -- Only direct action buttons, never list items. Keep every original closure.
    local footer = 0
    for _, button in ipairs({ widget:GetChildren() }) do
        if button:GetObjectType() == "Button" then
            local text = button:GetText()
            button:ClearAllPoints()
            button:SetSize(64, 24)
            if text == ADD then button:SetPoint("TOPRIGHT", widget, "TOPRIGHT", -80, -7)
            elseif text == RESET then button:SetPoint("TOPRIGHT", widget, "TOPRIGHT", -8, -7)
            else
                button:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", -8 - footer * 72, 8)
                footer = footer + 1
            end
            ns.SkinButton(button)
        end
    end
end

function ns.SetupNativeSettings(p)
    if not p then return end
    local d = ns.D(p)
    if d.nativeSettings then Refresh(d.nativeSettings); return end
    local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
    local ace = LibStub and LibStub("AceGUI-3.0", true)
    if not (registry and ace and ns.GUI) then return end
    local root = registry:GetOptionsTable("MeetingStone", "dialog", UI_NAME)
    if not (root and root.args) then return end
    local filters = registry:GetOptionsTable("MeetingStone Filters", "dialog", UI_NAME)
    local originals = {}
    for _, frame in ipairs({ p:GetChildren() }) do
        if frame.obj and frame.obj.type == "BlizOptionsGroup" then originals[#originals + 1] = frame end
    end
    -- Do not replace an unrecognized third-party/native layout.
    if #originals == 0 then return end
    local u = { panel = p, ace = ace, originals = originals, byKey = {}, rows = {}, categories = {}, selected = 1 }
    u.host = CreateFrame("Frame", nil, p)
    u.nav = CreateFrame("Frame", nil, u.host)
    ns.Inset(u.nav)
    u.navTitle = Label(u.nav, "集合石设置")
    u.title = Label(u.host, "")
    u.subtitle = Label(u.host, "", true)
    u.footer = Label(u.host, "修改即时保存 · 需要重载的选项仍会显示原版提示", true)
    u.scroll = CreateFrame("ScrollFrame", nil, u.host, "UIPanelScrollFrameTemplate")
    u.content = CreateFrame("Frame", nil, u.scroll)
    u.content:SetPoint("TOPLEFT", u.scroll, "TOPLEFT", 0, 0)
    u.scroll:SetScrollChild(u.content)
    u.scroll:EnableMouseWheel(true)
    u.scroll:SetScript("OnMouseWheel", function(_, delta) Scroll(u, u.scroll:GetVerticalScroll() - delta * 40) end)
    for i, group in ipairs(GROUPS) do
        local category = {}
        local index = i
        category.button = CreateFrame("Button", nil, u.nav, "UIPanelButtonTemplate")
        category.button:SetText(group[1])
        ns.SkinButton(category.button)
        ns.Mark(category.button) -- keep the selected accent during later walks
        category.mark = ns.Tex(category.button, "OVERLAY", 1, 1, 1, 1)
        ns.Accent(category.mark, 1)
        category.mark:SetPoint("TOPLEFT", category.button, "TOPLEFT", 0, -3)
        category.mark:SetSize(3, 26)
        category.button:SetScript("OnClick", function()
            StopEditing(u)
            StopCapture(u)
            u.selected = index
            Scroll(u, 0)
            Refresh(u)
        end)
        u.categories[i] = category
        for _, key in ipairs(group[3]) do
            local isFilter = key == "spamWord" or key == "spamLengthEnabled" or key == "spamLength"
            local options = isFilter and filters or root
            if options and options.args[key] then
                BuildRow(u, key, options.args[key], options, isFilter and "MeetingStone Filters" or "MeetingStone", i)
            end
        end
    end
    u.compatNote = Label(u.content, "Wind / NDui 兼容项仅在对应插件加载时显示。\n皮肤外观参数请前往「界面美化」标签。", true)
    u.compatNote:SetWordWrap(true)
    u.keywordNote = Label(u.content, "当前集合石版本未启用关键词模块。\n本美化不会强行开启或改动原版的词库数据。", true)
    u.keywordNote:SetWordWrap(true)
    u.originalButton = CreateFrame("Button", nil, u.nav, "UIPanelButtonTemplate")
    u.originalButton:SetText("原版设置")
    ns.SkinButton(u.originalButton)
    u.originalButton:SetScript("OnClick", function()
        StopEditing(u)
        StopCapture(u)
        local dialog = LibStub("AceConfigDialog-3.0", true)
        if dialog then dialog:Open("MeetingStone") end
    end)
    -- Hide only after a complete build. Park the shells, not the shared library
    -- or the options definitions. A later native :Show() cannot overlap us.
    if filters then AdoptKeywords(u, p) end
    u.keywordNote:SetShown(not u.keyword)
    u.parking = CreateFrame("Frame", nil, p)
    u.parking:Hide()
    for _, frame in ipairs(originals) do frame:SetParent(u.parking) end
    d.nativeSettings = u
    p:HookScript("OnShow", function() Refresh(u) end)
    p:HookScript("OnHide", function() StopEditing(u); StopCapture(u) end)
    p:HookScript("OnSizeChanged", function() Layout(u) end)
    u.host:HookScript("OnHide", function() StopEditing(u); StopCapture(u) end)
    Refresh(u)
    ns.QueueWalk(u.host)
end
