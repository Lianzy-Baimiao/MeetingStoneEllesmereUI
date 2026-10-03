-- Verbatim installed BrowsePanel cancel callback; offline fixture.
local ActivityList = browse.ActivityList
        ActivityList:SetCallback('OnItemDecline', function(_, _, activity)
            C_LFGList.CancelApplication(activity:GetID())
        end)
