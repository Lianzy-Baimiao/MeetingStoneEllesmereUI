-- Explicit homepage chrome. Do not infer successful painting from another
-- skin's "done/bg" flags. The borrowed SearchBox gets a reversible layer only
-- while MeetingStone owns it; input/menu callbacks and anchors remain native.
local ADDON, ns = ...
local function Allowed(f)
    return f and not (f.IsForbidden and f:IsForbidden())
end
local function Pixel(f)
    local _, height
    if GetPhysicalScreenSize then _, height = GetPhysicalScreenSize() end
    local scale = f.GetEffectiveScale and f:GetEffectiveScale() or 1
    return height and height > 0 and scale > 0 and 768 / height / scale or 1
end
local function Make(f, dropdown)
    local d = ns.D(f)
    if d.browseChrome then return d.browseChrome end
    local s = { hidden = {}, icons = {}, dropdown = dropdown, inputFont = {}, hintFont = {} }
    d.browseChrome = s
    local host = CreateFrame("Frame", nil, f)
    host:SetAllPoints(f)
    host:EnableMouse(false)
    ns.Mark(host)
    s.host = host
    s.fill = ns.Tex(host, "BACKGROUND", .04, .04, .04, 1)
    s.fill:SetAllPoints(host)
    s.edges = {}
    for i = 1, 4 do s.edges[i] = ns.Tex(host, "BORDER", 1, 1, 1, 1) end
    if dropdown then
        local arrow = CreateFrame("Frame", nil, host)
        arrow:EnableMouse(false); arrow:SetSize(12, 10)
        arrow:SetPoint("RIGHT", f, "RIGHT", -7, 0)
        ns.Mark(arrow); s.arrow = arrow
        for i = 1, 2 do
            local t = ns.Tex(arrow, "OVERLAY", .85, .91, .93, 1)
            t:SetSize(7, 2)
            t:SetPoint("CENTER", arrow, "CENTER", i == 1 and -2 or 2, 0)
            t:SetRotation(i == 1 and -math.pi / 4 or math.pi / 4)
        end
    end
    return s
end
local function HideArt(s, region)
    if not region or not region.GetAlpha then return end
    if s.hidden[region] == nil then s.hidden[region] = region:GetAlpha() end
    region:SetAlpha(0)
end
local function FadeTextures(s, keep1, keep2, ...)
    for i = 1, select("#", ...) do
        local r = select(i, ...)
        if r and r.GetObjectType and r:GetObjectType() == "Texture" and r ~= keep1 and r ~= keep2 then
            HideArt(s, r)
        end
    end
end
-- SearchBox belongs to Blizzard outside this page. Snapshot at each borrow,
-- not at addon load, so another skin's later changes are restored accurately.
-- Only font metrics change: leave font objects, colors, insets and text alone.
local function RestoreFont(saved)
    local f = saved.owner
    if not f then return end
    saved.owner = nil
    f:SetFont(saved.path, saved.size, saved.flags)
    ns.D(f).claimed = saved.claimed
end
local function MatchFont(f, saved, path, size, flags)
    if not (Allowed(f) and f.GetFont and f.SetFont and path) then return end
    if saved.owner ~= f then
        RestoreFont(saved)
        local oldPath, oldSize, oldFlags = f:GetFont()
        if not (oldPath and oldSize) then return end
        saved.owner, saved.path, saved.size, saved.flags = f, oldPath, oldSize, oldFlags or ""
        saved.claimed = ns.D(f).claimed
    end
    ns.ClaimFont(f)
    local currentPath, currentSize, currentFlags = f:GetFont()
    if currentPath ~= path or currentSize ~= size or currentFlags ~= flags then
        f:SetFont(path, size, flags)
    end
