--[[----------------------------------------------------------------------------
    MeetingStoneEllesmereUI -- Panels.lua

    Boot, plus the per-module passes for everything the generic dispatcher in
    Widgets.lua cannot identify on its own: the window shell, insets, titles,
    and the handful of buttons whose template gives no usable signature.

    Every module pass is individually pcall'd. If MeetingStone renames a field in
    one panel, that panel goes unskinned and the rest still works.
------------------------------------------------------------------------------]]

local ADDON, ns = ...

-------------------------------------------------------------------------------
--  Small helpers used only by the panel passes.
-------------------------------------------------------------------------------

-- MeetingStone drops unnamed UIPanelCloseButtons onto its popup panels.
--
-- Matched only among a panel's DIRECT children, and only by "Button carrying no
-- label and no button-template art". On these filter popups every other child is
-- either a labelled button or the Inset, so that is unambiguous -- and it has to
-- stay unambiguous, because S.CloseButton clears the art and would erase the
-- glyph off an icon button it mistook for a close box.
local function CloseIn(frame)
    if not (frame and frame.GetChildren) then return end
    for i = 1, select("#", frame:GetChildren()) do
        local c = select(i, frame:GetChildren())
        if c and c.GetObjectType and c:GetObjectType() == "Button"
           and not c.Left and not c.LeftSeparator and not c.Icon then
            local text = c.GetText and c:GetText()
            if not text or text == "" then ns.SkinClose(c) end
        end
    end
end

-- The bottom tab row is anchored 10px in from the window's left edge, which the
-- stock art hid: each tab's slices carry transparent padding, so the visible
-- plate started further right anyway. A flat block has no padding, so that 10px
-- now reads as the tab row being misaligned with the window. Re-seat it flush.
local function AlignTabs(MainPanel)
    local tf = MainPanel and MainPanel.TabFrame
    if not tf then return end
    local d = ns.D(tf)
    if d.aligned then return end
    local point, rel, relPoint, _, y = tf:GetPoint()
    if not (point and relPoint) then return end
    d.aligned = true
    tf:ClearAllPoints()
    tf:SetPoint(point, rel or MainPanel, relPoint, 0, y or 0)
end

-- Labelled buttons on a panel, by field name.
local function Buttons(owner, ...)
    if not owner then return end
    for i = 1, select("#", ...) do
        ns.SkinButton(owner[select(i, ...)])
    end
end

local function Fonts(owner, ...)
    if not owner then return end
    for i = 1, select("#", ...) do
        ns.Font(owner[select(i, ...)])
    end
end

-------------------------------------------------------------------------------
--  Text tweaks and behaviour fixes on MeetingStone's own widgets.
--
--  These are not skinning. They are here because the widgets involved are
--  anonymous locals in MeetingStone / MeetingStoneEX -- unreachable by name -- so
--  the alternative would be editing those addons, which an update would undo.
-------------------------------------------------------------------------------

-- Relabel buttons by their CURRENT text.
--
-- Both targets are `local` anonymous buttons inside BlzFilterPanel and are never
-- stored on a field (MeetingStoneEX.lua:559 and :585), so matching on the label is
-- the only handle available. If MeetingStoneEX ever changes the wording, the match
-- simply misses and the stock label stays -- no error, no wrong button.
local RELABEL = {
    ["搜索更多队伍"] = "搜索队伍",
    ["查看Roll币池"]  = "查看R币池",
}

local function Relabel(frame)
    if not (frame and frame.GetChildren) then return end
    for i = 1, select("#", frame:GetChildren()) do
        local c = select(i, frame:GetChildren())
        if c and c.GetText and c.SetText then
            local want = RELABEL[c:GetText() or ""]
            if want then c:SetText(want) end
        end
    end
end

-- One-click URL buttons.
--
-- MainPanel.lua:328 and :354 call ApplyUrlButton FROM INSIDE the button's own
-- OnClick. ApplyUrlButton (API.lua:535) does not open anything -- it only binds
-- UrlButtonOnClick as the handler. So the first click merely replaces its own
-- handler and shows nothing; the second click finally opens the dialog. Hence
-- MeetingStone's own tooltip saying "不行就多点几下".
--
-- The fix runs the original closure (which rebinds) and then immediately invokes
-- whatever it bound. Deliberately URL-agnostic: JoinQUrlBtn's embedded |Hurl:| text
-- is a DIFFERENT address from the one it actually opens, so reading the URL out of
-- the label and re-binding ourselves would send people to the wrong place.
local function FixUrlButton(btn)
    if not (btn and btn.GetScript) then return end
    local d = ns.D(btn)
    if d.urlFixed then return end
    local orig = btn:GetScript("OnClick")
    if not orig then return end
    d.urlFixed = true
    btn:SetScript("OnClick", function(self, ...)
        orig(self, ...)
        -- orig called SetScript, so our wrapper is already gone; run its result.
        local bound = self:GetScript("OnClick")
        if bound and bound ~= orig then bound(self, ...) end
    end)
