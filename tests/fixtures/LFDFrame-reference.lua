-- Reference excerpt; fetched 2026-10-01, not shipped or executed in game.
-- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GroupFinder/Mainline/LFDFrame.lua
-- SHA256 of downloaded full source: c03b26beec8b070c5f5324997b2f6eed09be9f73f94d452aa408a7e7fa8def10
function LFDQueueFrame_SetRoles()
	SetLFGRoles(LFGRole_GetChecked(LFDQueueFrameRoleButtonLeader),
		LFGRole_GetChecked(LFDQueueFrameRoleButtonTank),
		LFGRole_GetChecked(LFDQueueFrameRoleButtonHealer),
		LFGRole_GetChecked(LFDQueueFrameRoleButtonDPS));
end
