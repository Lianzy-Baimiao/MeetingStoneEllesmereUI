-- Extracted unchanged from installed MeetingStoneEX, offline test only.
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
    
    function roleFunc(box)
        local value = box.Check:GetChecked()
        local key = box.dataValue
        enabled[key] = value        
        saveAdvFilter()
    end  
