--[[----------------------------------------------------------------------------
    MeetingStoneEllesmereUI -- Options.lua

    The settings page, registered as a tab inside MeetingStone's own window via
    MainPanel:RegisterPanel (the same door MeetingStoneEX uses for its 屏蔽玩家列表
    tab; RegisterPanel calls UpdateTab itself, so registering after login works).

    Built out of NetEaseGUI widgets rather than Blizzard templates on purpose: our
    own dispatcher then skins this page exactly like the rest of MeetingStone, so
    the options screen cannot look out of place with what it is configuring.

    Percentages are stored 0-1 but edited 0-100 -- NumericBox is integer-only, and
    "12" reads better than "0.12" for an opacity anyway.
------------------------------------------------------------------------------]]

local ADDON, ns = ...

local TAB_NAME = "界面美化"

-- Four columns.
--
-- The content area is about 892x321: MainPanel is 447 tall, less topHeight 80 and
-- bottomHeight 26 for the Inset, less RegisterPanel's 10px padding top and bottom.
--
-- 4 headings x 26 + 6 field rows x 24 = 248, +12 top pad, +34 for the button row
-- = 294, so there is ~27px of slack. 24px rows give a 20px control room to
-- breathe; 22 was cramped. Columns are 212 wide: PAD + 4x212 = 860 inside 892.
local PAD, COL_W, COLS = 12, 212, 4
local ROW_H, SECTION_H = 24, 26

-------------------------------------------------------------------------------
--  Field builders.
--
--  Every cell has the SAME geometry: label left-aligned at the column's left
--  edge, control right-aligned at its right edge. That is the whole point --
--  NumericBox:SetLabel right-aligns the label against the box, while a CheckBox
--  hangs its text off to the right, so mixing the two straight out of the box
--  left every column with a different label start and a ragged grid. We draw the
--  labels ourselves instead and only let the widgets supply their controls.
-------------------------------------------------------------------------------

-- Control widths, right-aligned inside the column.
local NUM_W, NUM_H   = 46, 20
local CHECK_W        = 24
local SWATCH_W       = 20
local CTRL_PAD       = 10   -- gap between the column's right edge and the control

local function ColLeft(x)  return x end
local function CtrlLeft(x, w) return x + COL_W - w - CTRL_PAD end

-- Left-aligned caption, clipped to whatever room the control leaves.
local function NewLabel(parent, text, x, y, ctrlW)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    -- GameFontHighlight is 12pt, matching the labelFontSize default, so the
    -- captions sit at the same weight as the text inside the controls. The Small
    -- variant is 10pt and read noticeably lighter than everything around it.
    fs:SetFontObject("GameFontHighlight")   -- re-faced by ns.Font via the walk
    fs:SetPoint("LEFT", parent, "TOPLEFT", ColLeft(x), y - ROW_H / 2)
    fs:SetWidth(COL_W - ctrlW - CTRL_PAD - 8)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetText(text)
    return fs
end

-- Integer field.
--
-- scale maps the stored value onto the editor: 100 turns a 0-1 fraction into a
-- readable 0-100 percentage, and -1 flips a stored negative into a positive
-- "reduce by" number. That flip is not cosmetic -- NumericBox:SetMinMaxValues
-- hard errors on a negative minimum (NetEaseGUI-2.0/Widget/NumericBox.lua), so a
-- signed range cannot be edited directly.
local function NewNumber(parent, cfg, x, y)
    NewLabel(parent, cfg.text, x, y, NUM_W)

    local box = ns.GUI:GetClass("NumericBox"):New(parent)
    local scale = cfg.scale or 1
    box:SetSize(NUM_W, NUM_H)
    box:SetPoint("LEFT", parent, "TOPLEFT", CtrlLeft(x, NUM_W), y - ROW_H / 2)
    box:SetMinMaxValues(cfg.min, cfg.max)
    box:SetValueStep(cfg.step or 1)
    box:EnableControl()

    box.Reload = function()
        local v = ns.Get(cfg.key) or 0
        box:SetNumber(math.floor(v * scale + 0.5))
    end
    box:SetCallback("OnValueChanged", function(_, value)
        if box.loading then return end
        ns.Set(cfg.key, scale == 1 and value or (value / scale))
    end)
    return box
end

local function NewCheck(parent, cfg, x, y)
    NewLabel(parent, cfg.text, x, y, CHECK_W)

    local cb = ns.GUI:GetClass("CheckBox"):New(parent)
    cb:SetSize(CHECK_W, CHECK_W)
    cb:SetPoint("LEFT", parent, "TOPLEFT", CtrlLeft(x, CHECK_W), y - ROW_H / 2)
    -- The caption is ours, so the widget's own label stays empty. That also keeps
    -- CheckBox:SetText from widening the hit rect to the right, over the control
    -- in the next column.
    cb:SetText("")
    cb:SetScript("OnClick", function(self)
        ns.Set(cfg.key, self:GetChecked() and true or false)
        if cfg.reload then ns.ShowReloadHint() end
    end)
    cb.Reload = function() cb:SetChecked(ns.Get(cfg.key) and true or false) end
    return cb
end

-- Colour swatch. Uses Blizzard's picker, the only colour UI in the game, and one
-- EllesmereUI's own window packs already skin.
local function NewColor(parent, cfg, x, y)
    NewLabel(parent, cfg.text, x, y, SWATCH_W)

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SWATCH_W, SWATCH_W)
    btn:SetPoint("LEFT", parent, "TOPLEFT", CtrlLeft(x, SWATCH_W), y - ROW_H / 2)

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

