-- Optional (default off): hide browse results whose 说明 column shows the
-- voice-chat icon, which mostly marks studio groups. Wraps the list's one
-- registered predicate, so MeetingStone/EX filtering, counts and auto-apply
-- (which walks the same filtered list) keep working; the player's own
-- listing and groups with a live application are never hidden.
local ADDON, ns = ...
local issecretvalue = issecretvalue or function() return false end

-- Same condition as SummaryGrid's icon: Activity:GetVoiceChat() is set.
local function HasVoice(activity)
    local ok, voice = pcall(activity.GetVoiceChat, activity)
    if not ok or voice == nil or issecretvalue(voice) then return false end
    return type(voice) == "string" and voice ~= ""
end

local function Keep(activity)
    local function is(method)
        local fn = activity[method]
        return type(fn) == "function" and fn(activity)
    end
    return is("IsSelf") or (is("IsApplication") and not is("IsApplicationFinished"))
end

local function Install(list)
    local d = ns.D(list)
    if list.filter == d.voiceFilter and d.voiceFilter then return end
    d.voiceBase = list.filter
    d.voiceFilter = function(activity, ...)
        if ns.Get("hideVoiceGroups") and HasVoice(activity) and not Keep(activity) then
            return false
        end
        local base = d.voiceBase
        if base then return base(activity, ...) end
        return true
    end
    list.filter = d.voiceFilter
end

function ns.SetupVoiceFilter(p)
    local list = p and p.ActivityList
    if not (list and type(list.UpdateFilter) == "function") then return end
    local d = ns.D(list)
    if not d.voiceHooked and type(list.RegisterFilter) == "function" then
        d.voiceHooked = true
        -- A later RegisterFilter replaces the predicate; wrap the new one.
        hooksecurefunc(list, "RegisterFilter", function(self) ns.Safe(Install, self) end)
    end
    Install(list)
end

function ns.ApplyVoiceFilter()
    local p = ns.Module("BrowsePanel")
    local list = p and p.ActivityList
    if not (list and type(list.UpdateFilter) == "function") then return end
    ns.SetupVoiceFilter(p)
    list:UpdateFilter()
    if type(list.Refresh) == "function" then list:Refresh() end
end
