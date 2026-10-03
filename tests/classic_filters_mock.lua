-- Only WoW/class plumbing is mocked; upstream constructors/callbacks are real.
local Frame = getmetatable(browse)
for _, key in ipairs({'SetNormalTexture','SetPushedTexture','SetHighlightTexture',
    'SetCheckedTexture','SetDisabledCheckedTexture'}) do Frame[key] = function() end end
function Frame:SetFontString(text) self.Text = text end
local create = CreateFrame
function CreateFrame(kind, name, parent, template)
    local f = create(kind, name, parent)
    if template == 'SimplePanelTemplate' then f.Inset = create('Frame', nil, f) end
    return f
end
Addon = {}
function Addon:GetClass(kind)
    assert(kind == 'CheckBox')
    return {New=function(_, parent)
        local row = CreateFrame('Frame', nil, parent)
        for key, method in pairs(CheckBox) do row[key] = method end
        row:Constructor()
        return row
    end}
end
format = string.format
RAID_CLASS_COLORS = {}
MEETINGSTONE_UI_DB = {ClassNeed=true, FILTER_TANK=true}
function GetNumClasses() return 13 end
function GetClassInfo(id) return 'Class '..id, 'CLASS'..id, id end
C_LFGList = {
    GetActivityGroupInfo=function(id) return 'Dungeon '..id end,
    SaveAdvancedFilter=function() error('classic must not save Blizzard advanced filters') end,
    GetAdvancedFilter=function() error('classic must not read Blizzard advanced filters') end,
}
function browse.ActivityList:GetFrameLevel() return 1 end
for _, key in ipairs({'BlzFilterPanel','ExFilterPanel','ExSearchButton'}) do
    browse[key]:Hide(); browse[key] = nil
end
browse.MD = nil
browse.ActivityDropdown:SetCallback('OnSelectChanged', function() end)
function Frame:SetTooltipAnchor() end
function UnitClass() return 'Warrior', 'WARRIOR' end
function setupClassic() browse:EX_INIT() end
-- Classic uses the normal dungeon category, not new UI's synthetic "mplus".
browse.ActivityDropdown:SetItem({value='2-0-0-0', categoryId=2})
