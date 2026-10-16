-- MeetingStoneEX's auto-apply note popup (AutoApplyNote.lua) is built on demand
-- on UIParent, outside every walk. It gets the filter popups' window shell and
-- flat controls. While open it borrows Blizzard's LFGListApplicationDialog
-- Description: that input gets only the reversible chrome layer, released as
-- soon as it goes back. No dialog script, callback or text is replaced.
local ADDON, ns = ...

local function Title(dialog)
    for i = 1, select("#", dialog:GetRegions()) do
        local r = select(i, dialog:GetRegions())
        if r.GetObjectType and r:GetObjectType() == "FontString" then
            local point, relative = r:GetPoint(1)
            if point == "TOP" and relative == dialog then return r end
        end
    end
end

local function Skin(dialog)
    local d = ns.D(dialog)
    if d.autoApplyDialog then return end
    d.autoApplyDialog = true
    if dialog.SetBackdrop then dialog:SetBackdrop(nil) end
    ns.Shell(dialog)
    local title = Title(dialog)
    if title then
        -- Seat the heading inside the shell's 25px title band.
        title:ClearAllPoints()
        title:SetPoint("TOP", dialog, "TOP", 0, -6)
        ns.Font(title, 1, 1, 1)
    end
    ns.FontAll(dialog)
    for _, key in ipairs({ "WithNoteButton", "WithoutNoteButton", "CancelButton" }) do
        local b = dialog[key]
        if b then ns.SkinButton(b); ns.Mark(b) end
    end
    ns.SkinCloseButtons(dialog)
end

local function Sync(dialog)
    if dialog.WaitInput then ns.SetControlChrome(dialog.WaitInput, true) end
    local app = _G.LFGListApplicationDialog
    local desc = app and app.Description
    if not desc then return end
    local active = dialog:IsShown() and desc:GetParent() == dialog
    ns.SetControlChrome(desc, active, false, nil, desc.EditBox)
end

local function Attach(controller)
    local dialog = controller.noteDialog
    if not dialog then return end
    Skin(dialog)
    local d = ns.D(dialog)
    if not d.autoApplyHooks then
        d.autoApplyHooks = true
        -- AutoApplyNote's own OnHide restores the Description first.
        dialog:HookScript("OnShow", function(self) ns.Safe(Sync, self) end)
        dialog:HookScript("OnHide", function(self) ns.Safe(Sync, self) end)
    end
    Sync(dialog)
end

function ns.SetupAutoApplyDialog(p)
    local controller = p and p.AutoApplyController
    if not (controller and type(controller.RequestStart) == "function") then return end
    local d = ns.D(controller)
    if not d.dialogHooked then
        d.dialogHooked = true
        -- The dialog only exists after the first RequestStart.
        hooksecurefunc(controller, "RequestStart", function(self) ns.Safe(Attach, self) end)
    end
    Attach(controller)
end
