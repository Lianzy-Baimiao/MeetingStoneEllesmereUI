-- Original visibility methods, without initialization or live game calls.
function ManagerPanel:SetBlocker(text, showIcon)
    self.FullBlocker:SetText(text, not showIcon)
    self.FullBlocker:SetShown(text)
    if text then
        self:SetApplicantListBlocker(false)
    end
end

function ManagerPanel:SetApplicantListBlocker(text)
    if text and not self.FullBlocker:IsVisible() then
        self.ApplicantListBlocker:SetText(text)
        self.ApplicantListBlocker:Show()
    else
        self.ApplicantListBlocker:Hide()
    end
end
