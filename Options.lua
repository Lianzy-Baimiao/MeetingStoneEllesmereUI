-- Skin settings: the same navigation / scrollable-row visual language as
-- NativeSettings, but this page only owns MeetingStoneEllesmereUIDB.
local ADDON, ns = ...
local TAB_NAME = "界面美化"
local L = ns.SettingsLayout
local PAD, NAV, ROW = L.PAD, L.NAV, L.ROW
local Place, Label = L.Place, L.Label
local Panel, UI

local HINTS = {
    useClassColor = "默认关闭，选中使用 EUI 图标绿；开启使用角色职业色。边框始终深色",
    bgColor = "主窗口与过滤弹窗共用，不修改 EUI 的全局配色",
    bgAlpha = "0% 完全透明，100% 完全不透明",
    topBar = "在标题区域显示深色底条",
    topBarShade = "调整标题条与窗口背景的明暗差异",
    headerShade = "调整活动列表表头的明暗差异",
    tabColor = "底部标签页底板使用独立颜色",
    tabAlpha = "标签页位于窗口外，可单独保持不透明",
    listFontSize = "活动列表中的队伍、成员与说明文字",
    labelFontSize = "按钮、选项和下拉框文字",
    tabFontSize = "底部标签页标题文字",
    fontDelta = "相对原字号缩小；不影响上方三类独立字号",
    memberIconScale = "成员职责图标跟随活动列表字号缩放",
    roleFilterBar = "仅在适用的活动类型中显示底部职责快捷项",
    noAutoFilterPopup = "旧版过滤器兼容项；合并后的筛选窗口始终手动打开",
    skinRows = "使用统一行底色与选中效果 · 更改后需要重载",
    zebra = "交替显示深浅底色，方便逐行阅读",
    zebraAlpha = "控制交替底色的强度",
    hoverAlpha = "鼠标悬停时的背景亮度",
    selectBar = "在选中行左侧显示强调色竖条",
    selectAlpha = "选中活动时的背景填充强度",
    barWidth = "选中行强调色竖条的宽度",
}
local function NewColor(parent, cfg)
    local btn = CreateFrame("Button", nil, parent)
    -- 1px dark edge so a near-black swatch is still findable on a dark panel.
    local edge = ns.Tex(btn, "BACKGROUND", 0, 0, 0, 1)
    edge:SetAllPoints(btn)
    local swatch = btn:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 1, -1)
    swatch:SetPoint("BOTTOMRIGHT", -1, 1)

    btn.Reload = function()
        local r, g, b = ns.GetColor(cfg.key)
        swatch:SetColorTexture(r, g, b, 1)
    end

    btn:SetScript("OnClick", function()
        local r, g, b = ns.GetColor(cfg.key)
        local function apply()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            ns.Set(cfg.key, { nr, ng, nb })
            btn.Reload()
        end
        local info = {
            r = r, g = g, b = b,
            swatchFunc = apply,
            opacityFunc = apply,
            cancelFunc = function()
                ns.Set(cfg.key, { r, g, b })
                btn.Reload()
            end,
        }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func = info.swatchFunc
            ColorPickerFrame.cancelFunc = info.cancelFunc
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end
    end)
    return btn
end

local GROUPS = {
    { title = "窗口与标签", fields = {
        { kind = "check",  key = "useClassColor", text = "选中状态使用职业色" },
        { kind = "color",  key = "bgColor", text = "窗口背景颜色" },
        { kind = "number", key = "bgAlpha", text = "背景不透明度 %", min = 0, max = 100, scale = 100, step = 5 },
        { kind = "check",  key = "topBar", text = "标题栏深色条" },
        { kind = "number", key = "topBarShade", text = "标题栏对比 %", min = 0, max = 100, scale = 100, step = 2 },
        { kind = "number", key = "headerShade", text = "表头对比 %", min = 0, max = 100, scale = 100, step = 2 },
        { kind = "color",  key = "tabColor", text = "标签底板颜色" },
        { kind = "number", key = "tabAlpha", text = "标签不透明度 %", min = 0, max = 100, scale = 100, step = 5 },
    } },
    { title = "字体与交互", fields = {
        { kind = "number", key = "listFontSize", text = "活动列表字号", min = 8, max = 20 },
        { kind = "number", key = "labelFontSize", text = "按钮 / 选项字号", min = 8, max = 20 },
        { kind = "number", key = "tabFontSize", text = "标签页字号", min = 8, max = 20 },
        { kind = "number", key = "fontDelta", text = "其余文字缩小", min = 0, max = 6, scale = -1 },
        { kind = "check",  key = "memberIconScale", text = "成员图标随字号" },
        { kind = "check",  key = "roleFilterBar", text = "底部快捷筛选" },
        { kind = "check",  key = "noAutoFilterPopup", text = "禁用自动弹窗 *", reload = true },
    } },
    { title = "活动列表", fields = {
        { kind = "check",  key = "skinRows", text = "列表行皮肤 *", reload = true },
        { kind = "check",  key = "zebra", text = "交替行底色" },
        { kind = "number", key = "zebraAlpha", text = "交替底色深浅 %", min = 0, max = 100, scale = 100, step = 2 },
        { kind = "number", key = "hoverAlpha", text = "悬停亮度 %", min = 0, max = 100, scale = 100, step = 1 },
        { kind = "check",  key = "selectBar", text = "选中强调色竖条" },
        { kind = "number", key = "selectAlpha", text = "选中填充 %", min = 0, max = 100, scale = 100, step = 2 },
        { kind = "number", key = "barWidth", text = "竖条宽度 px", min = 1, max = 6 },
    } },
}

