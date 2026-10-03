-- Native EX filter creation/save callbacks, extracted unchanged 2026-10-03.
-- Wrapper supplies the panel; roll-pool UI is outside this fixture.
function createEXRatingPanel()
    local self = browse
    local BlzFilterPanel = self.BlzFilterPanel
    local Dungeons = {101, 102}
    local enabled = C_LFGList.GetAdvancedFilter()
    -- enabled.needsTank = false
    -- enabled.needsHealer = false
    -- enabled.needsDamage = false
    -- enabled.needsMyClass = false
    -- enabled.hasTank = false
    -- enabled.hasHealer = false
    -- enabled.activities = Dungeons
    -- C_LFGList.SaveAdvancedFilter(enabled)
    
    self.MD = {}

    function containsValue(array,value)
        for i,v in ipairs(array) do
            if v == value then
                return true,i
            end
        end
        return false,i        
    end

    
    function saveAdvFilter()
        enabled.difficultyNormal = true
        enabled.difficultyHeroic = true
        enabled.difficultyMythic = true
        enabled.difficultyMythicPlus = true
        enabled.generalPlaystyle1 = true
        enabled.generalPlaystyle2 = true
        enabled.generalPlaystyle3 = true
        enabled.generalPlaystyle4 = true
        -- if enabled.minimumRating == 0 then
        --    enabled.minimumRating = 1
        -- end    
        for i,v in ipairs(enabled.activities) do
            local stats,index = containsValue(Dungeons,v)
            if not stats then
                table.remove(enabled.activities,index)
            end    
        end
        if enabled.needsTank and enabled.hasTank then
             GUI:CallWarningDialog('不能同时选择缺坦克和已有坦克', true, nil)
        end    
        if enabled.needsHealer and enabled.hasHealer then
             GUI:CallWarningDialog('不能同时选择缺治疗和已有治疗', true, nil)
        end      


        C_LFGList.SaveAdvancedFilter(enabled)
    end   
    
    function createCheckBox(index,text,checked,value,cbEvent,cbFunc) 
        local Box = Addon:GetClass('CheckBox'):New(BlzFilterPanel.Inset)

        text = string.gsub(text, "塔扎维什：索·莉亚的宏图", "塔扎维什：宏图")
        text = string.gsub(text, "塔扎维什：琳彩天街", "塔扎维什：天街")
        text = string.gsub(text, "葛拉克朗殞命之地 - 恆龍黎明", "殞命")
        text = string.gsub(text, "姆多茲諾高地 - 恆龍黎明", "高地")
        text = string.gsub(text, "迦拉克隆的陨落 - 永恒黎明", "陨落")
        text = string.gsub(text, "姆诺兹多的崛起 - 永恒黎明", "崛起")

        Box.Check:SetText(text)
        if index <= #Dungeons then
            if checked then
                Box.Check:GetFontString():SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, 1)
            else
                Box.Check:GetFontString():SetTextColor(1, 1, 1, 0.5)    
            end 
        end       
        Box.Check:SetChecked(checked)
        Box.dataValue = value
        Box:SetCallback(cbEvent,cbFunc)
        if index == 1 then
            Box:SetPoint('TOPLEFT', 10, 0)
            Box:SetPoint('TOPRIGHT', -10, 0)
        else
            if index == #Dungeons+1 then
                Box:SetPoint('TOPLEFT', self.MD[index-1], 'BOTTOMLEFT', 0, -10)
                Box:SetPoint('TOPRIGHT', self.MD[index-1], 'BOTTOMRIGHT', 0, -10)
            else
                Box:SetPoint('TOPLEFT', self.MD[index-1], 'BOTTOMLEFT')
                Box:SetPoint('TOPRIGHT', self.MD[index-1], 'BOTTOMRIGHT')  
            end       
        end
        table.insert(self.MD, Box)

        return Box
    end
    function createFilterBox(index,text,min,cbEvent,cbFunc,DB_Name)
        local Box = Addon:GetClass('FilterBox'):New(BlzFilterPanel.Inset)
        Box.Check:SetText(text)
        Box.MinBox:SetText(min)
        Box.MinBox:SetMinMaxValues(min, 9999)
        Box.MaxBox:SetText(9999)
        Box.MaxBox:SetMinMaxValues(9999, 9999)
        Box.Text:Hide()
        Box.MaxBox:Hide()
        Box:SetCallback(cbEvent,cbFunc)
        Box:SetPoint('TOPLEFT', self.MD[index-1], 'BOTTOMLEFT', 0, -10)
        Box:SetPoint('TOPRIGHT', self.MD[index-1], 'BOTTOMRIGHT', 0, -10)    
        table.insert(self.MD, Box)
    end    
    
    function roleFunc(box)
        local value = box.Check:GetChecked()
        local key = box.dataValue
        enabled[key] = value        
        saveAdvFilter()
    end  


    for i, id in ipairs(Dungeons) do
        local name = C_LFGList.GetActivityGroupInfo(id)
        createCheckBox(i,name,#enabled.activities==0 and false or containsValue(enabled.activities,id),id,'OnChanged',function(box)
            local value = box.Check:GetChecked()
            local stats,index = containsValue(enabled.activities,box.dataValue)
            if value then
                if not stats then
                    table.insert(enabled.activities,box.dataValue)
                    box.Check:GetFontString():SetAlpha(1)  
                end
            else
                if stats then
                    table.remove(enabled.activities,index)
                    box.Check:GetFontString():SetAlpha(0.5)  
                end    
            end
            saveAdvFilter()
            --C_Timer.After(1,function()
                --self.ActivityList:Refresh()
            --end) 
        end)        
    end


    --createCheckBox(#self.MD + 1, PLAYER_DIFFICULTY1,enabled.difficultyNormal,"difficultyNormal",'OnChanged', roleFunc)
    --createCheckBox(#self.MD + 1, PLAYER_DIFFICULTY2,enabled.difficultyHeroic,"difficultyHeroic",'OnChanged', roleFunc)
    --createCheckBox(#self.MD + 1, PLAYER_DIFFICULTY6,enabled.difficultyMythic,"difficultyMythic",'OnChanged', roleFunc)
    --createCheckBox(#self.MD + 1, PLAYER_DIFFICULTY_MYTHIC_PLUS,enabled.difficultyMythicPlus,"difficultyMythicPlus",'OnChanged', roleFunc)


    --local availTank, availHealer, availDPS = C_LFGList.GetAvailableRoles();
    --if availTank then 
        createCheckBox(#self.MD + 1, "缺坦克",enabled.needsTank,"needsTank",'OnChanged', roleFunc)--LFG_LIST_NEEDS_TANK
    --end  
    --if availHealer then 
        createCheckBox(#self.MD + 1, "缺治疗",enabled.needsHealer,"needsHealer",'OnChanged',roleFunc)--LFG_LIST_NEEDS_HEALER
    --end  
    --if availDPS then 
        createCheckBox(#self.MD + 1, "缺DPS",enabled.needsDamage,"needsDamage",'OnChanged', roleFunc)--LFG_LIST_NEEDS_DAMAGE
    --end    
    createCheckBox(#self.MD + 1, "已有坦克",enabled.hasTank,"hasTank",'OnChanged', roleFunc)--LFG_LIST_HAS_TANK
    createCheckBox(#self.MD + 1, "已有治疗",enabled.hasHealer,"hasHealer",'OnChanged', roleFunc)--LFG_LIST_HAS_HEALER
    createCheckBox(#self.MD + 1, "过滤同职业",enabled.needsMyClass,"needsMyClass",'OnChanged', roleFunc)--string.format(LFG_LIST_CLASS_AVAILABLE, PlayerUtil.GetClassName())

    createFilterBox(#self.MD + 1, LFG_LIST_MINIMUM_RATING,enabled.minimumRating,'OnChanged',function(box) --
        enabled.minimumRating = box.MinBox:GetNumber()
    end)
     
    local ResetFilterButton = CreateFrame('Button', nil, BlzFilterPanel, 'UIPanelButtonTemplate')
    do
        ResetFilterButton:SetSize(100, 22)
        ResetFilterButton:SetPoint('BOTTOMLEFT', BlzFilterPanel, 'BOTTOMLEFT', 0, 3)
        ResetFilterButton:SetText('搜索更多队伍')
        ResetFilterButton:SetScript('OnClick', function(button)
            saveAdvFilter()
            for i,v in ipairs(self.MD) do
                if i<= #Dungeons then
                    if containsValue(enabled.activities,v.dataValue) then
                        v.Check:GetFontString():SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, 1)
                    else
                        v.Check:GetFontString():SetTextColor(1, 1, 1, 0.5)
                    end
                end    
            end
            --C_LFGList.ClearSearchTextFields()
            --self.ActivityDropdown:SetValue('2-0-0-0')
            button:Disable()
            self:DoSearch()
            C_Timer.After(3,function()
                button:Enable() 
            end)
        end)
    end

end
