-- Installed EUI WindowEngine WSkin.Font verbatim; test-only dependencies are injected.
function WSkin.Font(fs, r, g, b)
    if not fs or not fs.GetFont or (fs.IsForbidden and fs:IsForbidden()) then return end
    local _, size = fs:GetFont()
    if size and issecretvalue(size) then return end
    -- 12.0.7: shadows only render from a FontObject, never from instance
    -- SetShadowOffset. Prime BEFORE SetFont (SetFont then restores the face).
    EUI.PrimeFontShadow(fs, Theme.fontShadow)
    fs:SetFont(Theme.fontPath, size or 12, Theme.fontFlag or "")
    if r then fs:SetTextColor(r, g, b or r) end
end
