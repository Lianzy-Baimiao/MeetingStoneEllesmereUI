-- Presentation-only controls. No replacement buttons, saved state or callbacks.
local ADDON, ns = ...
local switches = setmetatable({}, { __mode = "k" })
local accentHooked

-- Straight-edged track and thumb: one solid rectangle each, no stepped caps.
local function Rectangle(parent, layer)
    return { parent:CreateTexture(nil, layer) }
end
local function Paint(parts, parent, w, h, r, g, b)
    local t = parts[1]
    t:ClearAllPoints()
    t:SetPoint("CENTER", parent, "CENTER", 0, 0)
    t:SetSize(w, h)
    t:SetColorTexture(r, g, b, 1)
end
local function Pixel(cb)
    local scale = cb.GetEffectiveScale and cb:GetEffectiveScale() or 1
    local _, height
    if GetPhysicalScreenSize then _, height = GetPhysicalScreenSize() end
    return height and height > 0 and scale > 0 and 768 / height / scale or 1
end
local function Snap(value, pixel)
    return math.floor(value / pixel + .5) * pixel
end
local function InSelectionList(cb)
    local parent = cb:GetParent()
    for i = 1, 8 do
        if not parent then return false end
        if ns.D(parent).selectionList then return true end
        parent = parent.GetParent and parent:GetParent()
    end
    return false
