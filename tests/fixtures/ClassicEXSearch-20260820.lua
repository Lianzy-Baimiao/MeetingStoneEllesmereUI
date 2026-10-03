-- Unchanged classic panel, button, EX_INIT and SwitchPanel functions.
-- Source: meeting-stone_-happy_20260820_classic/MeetingStoneEX/MeetingStoneEX.lua
local BrowsePanel, MainPanel = browse, main
local Dungeons = {396,420,306,382,392,398,139,141}
function BrowsePanel:CreateExSearchPanel()
    -- body
    local ExSearchPanel = CreateFrame('Frame', nil, self, 'SimplePanelTemplate')
	
    do
        GUI:Embed(ExSearchPanel, 'Refresh')
        --by 易安玥 调整筛选框大小
        ExSearchPanel:SetSize(310, 250 + #Dungeons*15)
        ExSearchPanel:SetPoint('TOPLEFT', MainPanel, 'TOPRIGHT', 0, -30)
        ExSearchPanel:SetFrameLevel(self.ActivityList:GetFrameLevel() + 5)
        ExSearchPanel:EnableMouse(true)

        local closeButton = CreateFrame('Button', nil, ExSearchPanel, 'UIPanelCloseButton')
        do
            closeButton:SetPoint('TOPRIGHT', 0, -1)
        end

        local Label = ExSearchPanel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
        do
            Label:SetPoint('TOPLEFT', 5, -10)
            Label:SetText('大秘境-条件过滤')
        end
    end
    self.ExSearchPanel = ExSearchPanel
    ExSearchPanel:SetShown(false)

    local function RefreshExSearch()
        local item = self.ActivityDropdown:GetItem()
        if not self.inUpdateFilters and item and item.categoryId then
            Profile:SetFilters(item.categoryId, self:GetExSearchs())
        end
    end

    self.MD = {}
	
    for i, groupId in ipairs(Dungeons) do
        if not self.MDSearchs then
            self.MDSearchs = {}
        end
        local groupInfo = C_LFGList.GetActivityGroupInfo(groupId)
        local v = groupInfo or ""


        local Box = Addon:GetClass('CheckBox'):New(ExSearchPanel.Inset)
        Box.Check:SetText(v)
        local text = v
        Box:SetCallback('OnChanged', function(box)
            if not self.MDSearchs then
                self.MDSearchs = {}
            end
            self.MDSearchs[groupId] = box.Check:GetChecked()
            if not box.Check:GetChecked() then
                local clear = true
                for k, v2 in pairs(self.MDSearchs) do
                    if v2 then
                        clear = false
                        break
                    end
                end
                if clear then
                    self.MDSearchs = nil
                end
            end
            self.ActivityList:Refresh()
        end)
        Box.dungeonName = v
        if i == 1 then
            Box:SetPoint('TOPLEFT', 10, -10)
            Box:SetPoint('TOPRIGHT', -10, -10)
        else
            Box:SetPoint('TOPLEFT', self.MD[i - 1], 'BOTTOMLEFT')
            Box:SetPoint('TOPRIGHT', self.MD[i - 1], 'BOTTOMRIGHT')
        end

        table.insert(self.MD, Box)
    end


	local function GetClassColoredText(class, text)
		if not class or not text then
			return text
		end
		local color = RAID_CLASS_COLORS[class]
		if color then
			return format('|c%s%s|r', color.colorStr, text)
		end
		return text
	end
	for classID = 1,GetNumClasses() do
		local className, classFile, classID = GetClassInfo(classID)
		local Box = Addon:GetClass('CheckBox'):New(ExSearchPanel.Inset)
		MEETINGSTONE_UI_DB[classFile] = false
        Box.Check:SetText(GetClassColoredText(classFile,className))
		Box:SetSize(90, 20)
		if classID == 1 then
			Box:SetPoint('TOPLEFT', self.MD[#Dungeons + classID - 1], 'BOTTOMLEFT') 
		elseif classID%3 == 1 then	
			Box:SetPoint('TOPLEFT', self.MD[#Dungeons + classID - 3], 'BOTTOMLEFT') 
		else
			Box:SetPoint('TOPLEFT', self.MD[#Dungeons + classID - 1],"TOPRIGHT") 
		end
		Box.Check:SetChecked(MEETINGSTONE_UI_DB[classFile] or false)
		Box:SetCallback('OnChanged', function(box)
            MEETINGSTONE_UI_DB[classFile] = box.Check:GetChecked()
			self.ActivityList:Refresh()
        end)
        table.insert(self.MD, Box)
	end
	local BoxNeed = Addon:GetClass('CheckBox'):New(ExSearchPanel.Inset)
	
	local BoxNotNeed = Addon:GetClass('CheckBox'):New(ExSearchPanel.Inset)
	
        BoxNeed.Check:SetText("需要")
		BoxNeed:SetSize(90, 20)
		BoxNeed:SetPoint('TOPLEFT', self.MD[#Dungeons + GetNumClasses()],"TOPRIGHT") 
		BoxNeed.Check:SetChecked(MEETINGSTONE_UI_DB.ClassNeed or true)
		BoxNeed:SetCallback('OnChanged', function(box)
            MEETINGSTONE_UI_DB.ClassNeed = box.Check:GetChecked()
			if box.Check:GetChecked() == BoxNotNeed.Check:GetChecked() then
				BoxNotNeed.Check:SetChecked( box.Check:GetChecked() == false)
				self.ActivityList:Refresh()
			end 
        end)
        table.insert(self.MD, BoxNeed)
	
        BoxNotNeed.Check:SetText("避开")
		BoxNotNeed:SetSize(90, 20)
		BoxNotNeed:SetPoint('TOPLEFT', BoxNeed,"TOPRIGHT") 
		BoxNotNeed:SetCallback('OnChanged', function(box)
            MEETINGSTONE_UI_DB.ClassNeed = box.Check:GetChecked() == false
			if box.Check:GetChecked() == BoxNeed.Check:GetChecked() then
				BoxNeed.Check:SetChecked( box.Check:GetChecked() == false)
				self.ActivityList:Refresh()
			end 
        end)		
        table.insert(self.MD, BoxNotNeed)
	

    self.MDSearchs = nil
    local ResetFilterButton = CreateFrame('Button', nil, ExSearchPanel, 'UIPanelButtonTemplate')
    do
        ResetFilterButton:SetSize(160, 22)
        ResetFilterButton:SetPoint('BOTTOM', ExSearchPanel, 'BOTTOM', 0, 3)
        ResetFilterButton:SetText('重置')
        ResetFilterButton:SetScript('OnClick', function()
            for i, box in ipairs(self.MD) do
                box:Clear()
            end
			for classID = 1,GetNumClasses() do
				local className, classFile, classID = GetClassInfo(classID)
				MEETINGSTONE_UI_DB[classFile] = false
				MEETINGSTONE_UI_DB.ClassNeed =  true
			end 
			BoxNeed.Check:SetChecked(true)
            self.MDSearchs = nil
			self.ActivityList:Refresh()
        end)
    end
	
	
	
	
	--GetNumClasses()
	--className, classFile, classID = GetClassInfo(classID)
end

local function CreateMemberFilter(self, point, MainPanel, x, text, DB_Name, tooltip)
    if MEETINGSTONE_UI_DB[DB_Name] == nil then
        MEETINGSTONE_UI_DB[DB_Name] = false
    end


    local TCount = GUI:GetClass('CheckBox'):New(self)
    do
        TCount:SetSize(24, 24)
        TCount:SetPoint(point, MainPanel, x, 3)
        TCount:SetText(text)
        TCount:SetChecked(MEETINGSTONE_UI_DB[DB_Name])
        TCount:SetScript('OnClick', function()
            MEETINGSTONE_UI_DB[DB_Name] = not MEETINGSTONE_UI_DB[DB_Name]
            self.ActivityList:Refresh()
        end)
    end
    if tooltip then
        GUI:Embed(TCount, 'Tooltip')
        TCount:SetTooltip("说明", tooltip)
        TCount:SetTooltipAnchor("ANCHOR_BOTTOMRIGHT")
    end
end

local function CreateScoreFilter(self, text, score)
    local DB_Name = 'SCORE'
    if MEETINGSTONE_UI_DB[DB_Name] == nil then
        MEETINGSTONE_UI_DB[DB_Name] = false
    end

    local filterScoreCheckBox = GUI:GetClass('CheckBox'):New(self)
    do
        filterScoreCheckBox:SetSize(24, 24)
        filterScoreCheckBox:SetPoint('TOPLEFT', self.SearchBox, 'TOPLEFT', 0, 26)
        filterScoreCheckBox:SetText(text)
        filterScoreCheckBox:SetChecked(MEETINGSTONE_UI_DB[DB_Name])
        filterScoreCheckBox:SetScript("OnClick", function()
            if MEETINGSTONE_UI_DB[DB_Name] then
                MEETINGSTONE_UI_DB[DB_Name] = nil
            else
                MEETINGSTONE_UI_DB[DB_Name] = score
            end
            self.ActivityList:Refresh()
        end)
        GUI:Embed(filterScoreCheckBox, 'Tooltip')
        filterScoreCheckBox:SetTooltip("说明", "过滤队长是0分的队伍, 可能有助于减少广告")
        filterScoreCheckBox:SetTooltipAnchor("ANCHOR_TOPLEFT")
    end
end

function BrowsePanel:CreateExSearchButton()
    self.RefreshButton:SetPoint('TOPRIGHT', MainPanel, 'TOPRIGHT', -180, -38)
    local ExSearchButton = CreateFrame('Button', nil, self, 'UIMenuButtonStretchTemplate')
    do
        GUI:Embed(ExSearchButton, 'Tooltip')
        ExSearchButton:SetTooltipAnchor('ANCHOR_RIGHT')
        ExSearchButton:SetTooltip('大秘境')
        ExSearchButton:SetSize(83, 31)
        ExSearchButton:SetPoint('LEFT', self.RefreshButton, 'RIGHT', 0, 0)
        ExSearchButton:SetText('大秘境')
        ExSearchButton:SetNormalFontObject('GameFontNormal')
        ExSearchButton:SetHighlightFontObject('GameFontHighlight')
        ExSearchButton:SetDisabledFontObject('GameFontDisable')

        ExSearchButton:SetScript('OnClick', function()
            self:SwitchPanel(self.ExSearchPanel)
        end)
    end
    self.ExSearchButton = ExSearchButton
    self.AdvButton:SetPoint('LEFT', ExSearchButton, 'RIGHT', 0, 0)
    self.AdvButton:SetScript('OnClick', function()
        self:SwitchPanel(self.AdvFilterPanel)
    end)

    CreateMemberFilter(self, 'BOTTOMLEFT', MainPanel, 70, '坦克', 'FILTER_TANK', "隐藏已有坦克职业的队伍，允许多选")
    CreateMemberFilter(self, 'BOTTOMLEFT', MainPanel, 130, '治疗', 'FILTER_HEALTH', "隐藏已有治疗职业的队伍，允许多选")
    CreateMemberFilter(self, 'BOTTOMLEFT', MainPanel, 190, '输出', 'FILTER_DAMAGE', "隐藏输出职业满的队伍，允许多选")
    CreateMemberFilter(self, 'BOTTOMLEFT', MainPanel, 250, '多选-"或"条件', 'FILTER_MULTY',
        '左侧几项多选时，将过滤出同时满足所有条件的队伍\n而多选的同时再勾选本项后，将过滤出满足勾选的任意一项条件的队伍\n一般而言，用于玩家想同时以多个职责加入队伍的时候\n例如战士想查找缺T或DPS的队伍')

    CreateMemberFilter(self, 'BOTTOM', MainPanel, 80, '同职过滤', 'FILTER_JOB',
        "五人副本时，隐藏已有同职责" .. UnitClass("player") .. "的队伍")
    CreateScoreFilter(self, '过滤队长0分队伍', 1)

    CreateMemberFilter(self, 'BOTTOM', MainPanel, 200, '显示屏蔽提示', 'IGNORE_TIPS_LOG',
        "屏蔽了队长或同标题玩家时，聊天框里显示一次提示信息")
end

--添加大秘境过滤功能
function BrowsePanel:EX_INIT()
    self:CreateExSearchPanel()
    self:CreateExSearchButton()
end

function BrowsePanel:SwitchPanel(panel)
    local list = {
        self.ExSearchPanel,
        self.AdvFilterPanel,
    }
    for i, v in ipairs(list) do
        if v == panel then
            v:SetShown(not v:IsShown())
        else
            v:SetShown(false)
        end
    end
end