end

-------------------------------------------------------------------------------
--  Role filters on the main bar.
--
--  MeetingStoneEX already owns this logic: BlzFilterPanel holds 缺坦克 / 缺治疗 /
--  缺DPS / 已有坦克 / 已有治疗 checkboxes (MeetingStoneEX.lua:543-552), each an
--  Addon:GetClass('CheckBox') carrying a .dataValue key, stored on BrowsePanel.MD.
--
--  So these are PROXIES, not a reimplementation. Toggling one calls Click() on the
--  real checkbox, which runs MeetingStoneEX's own path in full --
--  CheckBox:OnCheckClick -> Fire('OnChanged') -> roleFunc -> enabled[key] +
--  saveAdvFilter(). We never read or write `enabled`, never call saveAdvFilter, and
--  never touch C_LFGList. That matters: filtering that is silently wrong is worse
--  than no shortcut at all, and the only way to guarantee identical behaviour is to
--  go through the same click the popup would.
--
--  EX_INIT creates these controls for every activity type. Their existence is
--  NOT an availability check: these particular filters apply only to mplus.
--  Shortcuts follow the selected activity and the individual controls' shown
--  flags, NOT the popup's visibility. Closing the popup must leave usable
--  shortcuts on the browse panel, without changing upstream filter state.
-------------------------------------------------------------------------------
-- Two groups, because the bottom bar has an obstacle in the middle: BrowsePanel's
-- SignUpButton is anchored ('BOTTOM', MainPanel, 'BOTTOM', 0, 4) at
-- BrowsePanel.lua:407, i.e. dead centre. A single left-to-right run of five boxes
-- reaches x~384 and collides with it, so the 缺* group stays left of the button and
-- the 已有* group starts to its right.
-- Stop a filter popup opening by itself.
--
-- BrowsePanel.lua:454-468 (a "Modification" block, i.e. this fork's own patch, not
-- upstream NetEase code) unconditionally Show()s one of the two MeetingStoneEX
-- filter panels on EVERY activity-type change:
--
--     if data.value == 'mplus' then  BlzFilterPanel:Show()   -- titled 地下城搜索
--     else                           ExFilterPanel:Show()
--
-- and BrowsePanel:LFG_LIST_AVAILABILITY_UPDATE (:981-984) restores the saved type
-- with ActivityDropdown:SetValue(Profile:GetLastSearchCode()) as soon as Blizzard
-- delivers the activity list after login. SetValue fires OnSelectChanged (the
-- previous value is nil, so it is not suppressed), so a popup always opens on
-- login -- 地下城搜索 when the saved type is 大秘境, the other panel otherwise.
-- There is no "was it already open" guard. None of this is ours.
--
-- Hooked on that one method rather than on the panels' OnShow: this is exactly the
-- automatic path and nothing else, so toggling a panel by hand (MeetingStoneEX's
-- ExSearchButton, MeetingStoneEX.lua:325-340) still works normally. AdvFilterPanel
-- is left alone -- it is never auto-shown, and closing it here would shut a panel
-- the user had deliberately opened.
local AUTO_POPUP_KEYS = { "BlzFilterPanel", "ExFilterPanel" }

local function SuppressAutoFilterPopup(p)
    if not ns.Get("noAutoFilterPopup") then return end
    local d = ns.D(p)
    if d.autoPopupHooked then return end
    if type(p.LFG_LIST_AVAILABILITY_UPDATE) ~= "function" then return end
    d.autoPopupHooked = true
    -- Post-hook: MeetingStone has already shown the panel by the time this runs.
    hooksecurefunc(p, "LFG_LIST_AVAILABILITY_UPDATE", function(self)
        for i = 1, #AUTO_POPUP_KEYS do
            local panel = self[AUTO_POPUP_KEYS[i]]
            if panel and panel.Hide then panel:Hide() end
        end
    end)
end

local ROLE_GROUPS = {
    { anchor = "left",  keys = { "needsTank", "needsHealer", "needsDamage" } },
    { anchor = "right", keys = { "hasTank", "hasHealer" } },
}

local ROLE_BAR_X, ROLE_BAR_Y = 72, 4   -- clear of the 图示 legend at x=10..60
local ROLE_GAP = 16

local function IsRoleActivity(p)
    local dropdown = p.ActivityDropdown
    local item = dropdown and dropdown.GetItem and dropdown:GetItem()
    return item and item.value == "mplus"
end

-- Keep the upstream three-second search cooldown. A burst of changes while the
-- refresh button is disabled becomes one search for the latest saved filters.
local function FlushRoleSearch(p)
    local d = ns.D(p)
    if not d.roleSearchPending then return end
    if not IsRoleActivity(p) then
        d.roleSearchPending = nil
        return
    end
    if not p:IsVisible() then return end
    local button = p.RefreshButton
    if button and not button:IsEnabled() then return end
    d.roleSearchPending = nil
    if p.DoSearch then p:DoSearch() end
