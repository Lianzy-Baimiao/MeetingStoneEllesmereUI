-- Native FilterBox constructor/methods and EX callbacks run on these doubles.
local Frame = getmetatable(browse)
for _, key in ipairs({'SetNormalTexture','SetPushedTexture','SetHighlightTexture',
    'SetCheckedTexture','SetDisabledCheckedTexture'}) do Frame[key] = function() end end
function Frame:SetFontString(text) self.Text = text end
function BuildEnv() end
Addon = {}
function Addon:NewClass() return {} end
function Addon:GetClass(kind)
    return {New=function(_, parent)
        local row = CreateFrame('Frame', nil, parent)
        if kind == 'FilterBox' then
            for key, method in pairs(FilterBox) do row[key] = method end
            row:Constructor()
        else
            row.Check = GUI:GetClass('CheckBox'):New(row)
            row.Check:SetScript('OnClick', function() row:Fire('OnChanged') end)
        end
        return row
    end}
end
local getClass = GUI.GetClass
function GUI:GetClass(kind)
    if kind ~= 'NumericBox' then return getClass(self, kind) end
    return {New=function(_, parent)
        local box = CreateFrame('EditBox', nil, parent)
        box.minValue, box.maxValue = 0, 99
        function box:SetNumber(value)
            self:SetText(math.max(self.minValue, math.min(self.maxValue, value)))
        end
        function box:SetText(value)
            self.number = math.max(self.minValue, math.min(self.maxValue, tonumber(value) or 0))
            self.text = tostring(self.number)
            self:Fire('OnValueChanged', self.number)
        end
        function box:SetMinMaxValues(minimum, maximum)
            self.minValue, self.maxValue = minimum, maximum
            self:SetText(self:GetNumber())
        end
        return box
    end}
end
LFG_LIST_MINIMUM_RATING = '最低史诗钥石评分'
GREEN_FONT_COLOR = {r=0,g=1,b=0}
local function copy(t)
    local result = {}; for k,v in pairs(t) do result[k]=type(v)=='table' and copy(v) or v end
    return result
end
C_LFGList = {
    GetAdvancedFilter = function() return copy(savedFilter) end,
    SaveAdvancedFilter = function(value) savedFilter=copy(value); saveCount=saveCount+1 end,
    GetActivityGroupInfo = function(id) return tostring(id) end,
}
function setupRating(value)
    savedFilter = {minimumRating=value,activities={101},needsTank=true,customField='keep'}
    saveCount = 0
    browse.BlzFilterPanel = CreateFrame('Frame', nil, browse)
    browse.BlzFilterPanel.Inset = CreateFrame('Frame', nil, browse.BlzFilterPanel)
    createEXRatingPanel()
    ratingRow = browse.MD[#browse.MD]
    ns.SetupUnifiedFilters(browse)
end