-- Group heading: accent caption plus a hairline rule across the page, so the
-- groups actually read as groups. TitleWidget was doing neither -- with its
-- background hidden it was just floating text.
local function NewSection(parent, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject("GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y - 2)
    fs:SetText(text)
    local ar, ag, ab = ns.S.GetAccentColor()
    fs:SetTextColor(ar, ag, ab)

    local rule = ns.Tex(parent, "ARTWORK", 1, 1, 1, 0.12)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y - SECTION_H + 5)
    rule:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, y - SECTION_H + 5)
    return fs
end

-------------------------------------------------------------------------------
--  Layout
-------------------------------------------------------------------------------
local FIELDS = {
    { section = "窗口" },
    { kind = "color",  key = "bgColor",   text = "背景颜色" },
    { kind = "number", key = "bgAlpha",   text = "背景不透明度 %", min = 0, max = 100, scale = 100, step = 5 },
    { kind = "check",  key = "topBar",       text = "标题栏深色条" },
    { kind = "number", key = "topBarShade", text = "标题栏对比 %", min = 0, max = 100, scale = 100, step = 2 },
    { kind = "number", key = "headerShade", text = "表头对比 %", min = 0, max = 100, scale = 100, step = 2 },
    { kind = "check",  key = "roleFilterBar", text = "底部职责过滤", reload = true },
    { kind = "check",  key = "noAutoFilterPopup", text = "打开时不弹过滤面板", reload = true },

    { section = "字号" },
    { kind = "number", key = "listFontSize",  text = "活动列表字号", min = 8, max = 20 },
    { kind = "number", key = "labelFontSize", text = "按钮/选项字号", min = 8, max = 20 },
    { kind = "number", key = "tabFontSize",   text = "标签页字号",   min = 8, max = 20 },
    { kind = "number", key = "fontDelta",     text = "其余文字缩小", min = 0, max = 6, scale = -1 },

    { section = "列表行" },
    { kind = "check",  key = "zebra",       text = "斑马纹" },
    { kind = "number", key = "zebraAlpha",  text = "斑马纹深浅 %",  min = 0, max = 100, scale = 100, step = 2 },
    { kind = "number", key = "hoverAlpha",  text = "悬停亮度 %",    min = 0, max = 100, scale = 100, step = 1 },
    { kind = "check",  key = "selectBar",   text = "选中强调色竖条" },
    { kind = "number", key = "selectAlpha", text = "选中填充 %",    min = 0, max = 100, scale = 100, step = 2 },
    { kind = "number", key = "barWidth",    text = "竖条宽度 px",   min = 1, max = 6 },
    { kind = "check",  key = "skinRows",    text = "列表行皮肤", reload = true },
    { kind = "check",  key = "memberIconScale", text = "成员图标跟随字号" },

    { section = "底部标签页" },
    { kind = "color",  key = "tabColor", text = "标签底板颜色" },
    { kind = "number", key = "tabAlpha", text = "标签不透明度 %", min = 0, max = 100, scale = 100, step = 5 },
}

local Panel, widgets

local function ReloadAll()
    if not widgets then return end
    for i = 1, #widgets do
        local w = widgets[i]
        if w.Reload then
            w.loading = true
            ns.Safe(w.Reload)
            w.loading = nil
        end
    end
end
ns.OnSettingChanged = ReloadAll

function ns.ShowReloadHint()
    if Panel and Panel.ReloadHint then Panel.ReloadHint:Show() end
end

local function Build(parent)
    widgets = {}
    local y = -PAD
    local col, x = 0, PAD

    for i = 1, #FIELDS do
        local cfg = FIELDS[i]
        if cfg.section then
            if col > 0 then y = y - ROW_H end    -- close a half-filled row
            col, x = 0, PAD
            NewSection(parent, cfg.section, y)
            y = y - SECTION_H
        else
            local w
            if cfg.kind == "number" then
                w = NewNumber(parent, cfg, x, y)
            elseif cfg.kind == "check" then
                w = NewCheck(parent, cfg, x, y)
            elseif cfg.kind == "color" then
                w = NewColor(parent, cfg, x, y)
            end
            if w then widgets[#widgets + 1] = w end
            col = col + 1
            if col >= COLS then
                col, x = 0, PAD
                y = y - ROW_H
            else
                x = PAD + col * COL_W
            end
        end
    end
    if col > 0 then y = y - ROW_H end

    local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset:SetSize(110, 22)
    reset:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", PAD, PAD)
    reset:SetText("恢复默认")
    reset:SetScript("OnClick", function()
        ns.ResetAll()
        ns.ShowReloadHint()
    end)

    local reload = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reload:SetSize(110, 22)
    reload:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    reload:SetText("重载界面")
    reload:SetScript("OnClick", ReloadUI)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", reload, "RIGHT", 10, 0)
    hint:SetText("有设置需要重载界面后生效")
    hint:Hide()
    parent.ReloadHint = hint
end

-------------------------------------------------------------------------------
--  Registration
-------------------------------------------------------------------------------
function ns.SetupOptions(MainPanel)
    if not (MainPanel and MainPanel.RegisterPanel) then return end
    if MainPanel:IsPanelRegistered(TAB_NAME) then return end

    Panel = CreateFrame("Frame", nil, MainPanel)
    ns.GUI:Embed(Panel, "Refresh")

    -- After 设置 when it exists, otherwise appended. MeetingStone's own tab is
    -- named 设置 (module 'SettingPanel'), and MeetingStoneEX inserts after it too.
    MainPanel:RegisterPanel(TAB_NAME, Panel, { after = "设置" })

    Build(Panel)
    ReloadAll()

    -- The page is built from NetEaseGUI widgets, so our own dispatcher skins it.
    ns.QueueWalk(Panel)
    Panel:HookScript("OnShow", function(self)
        ReloadAll()
        ns.QueueWalk(self)
    end)
end