end
local function Update(cb)
    local s = switches[cb]
    if not s then return end
    local wide = cb:GetWidth() >= 28
    local w, h = wide and 28 or 20, wide and 14 or 12
    s.selection = InSelectionList(cb)
    if s.selection then w, h = 16, 16 end
    local pixel = Pixel(cb)
    w, h = Snap(w, pixel), Snap(h, pixel)
    local on = not not cb:GetChecked()
    local enabled = cb:IsEnabled()
    ns.HideStates(cb)
    for _, getter in ipairs({ "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
        local t = cb[getter] and cb[getter](cb)
        if t then t:SetAlpha(0) end
    end
    s.host:SetSize(w, h)
    -- Snap absolute edges, not only dimensions: centered controls can otherwise
    -- land on half a physical pixel at non-default window/UI scales.
    local left, bottom = cb:GetLeft() or 0, cb:GetBottom() or 0
    local x, y = (cb:GetWidth() - w) / 2, (cb:GetHeight() - h) / 2
    s.host:ClearAllPoints()
    s.host:SetPoint("BOTTOMLEFT", cb, "BOTTOMLEFT",
        Snap(left + x, pixel) - left, Snap(bottom + y, pixel) - bottom)
    s.host:SetAlpha(enabled and 1 or .4)
    local ar, ag, ab = ns.GetAccentColor()
    -- Borders never inherit selection colour. Keep switch rails dark too,
    -- so the green/class-coloured selected square remains clearly visible.
    Paint(s.edge, s.host, w, h, .22, .22, .22)
    local r, g, b = .10, .10, .10
    if on then
        if s.selection then r, g, b = ar, ag, ab
        else r, g, b = .18, .18, .18 end
    end
    Paint(s.track, s.host, w - 2 * pixel, h - 2 * pixel, r, g, b)
    s.knob:SetShown(not s.selection)
    if s.selection then
        if not s.tick then
            s.tick = s.host:CreateTexture(nil, "OVERLAY")
            s.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            s.tick:SetAllPoints(s.host)
        end
        s.tick:SetDesaturated(true)
        -- A dark check on light fills, a light check on dark class colours.
        local lightness = .2126 * ar + .7152 * ag + .0722 * ab
        local ink = lightness > .55 and .04 or 1
        s.tick:SetVertexColor(ink, ink, ink, 1)
        s.tick:SetShown(on)
        return
    end
    if s.tick then s.tick:Hide() end
    local size = h - 4 * pixel
    s.knob:SetSize(size, size)
    s.knob:ClearAllPoints()
    s.knob:SetPoint("LEFT", s.host, "LEFT", on and (w - size - 2 * pixel) or 2 * pixel, 0)
    if on then Paint(s.thumb, s.knob, size, size, ar, ag, ab)
    else Paint(s.thumb, s.knob, size, size, .40, .40, .40) end
end
function ns.RefreshSwitches()
    for cb in pairs(switches) do Update(cb) end
end

function ns.SkinSwitch(cb)
    if not cb or not cb.GetChecked or (cb.IsForbidden and cb:IsForbidden()) then return end
    if switches[cb] then Update(cb); return end
    local s = {}
    ns.D(cb).switch = s
    switches[cb] = s
    -- All art is on a mouse-transparent child; original label hit rect survives.
    s.host = CreateFrame("Frame", nil, cb)
    s.host:EnableMouse(false)
    s.host:SetPoint("CENTER", cb, "CENTER", 0, 0)
    s.edge = Rectangle(s.host, "BACKGROUND")
    s.track = Rectangle(s.host, "ARTWORK")
    s.knob = CreateFrame("Frame", nil, s.host)
    s.knob:EnableMouse(false)
    s.thumb = Rectangle(s.knob, "OVERLAY")
    ns.Mark(s.host); ns.Mark(s.knob)
    hooksecurefunc(cb, "SetChecked", Update)
    -- Native Click toggles checked state without calling the Lua SetChecked
    -- method. Hook after its original save/confirmation logic has run.
    for _, event in ipairs({ "OnClick", "OnShow", "OnEnable", "OnDisable", "OnSizeChanged" }) do
        cb:HookScript(event, Update)
    end
    if not accentHooked and ns.S.OnLooksChanged then
        accentHooked = true
        ns.S.OnLooksChanged(ns.RefreshSwitches)
        local watcher = CreateFrame("Frame")
        if watcher.RegisterEvent then
            watcher:RegisterEvent("UI_SCALE_CHANGED")
            watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
            watcher:SetScript("OnEvent", ns.RefreshSwitches)
        end
    end
    Update(cb)
end

-- Unknown raw CheckButtons may be radios, menu ticks or selectable list rows.
-- Match the stock checkbox art rather than turning every CheckButton into a switch.
local checkboxArt
function ns.IsSwitchCheckbox(cb)
    if cb:GetWidth() > 36 or cb:GetHeight() > 36 then return false end
    if not checkboxArt then
        checkboxArt = {}
        local probe = cb:CreateTexture()
        for _, suffix in ipairs({ "Up", "Check" }) do
            probe:SetTexture("Interface\\Buttons\\UI-CheckBox-" .. suffix)
            local id = probe:GetTexture()
            if id then checkboxArt[id] = true end
        end
        probe:Hide()
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetCheckedTexture" }) do
        local t = cb[getter] and cb[getter](cb)
        if t and checkboxArt[t:GetTexture()] then return true end
    end
    return false
end

function ns.SkinDropdown(dd)
    local d = ns.D(dd)
    if d.done then return end
    d.done = true

    ns.S.Dropdown(dd)

    local mb = dd.MenuButton
    if mb then
        ns.HideStates(mb)
        ns.S.FadeRegions(mb)
        -- Claim it: a bare 24x24 texture-only Button is exactly the shape the
        -- close-button heuristic looks for, and S.CloseButton would stamp an X
        -- over the house dropdown arrow.
        ns.Mark(mb)
    end
    -- Dropdown.Text IS the button's label (SetFontString in the constructor), so
    -- it needs a font object, not SetFont.
    ns.SetLabelFonts(dd, "labelLeft", "labelLeft", "labelLeftOff")
end

-- Table row selection is not an on/off preference. Mark the containing view
-- before walking so existing AND lazily pooled small checkboxes use a square.
-- Full-row CheckButtons, radios and menu markers are deliberately untouched.
local function SelectionChildren(frame, depth)
    if depth > 6 or not frame.GetChildren then return end
    for i = 1, select("#", frame:GetChildren()) do
        local child = select(i, frame:GetChildren())
        if child and not (child.IsForbidden and child:IsForbidden()) then
            if child.GetObjectType and child:GetObjectType() == "CheckButton"
                and child:GetWidth() <= 36 and child:GetHeight() <= 36
                and (ns.D(child).switch or ns.IsSwitchCheckbox(child)) then
                ns.SkinSwitch(child)
            end
            SelectionChildren(child, depth + 1)
        end
    end
end
function ns.SkinListSelections(view)
    if not (view and view.GetChildren) then return end
    ns.D(view).selectionList = true
    SelectionChildren(view, 0)
end
