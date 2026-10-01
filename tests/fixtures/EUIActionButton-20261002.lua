-- Verbatim installed EUI action button functions; offline fixture.
local function ApplyButton(btn, d, keepKeys)
    local keep = {}
    if d.bg then keep[d.bg] = true end
    if d.hover then keep[d.hover] = true end
    if keepKeys then
        for _, k in ipairs(keepKeys) do
            local r = btn[k]; if r then keep[r] = true end
        end
    end
    FadeRegions(btn, keep)
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local fn = btn[getter]
        local t = fn and fn(btn)
        if t and not keep[t] then t:SetAlpha(0) end
    end
    for _, k in ipairs({ "Left", "Middle", "Right", "LeftSeparator", "RightSeparator" }) do
        local r = btn[k]; if r and not keep[r] and r.SetAlpha then r:SetAlpha(0) end
    end

    local fill = d.bg
    if not fill then
        fill = btn:CreateTexture(nil, "BACKGROUND")
        d.bg = fill
    end
    fill:SetColorTexture(Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA)
    fill:SetAllPoints(btn)
    AddBorder(btn)

    local hover = d.hover
    if not hover then
        hover = btn:CreateTexture(nil, "HIGHLIGHT")
        d.hover = hover
    end
    hover:SetColorTexture(1, 1, 1, 0.1)
    hover:SetAllPoints(btn)

    -- Label font stays Blizzard's (color-only text policy).
    Register(btn, keep)
end

function WSkin.Button(btn, keepKeys)
    if not btn or btn:IsForbidden() then return end
    WSkin.CompleteSetup(btn, "skinned", ApplyButton, keepKeys)
end

-- Force a button's label white (color only, font untouched). Many action
-- buttons render their enabled text in Blizzard gold; this is opt-in per call
-- (WSkin.Button leaves labels alone). Buttons re-apply their font object when
-- re-enabled, so re-white on every OnEnable as well as now.
function WSkin.WhiteButtonLabel(btn)
    if not btn or (btn.IsForbidden and btn:IsForbidden()) then return end
    local lab = btn.Text or (btn.GetFontString and btn:GetFontString())
    if not lab then return end
    WSkin.White(lab)
    local d = GetFFD(btn)
    if not d.whiteHook then
        d.whiteHook = true
        if btn.HookScript then btn:HookScript("OnEnable", function() WSkin.White(lab) end) end
    end
end

-- Like WhiteButtonLabel, but the label mirrors the native enabled/disabled states:
-- white when clickable, gray when not (a plain white label leaves a disabled button
-- reading as active, since our color write overrides the disabled-font gray).
function WSkin.StateButtonLabel(btn)
    if not btn or (btn.IsForbidden and btn:IsForbidden()) then return end
    local lab = btn.Text or (btn.GetFontString and btn:GetFontString())
    if not lab then return end
    local d = GetFFD(btn)
    if d.stateHook then return end
    d.stateHook = true
    local function reflect()
        if btn:IsEnabled() then WSkin.White(lab) else lab:SetTextColor(0.5, 0.5, 0.5) end
    end
    if btn.HookScript then
        btn:HookScript("OnEnable", reflect)
        btn:HookScript("OnDisable", reflect)
    end
    reflect()
end

