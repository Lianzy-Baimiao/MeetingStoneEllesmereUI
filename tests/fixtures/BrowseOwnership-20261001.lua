-- Verbatim installed BrowsePanel OnShow/OnHide; offline fixture, not shipped.
function BrowsePanel:OnShow()
    -- self.AutoCompleteFrame:SetParent(self)
    -- self.AutoCompleteFrame:SetFrameLevel(self:GetFrameLevel() + 100)

    self.SearchBox:ClearAllPoints()
    self.SearchBox:SetParent(self)
    self.SearchBox:SetPoint('LEFT', self.ActivityDropdown, 'RIGHT', 20, 0)
    self.SearchBox:SetWidth(220)

end

-- Modification begin
-- Restore EditBox anchor
function BrowsePanel:OnHide()
    self.SearchBox:ClearAllPoints();
    self.SearchBox:SetParent(LFGListFrame.SearchPanel)
    self.SearchBox:SetPoint('TOPLEFT', LFGListFrame.SearchPanel.CategoryName, 'BOTTOMLEFT', 4, -7)
    self.SearchBox:SetWidth(319)
end