end
local function MatchMetrics(p, f, s)
    local dd = p.ActivityDropdown
    if not Allowed(dd) then return end
    -- Usually both scales are inherited from BrowsePanel. Use rendered height
    -- even if a separate skin has given one input its own local scale.
    local ds = dd.GetEffectiveScale and dd:GetEffectiveScale() or 1
    local es = f.GetEffectiveScale and f:GetEffectiveScale() or 1
    local ratio = ds > 0 and es > 0 and ds / es or 1
    local height = dd:GetHeight() * ratio
    if height > 0 then
        if not s.borrowed then s.borrowed, s.nativeHeight = f, f:GetHeight() end
        -- SetHeight can fire OnSizeChanged synchronously; equality prevents
        -- recursive rewriting, and the original height is already saved.
        if math.abs(f:GetHeight() - height) > .001 then f:SetHeight(height) end
    end
    local path, flags = ns.S.GetFont()
    path, flags = path or STANDARD_TEXT_FONT, flags or ""
    local size = ns.Get("labelFontSize") * ratio
    MatchFont(f, s.inputFont, path, size, flags)
    if s.hintFont.owner and s.hintFont.owner ~= f.Instructions then RestoreFont(s.hintFont) end
    MatchFont(f.Instructions, s.hintFont, path, size, flags)
end
local function Restore(s)
    if not s then return end
    s.host:Hide()
    for r, alpha in pairs(s.hidden) do r:SetAlpha(alpha); s.hidden[r] = nil end
    for r, alpha in pairs(s.icons) do r:SetAlpha(alpha); s.icons[r] = nil end
    RestoreFont(s.inputFont); RestoreFont(s.hintFont)
    local f, height = s.borrowed, s.nativeHeight
    s.borrowed, s.nativeHeight = nil, nil
    if f and f:GetHeight() ~= height then f:SetHeight(height) end
end
local function Paint(f, s)
    -- Equal frame levels let the input's own text render above BACKGROUND art.
    s.host:SetFrameLevel(f:GetFrameLevel())
    local pixel = Pixel(f)
    for i, edge in ipairs(s.edges) do
        edge:SetColorTexture(.22, .22, .22, 1)
        edge:ClearAllPoints()
        if i <= 2 then
            local point = i == 1 and "TOP" or "BOTTOM"
            edge:SetPoint(point .. "LEFT", s.host, point .. "LEFT", 0, 0)
            edge:SetPoint(point .. "RIGHT", s.host, point .. "RIGHT", 0, 0)
            edge:SetHeight(pixel)
        else
            local point = i == 3 and "LEFT" or "RIGHT"
            edge:SetPoint("TOP" .. point, s.host, "TOP" .. point, 0, 0)
            edge:SetPoint("BOTTOM" .. point, s.host, "BOTTOM" .. point, 0, 0)
            edge:SetWidth(pixel)
        end
    end
    -- Only direct textures: never sweep clear buttons, text, autocomplete or
    -- foreign child frames. Our own fill lives on a child, outside this sweep.
    FadeTextures(s, f.searchIcon, f.SearchIcon, f:GetRegions())
    for _, key in ipairs({ "searchIcon", "SearchIcon" }) do
        local icon = f[key]
        if icon then
            if s.icons[icon] == nil then s.icons[icon] = icon:GetAlpha() end
            icon:SetAlpha(1) -- preserve IsShown; empty-state logic remains native
        end
    end
    if f.NineSlice then HideArt(s, f.NineSlice) end
    if s.dropdown and f.MenuButton then
        FadeTextures(s, nil, nil, f.MenuButton:GetRegions())
        s.arrow:SetFrameLevel(f.MenuButton:GetFrameLevel() + 1)
    end
    local control = s.textOwner or f
    s.host:SetAlpha(control.IsEnabled and not control:IsEnabled() and .45 or 1)
    s.host:Show()