local SUBTITLES = {
    "自绘控件强调色，以及窗口与标签底板的颜色和透明度",
    "文字尺寸、成员图标与快捷筛选交互",
    "列表行底色、悬停与选中效果",
}
local function Scroll(u, value)
    local limit = math.max(0, u.content:GetHeight() - u.scroll:GetHeight())
    u.scroll:SetVerticalScroll(math.max(0, math.min(value, limit)))
end
local function Layout(u)
    local w, height = L.Page(u, Panel, u.hint)
    if not w then return end
    Place(u.reset, u.nav, 8, height - 2 * PAD - 66, NAV - 16, 26)
    Place(u.reload, u.nav, 8, height - 2 * PAD - 34, NAV - 16, 26)
    local y = 0
    for _, row in ipairs(u.rows) do
        local shown = row.category == u.selected
        row.frame:SetShown(shown)
        if shown then
            L.Row(row, u.content, y, w, row.cfg.kind)
            y = y + ROW + 4
        end
    end
    u.content:SetHeight(math.max(1, y))
    Scroll(u, u.scroll:GetVerticalScroll())
end
local function ReloadAll()
    if not UI then return end
    for _, row in ipairs(UI.rows) do
        local c = row.control
        if not row.editing then
            c.loading = true
            c.Reload()
            c.loading = nil
        end
    end
end
ns.OnSettingChanged = ReloadAll
function ns.ShowReloadHint()
    if UI then
        UI.hint:SetText("部分设置已更改，请点击「重载界面」使其完全生效")
    end
end
local function StopEditing()
    if not UI then return end
    for _, row in ipairs(UI.rows) do
        if row.editing then row.control:ClearFocus() end
    end
