-- Exact native dropdown value/menu methods. No widget construction.
local function _GetItem(menuTable, value)
    for i, v in ipairs(menuTable) do
        if v.value == value then
            return v
        end
        if v.menuTable then
            local item = _GetItem(v.menuTable, value)
            if item then
                return item
            end
        end
    end
end

function Dropdown:SetValue(value)
    value = value or self.defaultValue

    if not value then
        self.value = nil
        self.item = nil
        self:SetText(self.defaultText)
    elseif self.menuTable then
        local item = _GetItem(self.menuTable, value)
        if item then
            self:SetItem(item)
        end
    end
end

function Dropdown:GetValue()
    return self.value or self.defaultValue
end

function Dropdown:SetMenuTable(menuTable)
    self.menuTable = menuTable
end

function Dropdown:GetMenuTable()
    return self.menuTable
end

function Dropdown:SetItem(item)
    local noFire = self.value == item.value

    self.value = item.value
    self.item = item

    self:SetText(item.full or item.text)

    if self.DropMenu then
        self.DropMenu:Close()
    end

    if not noFire then
        self:Fire('OnSelectChanged', item)
    end
end

function Dropdown:GetItem()
    return self.item
end

function Dropdown:SetDefaultText(text)
    self.defaultText = text
    self:SetText(text)
end

function Dropdown:SetDefaultValue(value)
    self.defaultValue = value
end

function Dropdown:SetMaxItem(value)
    self.maxItem = value
end

function Dropdown:GetMaxItem()
    return self.maxItem
end
