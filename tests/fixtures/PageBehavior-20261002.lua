-- Exact upstream method excerpts; no network, database load, or game actions.
local CHECK_COORDS = {
    MULTI_NORMAL  = {0.5, 1,   0,   0.5},
    MULTI_CHECKED = {0,   0.5, 0,   0.5},
    RADIO_NORMAL  = {0.5, 1,   0.5, 1  },
    RADIO_CHECKED = {0,   0.5, 0.5, 1  },
}

function DropMenuItem:SetCheckState(checkable, isNotRadio, checked)
    if checkable then
        if isNotRadio then
            self.CheckBox:SetTexCoord(unpack(CHECK_COORDS[checked and 'MULTI_CHECKED' or 'MULTI_NORMAL']))
        else
            self.CheckBox:SetTexCoord(unpack(CHECK_COORDS[checked and 'RADIO_CHECKED' or 'RADIO_NORMAL']))
        end
        self.Text:SetPoint('LEFT', self.CheckBox, 'RIGHT', 2, 0)
        self.CheckBox:Show()
    else
        self.Text:SetPoint('LEFT')
        self.CheckBox:Hide()
    end
    self:SetChecked(checked)
    self.checkable = checkable or nil
    self.isNotRadio = isNotRadio or nil
end
function DropMenuItem:OnClick()
    self:SetCheckState(self.checkable, self.isNotRadio, self:GetChecked())
    self:FireHandler('OnItemClick')
end
function DropMenu:OnItemClick(button, data)
    if data.notClickable then
        return
    end
    if not data.keepShownOnClick then
        self:Hide()
    end

    local owner = self:GetOwner()
    if type(data.func) == 'function' then
        if data.confirm then
            if data.confirmInput then
                GUI:CallInputDialog(data.confirm, data.func, data.confirmKey, data.confirmDefault, data.confirmMaxBytes, data.confirmInput, owner, data)
            else
                GUI:CallMessageDialog(data.confirm, data.func, data.confirmKey, owner, data)
            end
        else
            data.func(owner, data, self, button:GetChecked())
        end
    end
    if owner then
        if type(owner.SetItem) == 'function' then
            owner:SetItem(data)
        end
    end

    if data.keepShownOnClick then
        self:Refresh()
    end
    if data.refreshParentOnClick and self:GetLevel() > 1 then
        self:RefreshMenu(self:GetLevel() - 1)
    end
end
function RecentPanel:Update()
    if not self.code then
        return
    end

    self.MemberList:SetItemList(Recent:GetRecentList(self.code))
    self.MemberList:Refresh()
end
function RecentPanel:SetActivity(code)
    self.code = code
    self:Refresh()
end
function RecentPanel:LFG_LIST_AVAILABILITY_UPDATE()
    self.ActivityDropdown:SetMenuTable(GetActivitesMenuTable(ACTIVITY_FILTER_OTHER))
end
function Recent:GetRecentList(code)
    local list = {}
    for manager in pairs(self.groupManagers[code]) do
        for _, player in manager:IteratePlayers() do
            tinsert(list, player)
        end
    end
    return list
end

function RecentPanel:BatchDelete()
    for i = 1, self.MemberList:GetItemCount() do
        local player = self.MemberList:GetItem(i)
        if player then
            player:GetManager():RemoveUnit(player)
        end
    end
end