end

local function RequestRoleSearch(p)
    if not IsRoleActivity(p) then return end
    local d = ns.D(p)
    d.roleSearchPending = true
    local button = p.RefreshButton
    if button and not ns.D(button).roleSearchHooked then
        ns.D(button).roleSearchHooked = true
        button:HookScript("OnEnable", function()
            -- OnRefreshTimer also enables RefreshFilterButton after this event.
            -- Wait until that method has finished before disabling both again.
            C_Timer.After(0, function() FlushRoleSearch(p) end)
        end)
    end
    -- Re-evaluate cached results immediately; search also retrieves teams that
    -- were absent from the previous server-filtered response.
    if p.ActivityList and p.ActivityList.Refresh then p.ActivityList:Refresh() end
    FlushRoleSearch(p)
end

local function UpdateRoleVisibility(p)
    local d = ns.D(p)
    local applicable = IsRoleActivity(p)
    local shown = ns.Get("roleFilterBar") and applicable
    if not applicable then d.roleSearchPending = nil end
    for _, pair in ipairs(d.roleBar or {}) do
        -- IsShown is the control's own flag; IsVisible would also test its
        -- ancestors and incorrectly hide shortcuts when the popup is closed.
        local real, check = pair.real, pair.real.Check
        pair.proxy:SetShown(not not (shown and real:IsShown() and check and check:IsShown()))
    end
end

-- The unified host owns visibility; category changes only switch its contents.
-- Fall back to 1.2.4's exclusivity if a future upstream layout cannot be adopted.
local function SyncActivityFilters(p)
    if not ns.SyncUnifiedFilters(p) and p.AdvFilterPanel and p.AdvFilterPanel:IsShown() then
        for _, key in ipairs(AUTO_POPUP_KEYS) do
            local panel = p[key]
            if panel then panel:Hide() end
        end
    end
    UpdateRoleVisibility(p)
end

local function HookBrowseActivity(p)
    local dropdown = p.ActivityDropdown
    if not dropdown or ns.D(dropdown).activityFiltersHooked then return end
    ns.D(dropdown).activityFiltersHooked = true
    -- Menu clicks call SetItem directly; saved selections call SetValue.
    -- Keep MeetingStone's OnSelectChanged callback and its search logic intact.
    for _, method in ipairs({ "SetItem", "SetValue" }) do
        if type(dropdown[method]) == "function" then
            hooksecurefunc(dropdown, method, function() ns.Safe(SyncActivityFilters, p) end)
        end
    end
end

local function SyncRoleBar(p)
    local bar = ns.D(p).roleBar
    if not bar then return end
    for i = 1, #bar do
        local pair = bar[i]
        if pair.real.Check and pair.proxy then
            pair.proxy:SetChecked(pair.real.Check:GetChecked() and true or false)
        end
    end
end

-- Seat the row. Split out and re-runnable because the proxies are measured by
-- their LABEL width, and the label only gets our font object a frame after
-- creation (the constructor hook defers) -- so the first layout is done on the
-- stock font and has to be redone once ours has landed. Called again on every show.
local function LayoutRoleBar(p)
    local bar = ns.D(p).roleBar
    if not bar then return end
    local host = ns.MainPanel
    if not host then return end

    local prev, prevW, x
    for i = 1, #bar do
        local pair = bar[i]
        local proxy = pair.proxy

        if pair.startsGroup then
            prev, prevW, x = nil, nil, nil
            if pair.rightOfButton and p.SignUpButton then
                prev, prevW = p.SignUpButton, 0
            else
                x = ROLE_BAR_X
            end
        end

        proxy:ClearAllPoints()
        if prev then
            -- Chain off the previous frame's right edge, but step over its label:
            -- a CheckBox frame is only the 20px tick, and SetText hangs the text
            -- outside it to the right.
            proxy:SetPoint("LEFT", prev, "RIGHT", prevW + ROLE_GAP, 0)
        else
            proxy:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", x, ROLE_BAR_Y)
        end

        prev  = proxy
        prevW = (proxy.Text and proxy.Text:GetStringWidth()) or 40
        x = nil
    end
end

