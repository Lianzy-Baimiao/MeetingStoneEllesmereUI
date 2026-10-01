-- Opt-in WoW font contract: a fresh FontString without a template has no font.
-- Existing fixture widgets represent native controls already initialized by XML.
local Frame=getmetatable(main)
local create, getFont, setFont, setText = Frame.CreateFontString, Frame.GetFont, Frame.SetFont, Frame.SetText
function Frame:CreateFontString(name,layer,template)
    local fs=create(self,name,layer,template)
    fs.fontUnset=not template
    return fs
end
function Frame:GetFont()
    if self.fontUnset and self.kind=='FontString' then return nil,-1,'' end
    return getFont(self)
end
function Frame:SetFont(path,height,flags)
    assert(type(height)=='number' and height>0, 'FontString:SetFont(): Invalid font height ('..tostring(height)..'): height must be > 0')
    setFont(self,path,height,flags); self.fontUnset=nil
    return true
end
function Frame:SetText(text)
    assert(not (self.fontUnset and self.kind=='FontString'), 'FontString:SetText(): Font not set')
    setText(self,text)
end
function Frame:IsObjectType(kind) return self.kind==kind end
