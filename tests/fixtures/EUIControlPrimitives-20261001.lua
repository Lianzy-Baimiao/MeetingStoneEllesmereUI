-- Verbatim installed EUI WindowEngine EditBox / Dropdown functions, 2026-10-01.
-- Offline compatibility fixture only, excluded from release ZIP.
function WSkin.EditBox(eb)
    if not eb or eb:IsForbidden() then return end
    local d = GetFFD(eb)
    if d.bg then return end
    FadeRegions(eb)
    for _, k in ipairs({ "Left", "Right", "Middle", "Mid" }) do
        local r = eb[k]; if r and r.SetAlpha then r:SetAlpha(0) end
    end
    local fill = SolidTex(eb, "BACKGROUND", 0.02, 0.02, 0.02, 1)
    fill:SetAllPoints(eb)
    d.bg = fill
    -- Same border as WSkin.Button (theme defaults).
    AddBorder(eb)
end

function WSkin.Dropdown(dd)
    if not dd or dd:IsForbidden() then return end
    local d = GetFFD(dd)
    if d.skinned then return end
    d.skinned = true
    FadeRegions(dd)
    local name = dd.GetName and dd:GetName()
    if name then
        for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
            local r = _G[name .. suffix]; if r and r.SetAlpha then r:SetAlpha(0) end
        end
    end
    if dd.Background then dd.Background:SetAlpha(0) end
    if dd.Texture then dd.Texture:SetAlpha(0) end
    local fill = SolidTex(dd, "BACKGROUND", Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA)
    fill:SetAllPoints(dd)
    d.bg = fill
    AddBorder(dd, 0.25, 0.25, 0.25, 1)
    -- Slight lighten on hover.
    local hover = SolidTex(dd, "HIGHLIGHT", 1, 1, 1, 0.05)
    hover:SetAllPoints(dd)
    d.hover = hover
    -- Our own arrow on the right (Blizzard's is faded with the rest).
    -- Sized to the atlas's native 62x44 aspect.
    local arrow = dd:CreateTexture(nil, "OVERLAY")
    arrow:SetAtlas("Azerite-PointingArrow")
    arrow:SetSize(14, 10)
    arrow:SetPoint("RIGHT", dd, "RIGHT", -6, 0)
    d.arrow = arrow
    -- Label recolored white; the font itself stays Blizzard's.
    local label = dd.Text or (dd.GetFontString and dd:GetFontString())
    if label then WSkin.White(label) end
end