-- EX warns about contradictory roles but still saves them. Validate only
-- those known native checkbox clicks BEFORE its OnChanged/save closure runs.
-- No shared GUI hooks, no direct writes to EX/Blizzard saved-filter tables.
local ROLE_OPPOSITE = {
    needsTank = "hasTank", hasTank = "needsTank",
    needsHealer = "hasHealer", hasHealer = "needsHealer",
}
local function GuardRoleConflicts(p)
    if type(p.MD) ~= "table" then return end
    local byKey = {}
    for _, row in ipairs(p.MD) do
        if row.dataValue and row.Check then byKey[row.dataValue] = row.Check end
    end
    for key, opposite in pairs(ROLE_OPPOSITE) do
        local check = byKey[key]
        if check and byKey[opposite] then
            local d = ns.D(check)
            d.roleOpposite = byKey[opposite] -- supports late/rebuilt peer rows
            local original = check:GetScript("OnClick")
            if original and original ~= d.roleGuard then
                d.roleGuard = function(self, ...)
                    if self:GetChecked() and d.roleOpposite:GetChecked() then
                        self:SetChecked(false)
                        local text = (key == "needsTank" or key == "hasTank")
                            and "不能同时选择缺坦克和已有坦克，已取消本次选择。"
                            or "不能同时选择缺治疗和已有治疗，已取消本次选择。"
                        ns.GUI:CallWarningDialog(text, true, nil)
                        return
                    end
                    return original(self, ...)
                end
                check:SetScript("OnClick", d.roleGuard)
            end
        end
    end
end