end
local function BuildRow(u, cfg, category)
    local row = { cfg = cfg, category = category }
    row.frame = CreateFrame("Frame", nil, u.content)
    ns.Inset(row.frame)
    row.label = Label(row.frame, cfg.text)
    row.hint = Label(row.frame, HINTS[cfg.key], true)
    row.frame:EnableMouse(true)
    row.frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(cfg.text)
        GameTooltip:AddLine(HINTS[cfg.key], .8, .85, .88, true)
        GameTooltip:Show()
    end)
    row.frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    local c
    if cfg.kind == "number" then
        c = ns.GUI:GetClass("NumericBox"):New(row.frame)
        c:SetMinMaxValues(cfg.min, cfg.max)
        c:SetValueStep(cfg.step or 1)
        c:SetLabel(" "); c:SetLabel("")
        c:EnableControl()
        local scale = cfg.scale or 1
        c.Reload = function() c:SetNumber(math.floor((ns.Get(cfg.key) or 0) * scale + .5)) end
        local function save(value)
            if c.loading or row.editing then return end
            value = math.max(cfg.min, math.min(cfg.max, math.floor(value + .5)))
            if ns.Get(cfg.key) ~= value / scale then ns.Set(cfg.key, value / scale) end
        end
        c:SetCallback("OnValueChanged", function(_, value) save(value) end)
        c:HookScript("OnEditFocusGained", function() row.editing = true end)
        c:HookScript("OnEditFocusLost", function(self) row.editing = nil; save(self:GetNumber()); ReloadAll() end)
        c:SetScript("OnEscapePressed", function(self)
            row.editing = nil; ReloadAll(); self:ClearFocus()
        end)
    elseif cfg.kind == "check" then
        c = ns.GUI:GetClass("CheckBox"):New(row.frame)
        c:SetText("")
        c:SetScript("OnClick", function(self)
            ns.Set(cfg.key, not not self:GetChecked())
            if cfg.reload then ns.ShowReloadHint() end
        end)
        c.Reload = function() c:SetChecked(not not ns.Get(cfg.key)) end
        ns.SkinSwitch(c)
    else
        c = NewColor(row.frame, cfg)
        ns.Mark(c) -- don't let a later generic walk strip the swatch
    end
    row.control = c
    u.rows[#u.rows + 1] = row
    u.byKey[cfg.key] = row
end
local function Build(parent)
    local u = { categories = {}, rows = {}, byKey = {}, selected = 1 }
    UI = u
    ns.D(parent).skinOptions = u
    u.host = CreateFrame("Frame", nil, parent)
    u.nav = CreateFrame("Frame", nil, u.host); ns.Inset(u.nav)
    u.navTitle = Label(u.nav, "界面美化")
    u.title = Label(u.host, GROUPS[1].title)
    u.subtitle = Label(u.host, SUBTITLES[1], true)
    u.hint = Label(u.host, "即时保存 · 带 * 的项目需要重载界面", true)
    parent.ReloadHint = u.hint
    u.scroll = CreateFrame("ScrollFrame", nil, u.host, "UIPanelScrollFrameTemplate")
    u.content = CreateFrame("Frame", nil, u.scroll)
    u.content:SetPoint("TOPLEFT", u.scroll, "TOPLEFT", 0, 0)
    u.scroll:SetScrollChild(u.content)
    u.scroll:EnableMouseWheel(true)
    u.scroll:SetScript("OnMouseWheel", function(_, delta) Scroll(u, u.scroll:GetVerticalScroll() - delta * 40) end)
    for i, group in ipairs(GROUPS) do
        local cat, index = {}, i
        cat.button = CreateFrame("Button", nil, u.nav, "UIPanelButtonTemplate")
        cat.button:SetText(group.title)
        ns.SkinButton(cat.button); ns.Mark(cat.button)
        cat.mark = ns.Tex(cat.button, "OVERLAY", 1, 1, 1, 1)
        ns.Accent(cat.mark, 1)
        cat.mark:SetPoint("TOPLEFT", cat.button, "TOPLEFT", 0, -3)
        cat.mark:SetSize(3, 26)
        cat.button:SetScript("OnClick", function()
            StopEditing()
            u.selected = index
            u.title:SetText(group.title); u.subtitle:SetText(SUBTITLES[index])
            Scroll(u, 0); ReloadAll(); Layout(u)
        end)
        u.categories[i] = cat
        for _, cfg in ipairs(group.fields) do BuildRow(u, cfg, i) end
    end
    u.reset = CreateFrame("Button", nil, u.nav, "UIPanelButtonTemplate")
    u.reset:SetText("恢复默认")
    u.reset:SetScript("OnClick", function()
        StopEditing()
        ns.GUI:CallMessageDialog("恢复全部界面美化设置为默认值？不会改动集合石的组队或过滤配置。", function(result)
            if result then ns.ResetAll(); ns.ShowReloadHint() end
        end)
    end)
    u.reload = CreateFrame("Button", nil, u.nav, "UIPanelButtonTemplate")
    u.reload:SetText("重载界面")
    u.reload:SetScript("OnClick", function() StopEditing(); ReloadUI() end)
    ns.SkinButton(u.reset); ns.SkinButton(u.reload)
    parent:HookScript("OnSizeChanged", function() Layout(u) end)
    parent:HookScript("OnHide", StopEditing)
    Layout(u)
end
function ns.SetupOptions(MainPanel)
    if not (MainPanel and MainPanel.RegisterPanel) then return end
    if MainPanel:IsPanelRegistered(TAB_NAME) then return end
    Panel = CreateFrame("Frame", nil, MainPanel)
    ns.GUI:Embed(Panel, "Refresh")
    MainPanel:RegisterPanel(TAB_NAME, Panel, L.TabArgs(MainPanel))
    Build(Panel)
    ReloadAll()
    ns.QueueWalk(Panel)
    Panel:HookScript("OnShow", function(self) ReloadAll(); Layout(UI); ns.QueueWalk(self) end)
end
