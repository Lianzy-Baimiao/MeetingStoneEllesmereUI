-- Shared geometry for the two settings tabs. TabPanel's OUTER padding and
-- inset heights matter just as much as coordinates inside a settings page.
local ADDON, ns = ...
local L = { PAD = 12, NAV = 156, GAP = 12, ROW = 52 }
ns.SettingsLayout = L
function L.Place(f, parent, x, y, w, h)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f:SetSize(w, h)
end
function L.Label(parent, text, muted)
    local f = parent:CreateFontString(nil, "OVERLAY", muted and "GameFontHighlightSmall" or "GameFontHighlight")
    f:SetText(text)
    f:SetJustifyH("LEFT")
    f:SetWordWrap(false)
    if muted then ns.Font(f, .58, .63, .67) else ns.Font(f) end
    return f
end
function L.TabArgs(main)
    local opts = { after = "设置", padding = 3 }
    local _, data = main:IsPanelRegistered("设置")
    if type(data) == "table" then
        opts.topHeight, opts.bottomHeight, opts.noInset = data.topHeight, data.bottomHeight, data.noInset
        local panel = data.panel
        if panel and panel.GetPoint then
            -- Registered native page is the authority; preserve custom builds'
            -- panel padding as well as the installed version's 3-unit padding.
            local point, _, _, x = panel:GetPoint(1)
            if point == "TOPLEFT" and type(x) == "number" then opts.padding = x end
        end
    end
    return opts
end
function L.Page(u, panel, footer)
    local width, height = panel:GetWidth(), panel:GetHeight()
    if width < 350 or height < 180 then return end
    local Place, PAD, NAV, GAP = L.Place, L.PAD, L.NAV, L.GAP
    Place(u.host, panel, 0, 0, width, height)
    Place(u.nav, u.host, PAD, PAD, NAV, height - 2 * PAD)
    Place(u.navTitle, u.nav, 12, 12, NAV - 24, 20)
    for i, cat in ipairs(u.categories) do
        Place(cat.button, u.nav, 8, 44 + (i - 1) * 38, NAV - 16, 32)
        cat.mark:SetShown(i == u.selected)
    end
    local x = PAD + NAV + GAP
    local w = width - x - PAD - 24 -- fixed scrollbar gutter
    -- Header, row text and footer share a single left edge.
    Place(u.title, u.host, x + 12, PAD, w - 24, 22)
    Place(u.subtitle, u.host, x + 12, 38, w - 24, 16)
    Place(u.scroll, u.host, x, 66, w, height - 108)
    Place(footer, u.host, x + 12, height - 30, w - 24, 18)
    u.content:SetWidth(w)
    return w, height
end
function L.Row(row, content, y, w, kind)
    local Place = L.Place
    Place(row.frame, content, 0, y, w, L.ROW)
    -- A stable control column across both pages, irrespective of row type.
    Place(row.label, row.frame, 12, 8, w - 196, 18)
    Place(row.hint, row.frame, 12, 29, w - 196, 15)
    if row.widget then
        row.widget:SetWidth(152)
        Place(row.widget.frame, row.frame, w - 168, 14, 152, 24)
    elseif kind == "number" then
        Place(row.control, row.frame, w - 112, 15, 72, 22)
        if row.unit then Place(row.unit, row.frame, w - 32, 17, 16, 18) end
    elseif kind == "action" then
        Place(row.control, row.frame, w - 132, 13, 116, 26)
    else
        Place(row.control, row.frame, w - 48, 15, 32, 22)
    end
    -- Moving an anchor without resizing does not fire OnSizeChanged in WoW.
    if ns.D(row.control).switch then ns.SkinSwitch(row.control) end
end