local function BuildRoleBar(p)
    local d = ns.D(p)
    if d.roleBar then
        SyncRoleBar(p)
        LayoutRoleBar(p)
        UpdateRoleVisibility(p)
        FlushRoleSearch(p)
        return
    end
    if not ns.Get("roleFilterBar") then return end

    local md = p.MD
    if type(md) ~= "table" or #md == 0 then return end   -- EX panel not built yet
    if not ns.MainPanel then return end

    -- Index the real boxes by the key MeetingStoneEX tags them with.
    local real = {}
    for i = 1, #md do
        local b = md[i]
        if b and b.dataValue then real[b.dataValue] = b end
    end

    local bar = {}
    for gi = 1, #ROLE_GROUPS do
        local group = ROLE_GROUPS[gi]
        local first = true
        for ki = 1, #group.keys do
            local key = group.keys[ki]
            local box = real[key]
            if box and box.Check and box.Check.GetText then
                local proxy = ns.GUI:GetClass("CheckBox"):New(p)
                -- Label read off the real widget, so it can never drift out of
                -- sync with whatever MeetingStoneEX calls it.
                proxy:SetText(box.Check:GetText() or key)
                proxy:SetChecked(box.Check:GetChecked() and true or false)
                proxy:SetScript("OnClick", function(self)
                    local rc = box.Check
                    if not (rc and rc.Click) then return end
                    local want = self:GetChecked() and true or false
                    local before = not not rc:GetChecked()
                    if before ~= want then
                        rc:Click()      -- save through MeetingStoneEX's own handler
                        self:SetChecked(not not rc:GetChecked())
                        if before ~= not not rc:GetChecked() then RequestRoleSearch(p) end
                    end
                end)

                -- Keep in step when the popup is the one that changed it. Both
                -- hooks are needed: a native Click() toggles the state internally
                -- without going through the scripted SetChecked, so SetChecked
                -- alone catches only programmatic changes (EX's build and Clear),
                -- and OnClick alone catches only user clicks.
                hooksecurefunc(box.Check, "SetChecked", function(_, on)
                    proxy:SetChecked(on and true or false)
                end)
                box.Check:HookScript("OnClick", function(self)
                    proxy:SetChecked(self:GetChecked() and true or false)
                end)

                -- Observe explicit source-row visibility even while its popup
                -- is hidden (when OnShow/OnHide events alone are insufficient).
                for _, control in ipairs({ box, box.Check }) do
                    if not ns.D(control).roleVisibilityHooked then
                        ns.D(control).roleVisibilityHooked = true
                        for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
                            hooksecurefunc(control, method, function() UpdateRoleVisibility(p) end)
                        end
                    end
                end

                bar[#bar + 1] = {
                    proxy = proxy, real = box,
                    startsGroup = first or nil,
                    rightOfButton = (group.anchor == "right") or nil,
                }
                first = false
            end
        end
    end

    if #bar == 0 then return end
    d.roleBar = bar
    LayoutRoleBar(p)
    UpdateRoleVisibility(p)
end

-- Config refreshes do not rerun the boot passes. Toggle existing proxies live,
-- and lazily create them if the option was off when the window first opened.
function ns.ApplyRoleBar()
    local p = ns.Module("BrowsePanel") or ns.EnvGet("BrowsePanel")
    if p then BuildRoleBar(p) end
end

-- MeetingStone seats all three filter popups against the window's right edge
-- with a couple of pixels of slop that Blizzard's SimplePanelTemplate art used
-- to absorb -- the template's nine-slice carries transparent padding, so the
-- visible edge landed flush anyway:
--
--   AdvFilterPanel  TOPLEFT -> MainPanel TOPRIGHT, (-2, -10)   BrowsePanel.lua:477
--   BlzFilterPanel  TOPLEFT -> MainPanel TOPRIGHT, ( 2, -10)   MeetingStoneEX.lua:387
--   ExFilterPanel   TOPLEFT -> MainPanel TOPRIGHT, ( 2, -10)   MeetingStoneEX.lua:644
--
-- Our backdrop goes edge to edge, so those offsets are now literal: -2 overlaps
-- the window by 2px, +2 leaves a 2px gap, and -10 drops the popup below the
-- window's top. Re-seat flush -- left edge on the window's right edge, tops
-- aligned.
--
-- Bails out if the anchor is not the pair we expect, so a future MeetingStone
-- layout change is left alone rather than dragged somewhere wrong.
local function Reseat(panel)
    local d = ns.D(panel)
    if d.reseated then return end
    local point, rel, relPoint = panel:GetPoint()
    if point ~= "TOPLEFT" or relPoint ~= "TOPRIGHT" or not rel then return end
    d.reseated = true
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", rel, "TOPRIGHT", 0, 0)
end

-- One of MeetingStone's three filter popups (advanced / mythic+ / EX).
--
-- S.Shell rather than S.Panel, so these resolve through the SAME style path as
-- the main window: EllesmereUI picks the backdrop from the user's own window-skin
-- setting, and both surfaces read from it. S.Panel used a fixed flat theme colour
-- instead, which is why the popups sat a shade off the window.
local function FilterPanel(panel)
    if not panel then return end
    ns.Shell(panel)
    ns.Inset(panel.Inset)
    CloseIn(panel)
    Reseat(panel)
    ns.QueueWalk(panel)
end

local FILTER_KEYS = { "AdvFilterPanel", "BlzFilterPanel", "ExFilterPanel", "ExSearchPanel" }

-- MeetingStoneEX builds BlzFilterPanel and ExFilterPanel lazily, so this has to
-- be re-runnable rather than a one-shot at login. Everything inside is guarded.
local function FilterPanels(p)
    for i = 1, #FILTER_KEYS do
        local panel = p[FILTER_KEYS[i]]
        ns.Safe(FilterPanel, panel)
        ns.Safe(Relabel, panel)
    end
end

-- A DataGridView / ListView: headers, scroll bar, and whatever rows exist now.
-- Later rows are covered by the constructor hook and the UpdateItems hook.
local function ListLike(list)
    if not list then return end
    ns.SkinListSelections(list)
    local d = ns.D(list)
    if list.UpdateItems and not d.selectionHook then
        d.selectionHook = true
        hooksecurefunc(list, "UpdateItems", ns.SkinListSelections)
    end
    local headers = list.sortButtons
    if type(headers) == "table" then
        for i = 1, #headers do ns.Safe(ns.SkinSortButton, headers[i]) end
    end
    if list.ScrollBar then ns.Safe(ns.SkinObject, list.ScrollBar) end
    local buttons = list.buttons
    if type(buttons) == "table" then
        for i = 1, #buttons do ns.Safe(ns.SkinObject, buttons[i]) end
    end
end

-- Stamp our logo and version onto the window title, so which build of the skin is
-- loaded is visible at a glance.
--
-- Hooked rather than appended once: MeetingStone re-sets the title from several
-- places, and each of those would drop the suffix. The "already branded" test both
-- keeps it idempotent and terminates the one level of recursion our own SetText
-- inside the hook causes.
local BRAND_MARK = "|cff0cd29fEUI|r"

local function Brand(MainPanel)
    local fs = MainPanel.TitleText
    if not fs then return end

    local version = (C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or ""
    -- Long-bracket string: a texture path is full of backslashes, and in a
    -- "..." string Lua 5.1 silently drops unknown escapes ("\A" -> "A"), which
    -- would collapse the path to InterfaceAddOnsEllesmereUI... and load nothing.
    local LOGO = [[Interface\AddOns\EllesmereUI\media\eg-logo.tga]]
    local suffix = ("  |T%s:14:14|t %s|cff9d9d9d界面美化 %s|r")
        :format(LOGO, BRAND_MARK, version)

    local function Apply()
        local text = fs:GetText() or ""
        if text:find(BRAND_MARK, 1, true) then return end
        fs:SetText(text .. suffix)
    end

    local d = ns.D(fs)
    if not d.branded then
        d.branded = true
        hooksecurefunc(fs, "SetText", Apply)
    end
    Apply()
end

-------------------------------------------------------------------------------
--  MainPanel -- the window itself.
-------------------------------------------------------------------------------
local function Skin_MainPanel(MainPanel)
    if not MainPanel then return end

    -- Full house shell: fades the stone/marble art, lays the themed backdrop and
    -- the EUI window border, and adds the 25px dark title strip. MainPanel sets
    -- topHeight 80 with its title row at the top, so the strip belongs.
    ns.Shell(MainPanel)

    -- The portrait art is NOT reached by the shell's own sweep: NetEasePanel-
    -- Template's OnLoad reparents Portrait and _PortraitFrame onto the
    -- PortraitFrame button, so they are no longer regions of MainPanel.
    --
    -- Do not use Panel:HidePortrait() to do this. It reads self.TopLeftCorner
    -- while the XML parentKey is lowercase 'topLeftCorner'
    -- (NetEaseGUI-2.0/Template/Frame.xml vs Widget/Panel.lua) -- it errors.
    if MainPanel.PortraitFrame then
        ns.S.FadeRegions(MainPanel.PortraitFrame)
        ns.HideStates(MainPanel.PortraitFrame)
    end
    ns.Hide(MainPanel.Portrait, MainPanel.TopBorderBar, MainPanel.LeftBorderBar,
            MainPanel.TopRightCorner, MainPanel.topLeftCorner, MainPanel.TopLeftCorner)

    ns.Inset(MainPanel.Inset)
    ns.SkinClose(MainPanel.CloseButton)
    if MainPanel.TitleText then
        ns.Font(MainPanel.TitleText, 1, 1, 1)
        Brand(MainPanel)
    end

    -- The two title-row url buttons ([更新地址] / [Bug反馈]) are anonymous locals,
    -- identified by the |Hurl:| marker MeetingStone puts in their label.
    for i = 1, select("#", MainPanel:GetChildren()) do
        local c = select(i, MainPanel:GetChildren())
        if c and c.GetText and (c:GetText() or ""):find("|Hurl:", 1, true) then
            FixUrlButton(c)
        end
    end

    -- Title-row icon buttons: drop the metal glow, keep the icon.
    local tb = MainPanel.titleButtons
    if type(tb) == "table" then
        for i = 1, #tb do
            local b = tb[i]
            local hl = b and b.GetHighlightTexture and b:GetHighlightTexture()
            if hl then
                hl:SetColorTexture(1, 1, 1, 0.15)
                hl:SetBlendMode("BLEND")
                hl:SetAlpha(1)
            end
        end
    end

    -- Blockers. The GLUES art collages on the announcement/help screens are
    -- deliberate artwork, so only their controls and text get touched.
    local help = MainPanel.HelpBlocker or (MainPanel.blockers and MainPanel.blockers.HelpBlocker)
    if help then
        ns.Font(help.NewVersion)
        ns.QueueWalk(help)
    end

    -- Re-walk on show: MeetingStone builds tab frames, blocker contents and
    -- several plain frames lazily, on first open.
    local d = ns.D(MainPanel)
    if not d.showHook then
        d.showHook = true
        MainPanel:HookScript("OnShow", function(self)
            ns.QueueWalk(self)
            AlignTabs(self)
            if self.TabFrame then ns.QueueWalk(self.TabFrame) end
        end)
    end
    AlignTabs(MainPanel)
end

-------------------------------------------------------------------------------
--  查找活动 / Browse
-------------------------------------------------------------------------------
local function RefreshBrowseExtras(p)
    GuardRoleConflicts(p)
    FilterPanels(p)
    ns.SetupUnifiedFilters(p)
    HookBrowseActivity(p) -- popup coordination must work with shortcuts disabled
    BuildRoleBar(p)
    SyncActivityFilters(p)
end

local function Skin_BrowsePanel(p)
    if not p then return end
    ns.Safe(ns.SkinBrowseInputs, p)

    Buttons(p, "SignUpButton", "AdvButton", "RefreshButton",
               "ResetFilterButton", "RefreshFilterButton", "ExSearchButton")
    -- The sparkle on the advanced-filter button is MeetingStone's own decoration
    -- and fights the flat block. It is ours to hide (not a Blizzard frame).
    if p.AdvButton and p.AdvButton.Shine then p.AdvButton.Shine:Hide() end

    ns.Safe(RefreshBrowseExtras, p)
    ns.Safe(SuppressAutoFilterPopup, p)

    -- The two MeetingStoneEX popups do not exist yet at login (EX_INIT builds
    -- them on demand), so re-run the pass whenever the panel is shown. Done
    -- synchronously, ahead of the deferred walk, so the filter pass claims those
    -- frames before the walk's generic rules can guess at them.
    local d = ns.D(p)
    if not d.showHook then
        d.showHook = true
        p:HookScript("OnShow", function(self)
            ns.Safe(RefreshBrowseExtras, self)
            ns.Safe(ns.SkinBrowseInputs, self)
            ns.QueueWalk(self)
        end)
    end

    -- EX can initialize while BrowsePanel is already visible, with no OnShow.
    if not d.exInitHooked and type(p.EX_INIT) == "function" then
        d.exInitHooked = true
        hooksecurefunc(p, "EX_INIT", function(self)
            ns.Safe(RefreshBrowseExtras, self)
        end)
    end

    for _, key in ipairs({ "SearchingBlocker", "NoResultBlocker" }) do
        local b = p[key]
        if b then
            ns.Panel(b, { noBorder = true })
            ns.SkinButton(b.Button)
            ns.Font(b.Label)
        end
    end

    Fonts(p, "ActivityTotals", "ActivityLabel")
    ListLike(p.ActivityList)
    if p.AutoCompleteFrame then ns.Safe(ns.SkinMenu, p.AutoCompleteFrame) end
end

-------------------------------------------------------------------------------
--  管理活动 / Manager + Create + Applicant
-------------------------------------------------------------------------------
local function Skin_ManagerPanel(p)
    if not p then return end
    ns.Safe(ns.SkinTablePanel, p, "ManagerPanel")
    ns.SkinButton(p.RefreshButton)
    for _, key in ipairs({ "FullBlocker", "ApplicantListBlocker" }) do
        if p[key] then ns.Safe(ns.SkinCover, p[key]) end
    end
end

local function Skin_CreatePanel(p)
    if not p then return end
    ns.Safe(ns.SkinTablePanel, p, "CreatePanel")

    Buttons(p, "CreateButton", "DisbandButton")
    for _, key in ipairs({ "ActivityType", "GeneralPlaystyle" }) do
        if p[key] then ns.Safe(ns.SkinDropdown, p[key]) end
    end
    for _, key in ipairs({ "ItemLevel", "Score" }) do
        if p[key] then ns.Safe(ns.SkinInputBox, p[key]) end
    end
    for _, key in ipairs({ "PrivateGroup", "CrossFactionGroup" }) do
        if p[key] then ns.Safe(ns.SkinCheck, p[key]) end
    end

    -- The activity artwork behind the info board is the panel's only colour;
    -- knock it back rather than removing it so the shell stays readable.
    local info = p.InfoWidget
    if info and info.Background then info.Background:SetAlpha(0.25) end

    ns.QueueWalk(p)
end

local function Skin_ApplicantPanel(p)
    if not p then return end
    ns.Safe(ns.SkinTablePanel, p, "ApplicantPanel")
    ListLike(p.ApplicantList)
    if p.AutoInvite then ns.Safe(ns.SkinCheck, p.AutoInvite) end
end

-------------------------------------------------------------------------------
--  最近玩友 / Recent
-------------------------------------------------------------------------------
local function Skin_RecentPanel(p)
    if not p then return end
    ns.Safe(ns.SkinTablePanel, p, "RecentPanel")
    for _, key in ipairs({ "ActivityDropdown", "ClassDropdown", "RoleDropdown" }) do
        if p[key] then ns.Safe(ns.SkinDropdown, p[key]) end
    end
    if p.SearchInput then ns.Safe(ns.SkinInputBox, p.SearchInput) end
    ns.SkinButton(p.BatchDeleteButton)
    ListLike(p.MemberList)
    ns.QueueWalk(p)
end

-------------------------------------------------------------------------------
--  设置 / Settings. NativeSettings owns the grouped presentation; the original
--  AceConfig definitions still own storage, dependencies and confirmations.
--  Note the registered module name is 'SettingPanel', not 'OptionPanel'.
-------------------------------------------------------------------------------
local function Skin_SettingPanel(p)
    if not p then return end
    ns.SetupNativeSettings(p)
    ns.QueueWalk(p)
    local d = ns.D(p)
    if not d.showHook then
        d.showHook = true
        p:HookScript("OnShow", function(self)
            ns.SetupNativeSettings(self)
            ns.QueueWalk(self)
        end)
    end
end

-------------------------------------------------------------------------------
--  悬浮小窗 / DataBroker. A LibWindow-embedded Button with its own backdrop.
-------------------------------------------------------------------------------
local function Skin_DataBroker(mod)
    if not mod then return end
    local panel = mod.BrokerPanel
    if not panel then return end
    if panel.SetBackdrop then panel:SetBackdrop(nil) end
    ns.Panel(panel)
    ns.Font(mod.BrokerText)
end

-------------------------------------------------------------------------------
--  QuestPanel. XML-built: two InsetFrameTemplate blocks plus a background image.
-------------------------------------------------------------------------------
local function Skin_QuestPanel(p)
    if not p then return end
    local body = p.Body
    if body then
        ns.Inset(body)
        if body.Bg then body.Bg:SetAlpha(0.15) end
        Buttons(body, "Refresh", "Extern", "Join", "Ranking", "RefreshBtn")
        Fonts(body, "Time", "ScoreLabel", "Label1", "Label2")
    end
    if p.Summary then
        ns.Inset(p.Summary)
        ns.Font(p.Summary.Text)
    end
    ListLike(p.Quests)
    ns.QueueWalk(p)
end

-------------------------------------------------------------------------------
--  MeetingStoneEX -- 屏蔽玩家列表
-------------------------------------------------------------------------------
local function Skin_IgnoreListPanel(p)
    if not p then return end
    ns.Safe(ns.SkinTablePanel, p, "IgnoreListPanel")
    ListLike(p.IgnoreList)
    ns.QueueWalk(p)
end

-------------------------------------------------------------------------------
--  Boot
-------------------------------------------------------------------------------
local PASSES = {
    { "MainPanel",         Skin_MainPanel        },
    { "BrowsePanel",       Skin_BrowsePanel      },
    { "ManagerPanel",      Skin_ManagerPanel     },
    { "CreatePanel",       Skin_CreatePanel      },
    { "ApplicantPanel",    Skin_ApplicantPanel   },
    { "RecentPanel",       Skin_RecentPanel      },
    { "SettingPanel",      Skin_SettingPanel     },
    { "DataBroker",        Skin_DataBroker       },
    { "QuestPanel",        Skin_QuestPanel       },
    { "IgnoreListPanel",   Skin_IgnoreListPanel  },
}

function ns.Boot(S)
    ns.S = S

    -- Resolve MeetingStone lazily: at PLAYER_LOGIN everything is loaded, so a
    -- miss here genuinely means MeetingStone is absent or disabled.
    local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
    ns.GUI   = LibStub and LibStub("NetEaseGUI-2.0", true)
    ns.Class = LibStub and LibStub("LibClass-2.0", true)
    ns.MS    = AceAddon and AceAddon.GetAddon and select(2, pcall(AceAddon.GetAddon, AceAddon, "MeetingStone", true)) or nil
    if not (ns.GUI and ns.Class and ns.MS) then return end

    local Env = LibStub("NetEaseEnv-1.0", true)
    if Env and Env._NSList then
        ns.MSEnv = Env._NSList[ns.MS.baseName or "MeetingStone"]
    end

    -- Shared Blizzard controls stay out of the generic descendant walk.
    -- The homepage SearchBox has its own reversible BrowseInputs layer; never
    -- run generic/frame heuristics over this borrowed control.
    -- EntryCreation fields remain owned by the EUI Group Finder pack.
    local LFG = _G.LFGListFrame
    if LFG then
        local SP, EC = LFG.SearchPanel, LFG.EntryCreation
        if SP then ns.Skip(SP.SearchBox) end
        if EC then
            ns.Skip(EC.Name)
            if EC.Description then ns.Skip(EC.Description.EditBox, EC.Description) end
            if EC.VoiceChat then ns.Skip(EC.VoiceChat.EditBox, EC.VoiceChat) end
        end
    end

    ns.DB()
    ns.BuildDispatch()
    ns.InstallHooks()

    -- Custom elements we draw ourselves do not track accent changes on their own,
    -- and our font objects need re-resolving if the user switches EllesmereUI's
    -- font. Both are shared objects, so one rebuild reaches every tab and cell.
    ns.S.OnLooksChanged(function()
        ns.Safe(ns.RefreshAccents)
        ns.Safe(ns.ApplyTabFont)
        ns.Safe(ns.ApplyListFont)
        ns.Safe(ns.ApplyBrowseInputs)
    end)

    local MainPanel = ns.Module("MainPanel") or ns.EnvGet("MainPanel") or _G.MeetingStoneMainPanel
    ns.MainPanel = MainPanel
    if MainPanel and MainPanel.SetScale and not ns.D(MainPanel).switchScaleHook then
        ns.D(MainPanel).switchScaleHook = true
        hooksecurefunc(MainPanel, "SetScale", function()
            ns.Safe(ns.RefreshSwitches)
            ns.Safe(ns.ApplyBrowseInputs)
        end)
    end

    for i = 1, #PASSES do
        local name, fn = PASSES[i][1], PASSES[i][2]
        local mod = (name == "MainPanel" and MainPanel) or ns.Module(name) or ns.EnvGet(name)
        if mod then ns.Safe(fn, mod) end
    end

    -- PlayerInfoDialog is not an AceAddon module at all -- it only exists in the
    -- namespace table, which is why EnvGet validates what it hands back.
    local dialog = ns.EnvGet("PlayerInfoDialog")
    if dialog then
        ns.Safe(ns.SkinTitlePanel, dialog)
        ns.QueueWalk(dialog)
    end

    -- Our own settings tab. Registered after the module passes so 设置 already
    -- exists for the {after = "设置"} placement, and before the walk so the page's
    -- widgets get skinned in the same sweep as everything else.
    ns.Safe(ns.SetupOptions, MainPanel)

    -- Finally sweep everything that already exists. Anything created after this
    -- point is caught by the constructor and UpdateItems hooks.
    if MainPanel then
        ns.Safe(ns.Walk, MainPanel)
        if MainPanel.TabFrame then ns.Safe(ns.Walk, MainPanel.TabFrame) end
    end
end
