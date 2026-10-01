-- Homepage join toggles: two-row layout and a read-only specialization-role label.
-- Never change selected roles, quick-join settings or the ApplyToGroup path.
local ADDON, ns = ...
local roles = { TANK = "防御", HEALER = "治疗", DAMAGER = "输出" }
local watcher
local function IsCheckbox(f, p)
    return f and f:GetParent() == p and f.GetChecked and f.SetChecked and f.GetText
        and f.GetObjectType and f:GetObjectType() == "CheckButton"
        and not (f.IsForbidden and f:IsForbidden())
end
local function Find(p, s, ...)
    for i = 1, select("#", ...) do
        local f = select(i, ...)
        if IsCheckbox(f, p) then
            local text = f:GetText()
            if text == "双击加入(专精职责)" or text == "双击加入（专精职责）" then s.quick = f
            elseif text == "自动进组" then s.auto = f end
        end
    end
end
local function SpecializationRole()
    -- Same source as MeetingStone's native OnItemDoubleClick / ApplyToGroup.
    local spec = GetSpecialization()
    if not spec then return end
    return select(5, GetSpecializationInfo(spec))
end
local function CurrentRole()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then
        return "专精未就绪"
    end
    local ok, role = pcall(SpecializationRole)
    -- Never fall back to LFG selections, available roles or assigned group role:
    -- none of them describes what the native double-click actually applies as.
    return ok and roles[role] or "专精未就绪"
end
local function UpdateLabel(p)
    if not p or not p:IsVisible() then return end
    local s = ns.D(p).browseJoin
    if not (s and IsCheckbox(s.quick, p)) then return end
    local text = "双击加入（" .. CurrentRole() .. "）"
    if s.quick:GetText() ~= text then s.quick:SetText(text) end
end
local function OnSpecializationChanged(_, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    local p = ns.Module("BrowsePanel")
    if p then ns.Safe(UpdateLabel, p) end
end
local function WatchSpecialization()
    if not watcher then
        watcher = CreateFrame("Frame")
        ns.Mark(watcher)
        watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
        watcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        watcher:SetScript("OnEvent", OnSpecializationChanged)
    end
end
local function Place(cb, input, y)
    cb:ClearAllPoints()
    cb:SetSize(24, 20)
    cb:SetPoint("LEFT", input, "RIGHT", 10, y)
    ns.Mark(cb)
    ns.SetLabelFonts(cb, "labelLeft", "labelLeft", "labelLeftOff")
    -- Recalculate native label click width after font/role changes. The original
    -- CheckBox:SetText owns the expanded hit rectangle and the click handler.
    cb:SetText(cb:GetText())
    ns.SkinSwitch(cb) -- repaint AFTER moving so its physical-pixel snap is valid
end
function ns.SkinBrowseJoinControls(p)
    local input = p and p.SearchBox
    if not (input and input:GetParent() == p and p:IsVisible()) then return end
    local d = ns.D(p)
    local s = d.browseJoin
    if not s then s = {}; d.browseJoin = s end
    if not (IsCheckbox(s.quick, p) and IsCheckbox(s.auto, p)) then
        Find(p, s, p:GetChildren())
    end
    -- These are unnamed locals in the supported MeetingStone build. If only
    -- one is present, leave layout untouched rather than skin an unrelated box.
    if not (IsCheckbox(s.quick, p) and IsCheckbox(s.auto, p)) then return end
    WatchSpecialization()
    UpdateLabel(p)
    -- Previously quick was centered on input and auto was a full row ABOVE it.
    -- Center the TWO-row block instead. Twenty-unit rows keep separate hitboxes
    -- and leave the existing gap above the activity list at the max font size.
    Place(s.auto, input, 10)
    Place(s.quick, input, -10)
    if not s.tooltip then
        s.tooltip = true
        if s.quick.SetTooltip then
            s.quick:SetTooltip("双击加入",
                "双击队伍时，按当前专精对应的职责申请加入。")
        end
    end
end
