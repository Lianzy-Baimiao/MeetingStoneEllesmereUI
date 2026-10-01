-- Original installed callback; offline only. Private flag supplied by test.
        ActivityList:SetCallback('OnItemDoubleClick', function(_, _, activity)
            if Private_EnableQuickJoin then
                local specId = GetSpecialization()
                local role = select(5, GetSpecializationInfo(specId))
                local damager = role == "DAMAGER";
                local tank = role == "TANK";
                local healer = role == "HEALER";

                local searchResultInfo = C_LFGList.GetSearchResultInfo(activity:GetID())
                -- 太卡了，会获取nil，然后抛异常 by 易安玥
                if searchResultInfo ~= nil then
                    if (damager) then
                        print("已作为DPS申请" .. searchResultInfo.name .. "," .. activity:GetName())
                    end
                    if (tank) then
                        print("已作为坦克申请" .. searchResultInfo.name .. "," .. activity:GetName())
                    end
                    if (healer) then
                        print("已作为治疗申请" .. searchResultInfo.name .. "," .. activity:GetName())
                    end
                end
                C_LFGList.ApplyToGroup(activity:GetID(), tank, healer, damager)
            end
        end)
