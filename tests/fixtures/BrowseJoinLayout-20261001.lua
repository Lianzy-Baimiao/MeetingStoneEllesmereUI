-- Installed BrowsePanel's checkbox geometry/text, isolated from login, chat,
-- portal/auto-invite side effects. Callback doubles are installed by the test.
return function(p)
    local quick = GUI:GetClass('CheckBox'):New(p)
    quick:SetPoint('LEFT', LFGListFrame.SearchPanel.SearchBox, 'RIGHT', 10, 0)
    quick:SetText('双击加入(专精职责)')
    quick:SetSize(24, 24)
    local auto = GUI:GetClass('CheckBox'):New(p)
    auto:SetPoint('TOPLEFT', quick, 'TOPLEFT', 0, 24)
    auto:SetText('自动进组')
    auto:SetSize(24, 24)
    return quick, auto
end