end
local function Refresh(p)
    local active = p:IsVisible()
    local dd = p.ActivityDropdown
    if Allowed(dd) then
        local s = ns.D(dd).browseChrome
        if active and s then Paint(dd, s) elseif s then Restore(s) end
    end
    local eb = p.SearchBox
    if Allowed(eb) then
        local s = ns.D(eb).browseChrome
        if active and eb:GetParent() == p and s then
            MatchMetrics(p, eb, s)
            Paint(eb, s)
        elseif s then Restore(s) end
    end
    if active then ns.Safe(ns.SkinBrowseJoinControls, p) end
end
-- Config/font/theme refreshes also cover the shared edit box, whose font
-- metrics are deliberately not replaced by a permanent skin font object.
function ns.ApplyBrowseInputs()
    local p = ns.Module("BrowsePanel")
    if p then Refresh(p) end
end
local function Deferred(p)
    local d = ns.D(p)
    if d.browseInputPending then return end
    d.browseInputPending = true
    C_Timer.After(0, function()
        d.browseInputPending = nil
        ns.Safe(Refresh, p) -- late OnShow skin callbacks have now finished
    end)
end
function ns.SkinBrowseInputs(p)
    if not p then return end
    local d = ns.D(p)
    if not d.browseInputHooks then
        d.browseInputHooks = true
        p:HookScript("OnHide", function() Refresh(p) end)
    end
    local dd = p.ActivityDropdown
    if Allowed(dd) then
        local s = Make(dd, true)
        ns.Mark(dd)
        if dd.MenuButton then ns.Mark(dd.MenuButton) end
        ns.SetLabelFonts(dd, "labelLeft", "labelLeft", "labelLeftOff")
        if not s.hooks then
            s.hooks = true
            dd:HookScript("OnEnable", function() Refresh(p) end)
            dd:HookScript("OnDisable", function() Refresh(p) end)
            dd:HookScript("OnSizeChanged", function() Refresh(p) end)
        end
    end
    local eb = p.SearchBox
    if Allowed(eb) then
        local s = Make(eb, false)
        -- Mark, but do not reparent, clear focus, rewrite scripts or text.
        ns.Mark(eb)
        if not s.hooks then
            s.hooks = true
            hooksecurefunc(eb, "SetParent", function() Refresh(p); Deferred(p) end)
            eb:HookScript("OnShow", function() Refresh(p); Deferred(p) end)
            eb:HookScript("OnSizeChanged", function() Refresh(p) end)
        end
    end
    Refresh(p)
    Deferred(p)
end

-- Same visual primitive for secondary pages. Ownership and scheduling stay
-- with the caller; borrowed Blizzard inputs must explicitly release on hide or
-- reparent. No input callbacks, text, focus, insets or parent are rewritten.
function ns.SetControlChrome(f, active, dropdown, height, textOwner)
    if not Allowed(f) then return end
    local s = ns.D(f).browseChrome
    if not active then
        if s then Restore(s) end
        return
    end
    s = s or Make(f, dropdown)
    s.textOwner = textOwner
    ns.Mark(f)
    if height and not dropdown then
        if not s.borrowed then s.borrowed, s.nativeHeight = f, f:GetHeight() end
        if math.abs(f:GetHeight() - height) > .001 then f:SetHeight(height) end
    end
    if dropdown then
        if f.MenuButton then ns.Mark(f.MenuButton) end
        ns.SetLabelFonts(f, "labelLeft", "labelLeft", "labelLeftOff")
    else
        local path, flags = ns.S.GetFont()
        -- A multiline field paints the fixed ScrollFrame, not its taller,
        -- scrolling EditBox. Borrow only the inner text's font, never its size.
        local text = textOwner or f
        MatchFont(text, s.inputFont, path or STANDARD_TEXT_FONT, ns.Get("labelFontSize"), flags or "")
        MatchFont(text.Instructions or text.Prompt, s.hintFont, path or STANDARD_TEXT_FONT,
            ns.Get("labelFontSize"), flags or "")
    end
    Paint(f, s)
end
