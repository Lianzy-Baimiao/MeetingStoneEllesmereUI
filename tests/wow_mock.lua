-- Minimal WoW/NetEaseGUI contract double. Real addon chunks run unchanged.
-- CheckButton:Click toggles before OnClick; NumericBox fires OnValueChanged.
local Frame = {}
Frame.__index = Frame
frames = {}
local function noop() end
function CreateFrame(kind, name, parent)
    local f = setmetatable({kind=kind, parent=parent, children={}, regions={}, points={},
        scripts={}, hooks={}, callbacks={}, shown=true, enabled=true, width=20, height=20}, Frame)
    frames[#frames+1] = f
    if parent then parent.children[#parent.children+1] = f end
    return f
end
function Frame:GetObjectType() return self.kind end
function Frame:GetParent() return self.parent end
function Frame:SetParent(parent)
    if self.parent then
        for i,c in ipairs(self.parent.children) do if c==self then table.remove(self.parent.children,i); break end end
    end
    self.parent=parent; if parent then table.insert(parent.children,self) end
end
function Frame:SetScrollChild(child) self.scrollChild=child end
function Frame:SetVerticalScroll(v) self.scroll=v end
function Frame:GetVerticalScroll() return self.scroll or 0 end
function Frame:EnableMouse() end
function Frame:EnableMouseWheel() end
function Frame:SetClampedToScreen() end
function Frame:SetTooltip(text) self.tooltip=text end
function Frame:GetChildren() return unpack(self.children) end
function Frame:GetRegions() return unpack(self.regions) end
function Frame:CreateFontString()
    local f = CreateFrame('FontString'); f.parent=self; self.regions[#self.regions+1]=f; return f
end
function Frame:CreateTexture() local f=self:CreateFontString(); f.kind='Texture'; return f end
function Frame:SetSize(w,h)
    local changed=self.width~=w or self.height~=h
    self.width=w; self.height=h
    if changed then self:RunScript('OnSizeChanged',w,h) end
end
function Frame:SetWidth(w) self.width=w end
function Frame:SetHeight(h) self:SetSize(self.width,h) end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetPoint(point, relative, relpoint, x, y)
    if type(relative)=='number' then x,y,relative,relpoint=relative,relpoint,self.parent,point end
    self.points[point]={point,relative or self.parent,relpoint or point,x or 0,y or 0}
end
function Frame:ClearAllPoints() self.points={}; self.allPoints=nil end
function Frame:GetPoint() local _,p=next(self.points); if p then return unpack(p) end end
function Frame:SetAllPoints(f) self:ClearAllPoints(); self:SetPoint('TOPLEFT',f,'TOPLEFT'); self:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT'); self.allPoints=f end
local factors={TOPLEFT={0,1},TOP={.5,1},TOPRIGHT={1,1},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,0},BOTTOM={.5,0},BOTTOMRIGHT={1,0}}
function Frame:Rect()
    if self.allPoints then return self.allPoints:Rect() end
    if self.root then return self.x or 0,self.y or 0,self.width,self.height end
    local _,p=next(self.points)
    if not p then return 0,0,self.width,self.height end
    local r=p[2]; local rx,ry,rw,rh=r:Rect(); local a,b=factors[p[1]],factors[p[3]]
    return rx+rw*b[1]+p[4]-self.width*a[1], ry+rh*b[2]+p[5]-self.height*a[2],self.width,self.height
end
function Frame:GetLeft() local x=self:Rect(); return x end
function Frame:GetRight() local x,_,w=self:Rect(); return x+w end
function Frame:GetTop() local _,y,_,h=self:Rect(); return y+h end
function Frame:GetBottom() local _,y=self:Rect(); return y end
function Frame:SetScript(k,fn) self.scripts[k]=fn end
function Frame:GetScript(k) return self.scripts[k] end
function Frame:HookScript(k,fn) self.hooks[k]=self.hooks[k] or {}; table.insert(self.hooks[k],fn) end
function Frame:RunScript(k,...)
    if self.scripts[k] then self.scripts[k](self,...) end
    for _,fn in ipairs(self.hooks[k] or {}) do fn(self,...) end
end
function Frame:SetShown(v)
    v=not not v; if self.shown==v then return end
    self.shown=v; self:RunScript(v and 'OnShow' or 'OnHide')
end
function Frame:Show() self:SetShown(true) end
function Frame:Hide() self:SetShown(false) end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:IsEnabled() return self.enabled end
function Frame:Enable() self.enabled=true; self:RunScript('OnEnable') end
function Frame:Disable() self.enabled=false; self:RunScript('OnDisable') end
function Frame:SetChecked(v) self.checked=not not v end
function Frame:GetChecked() return self.checked end
function Frame:Click()
    if not self.enabled then return end
    if self.kind=='CheckButton' then self.checked=not self.checked end
    self:RunScript('OnClick')
end
function Frame:SetText(t) self.text=t; if self.Text then self.Text:SetText(t) end end
function Frame:GetText() return self.text or '' end
function Frame:GetStringWidth()
    local _,n=self:GetText():gsub('[\128-\191]',''); return (#self:GetText()-n)*12
end
function Frame:SetNumber(n) self.number=n; self:Fire('OnValueChanged',n) end
function Frame:GetNumber() return self.number or 0 end
function Frame:SetMinMaxValues(a,b) assert(a>=0); self.min=a; self.max=b end
function Frame:SetValueStep(s) self.step=s end
function Frame:SetCallback(k,fn) self.callbacks[k]=fn end
function Frame:Fire(k,...) if self.callbacks[k] then self.callbacks[k](self,...) end end
function Frame:GetItem() return self.item end
function Frame:SetItem(item) self.item=item; self:Fire('OnSelectChanged',item) end
function Frame:SetValue(v) self:SetItem({value=v}) end
function Frame:SetFontObject(font) self.font=font end
function Frame:GetFontString() return self.Text end
for _,k in ipairs({'SetColorTexture','SetTextColor','SetJustifyH','SetWordWrap','EnableControl',
    'SetHitRectInsets','SetFont','SetAlpha','SetBlendMode','SetNormalFontObject',
    'SetHighlightFontObject','SetDisabledFontObject','SetFrameLevel'}) do Frame[k]=noop end
function Frame:GetFrameLevel() return 1 end
function hooksecurefunc(obj,key,hook)
    local original=obj[key]; assert(type(original)=='function',key)
    obj[key]=function(...) local result=original(...); hook(...); return result end
end
C_Timer={pending={}}
function C_Timer.After(_,fn) table.insert(C_Timer.pending,fn) end
function flush()
    local pending=C_Timer.pending; C_Timer.pending={}
    for _,fn in ipairs(pending) do fn() end
end
GUI={}
function GUI:Embed() end
function GUI:GetClass(kind)
    return {New=function(_,parent)
        local f=CreateFrame(kind=='CheckBox' and 'CheckButton' or 'EditBox',nil,parent)
        f.widgetKind=kind
        if kind=='CheckBox' then f.Text=f:CreateFontString(); f.Text:SetPoint('LEFT',f,'RIGHT',2,0) end
        return f
    end}
end
ns={GUI=GUI,S={GetAccentColor=function() return 0,.82,.62 end}}
function ns.D(f) f.data=f.data or {}; return f.data end
function ns.Safe(fn,...) if fn then return fn(...) end end
function ns.Get(k) if settings[k]~=nil then return settings[k] end; return 0 end
function ns.Set(k,v) settings[k]=v; if ns.OnSettingChanged then ns.OnSettingChanged(k) end end
function ns.GetColor() return .1,.1,.1 end
function ns.Tex(p) return p:CreateTexture() end
function ns.ResetAll() settings={}; if ns.OnSettingChanged then ns.OnSettingChanged() end end
for _,k in ipairs({'SkinButton','Font','QueueWalk','Shell','Inset','SkinClose','SkinSortButton','SkinObject'}) do ns[k]=noop end
ReloadUI=noop
settings={roleFilterBar=true,noAutoFilterPopup=false}
main=CreateFrame('Frame'); main.root=true; main:SetSize(922,447); ns.MainPanel=main
browse=CreateFrame('Frame',nil,main)
browse.SignUpButton=CreateFrame('Button',nil,browse); browse.SignUpButton:SetSize(120,22)
browse.SignUpButton:SetPoint('BOTTOM',main,'BOTTOM',0,4)
browse.RefreshButton=CreateFrame('Button',nil,browse); browse.RefreshButton:SetSize(80,31)
browse.RefreshButton:SetPoint('TOPRIGHT',main,'TOPRIGHT',-180,-38)
browse.ExSearchButton=CreateFrame('Button',nil,browse); browse.ExSearchButton:SetSize(83,31)
browse.ExSearchButton:SetPoint('LEFT',browse.RefreshButton,'RIGHT',0,0)
browse.AdvButton=CreateFrame('Button',nil,browse); browse.AdvButton:SetSize(83,31)
browse.AdvButton:SetPoint('LEFT',browse.RefreshButton,'RIGHT',80,0)
browse.ActivityDropdown=CreateFrame('Frame',nil,browse); browse.ActivityDropdown.item={value='mplus',categoryId=2}
browse.BlzFilterPanel=CreateFrame('Frame',nil,browse)
browse.BlzFilterPanel:SetPoint('TOPLEFT',main,'TOPRIGHT',2,-10)
browse.ExFilterPanel=CreateFrame('Frame',nil,browse); browse.ExFilterPanel:Hide()
browse.ExFilterPanel:SetPoint('TOPLEFT',main,'TOPRIGHT',2,-10)
browse.AdvFilterPanel=CreateFrame('Frame',nil,browse); browse.AdvFilterPanel:Hide()
browse.AdvFilterPanel:SetPoint('TOPLEFT',main,'TOPRIGHT',-2,-10)
-- Stock click handlers hide the other popup AFTER showing their own popup.
browse.AdvButton:SetScript('OnClick',function()
    browse.AdvFilterPanel:SetShown(not browse.AdvFilterPanel:IsShown())
    if browse.BlzFilterPanel then browse.BlzFilterPanel:Hide() end
    if browse.ExFilterPanel then browse.ExFilterPanel:Hide() end
end)
browse.ExSearchButton:SetScript('OnClick',function()
    if browse.ActivityDropdown:GetItem().value=='mplus' then
        browse.BlzFilterPanel:SetShown(not browse.BlzFilterPanel:IsShown())
        browse.ExFilterPanel:Hide()
    else
        browse.ExFilterPanel:SetShown(not browse.ExFilterPanel:IsShown())
        browse.BlzFilterPanel:Hide()
    end
    browse.AdvFilterPanel:Hide()
end)
browse.ActivityList={Refresh=function(self) self.refreshes=(self.refreshes or 0)+1 end}
browse.searches=0
browse.filters={}
for _,panel in ipairs({browse.BlzFilterPanel,browse.ExFilterPanel,browse.AdvFilterPanel}) do
    panel.Inset=CreateFrame('Frame',nil,panel)
end
browse.BlzFilterPanel:SetSize(200,430)
browse.ExFilterPanel:SetSize(200,180)
browse.AdvFilterPanel:SetSize(200,360)
for _,key in ipairs({'LeaderScore','ItemLevel','BossKilled','Age','Members'}) do
    local row=CreateFrame('Frame',nil,browse.AdvFilterPanel.Inset); row:SetHeight(60); row.key=key
    row.Check=GUI:GetClass('CheckBox'):New(row)
    row.MinBox=CreateFrame('EditBox',nil,row); row.MaxBox=CreateFrame('EditBox',nil,row)
    function row:Clear() self.MinBox:SetNumber(0); self.MaxBox:SetNumber(0); self.cleared=true end
    table.insert(browse.filters,row)
end
for i=1,5 do local row=CreateFrame('Frame',nil,browse.ExFilterPanel.Inset); row:SetHeight(20); row.Check=GUI:GetClass('CheckBox'):New(row) end
browse.ResetFilterButton=CreateFrame('Button',nil,browse.AdvFilterPanel)
browse.ResetFilterButton:SetText('RESET')
browse.ResetFilterButton:SetScript('OnClick',function() for _,row in ipairs(browse.filters) do row:Clear() end end)
browse.RefreshFilterButton=CreateFrame('Button',nil,browse.AdvFilterPanel)
browse.RefreshFilterButton:SetText('REFRESH')
browse.RefreshFilterButton:SetScript('OnClick',function() browse:DoSearch() end)
browse.savedCategories={}
function browse:UpdateFilters()
    local item=self.ActivityDropdown:GetItem()
    if not item or not item.categoryId then return end
    self.loadedCategory=item.categoryId
    self.filters[1].MinBox:SetNumber(self.savedCategories[item.categoryId] or 0)
end
browse.dungeonApply=CreateFrame('Button',nil,browse.BlzFilterPanel)
browse.dungeonApply:SetText('搜索更多队伍')
browse.dungeonApply:SetScript('OnClick',function(self)
    browse.savedRating=browse.rating; browse.saves=(browse.saves or 0)+1
    self:Disable(); browse:DoSearch(); C_Timer.After(3,function() self:Enable() end)
end)
browse.rollButton=CreateFrame('Button',nil,browse.BlzFilterPanel)
browse.rollButton:SetText('查看Roll币池')
browse.rollButton:SetScript('OnClick',function() browse.rollClicks=(browse.rollClicks or 0)+1 end)
function browse:DoSearch() self.searches=self.searches+1; self.RefreshButton:Disable(); self.RefreshFilterButton:Disable() end
browse.RefreshButton:SetScript('OnClick',function() browse:DoSearch() end)
browse.ActivityDropdown:SetCallback('OnSelectChanged',function(_,data)
    browse.BlzFilterPanel:SetShown(data.value=='mplus'); browse.ExFilterPanel:SetShown(data.value~='mplus')
end)
browse.MD={}
for i,key in ipairs({'needsTank','needsHealer','needsDamage','hasTank','hasHealer'}) do
    local box=CreateFrame('Frame',nil,browse.BlzFilterPanel.Inset); box.dataValue=key; box:SetHeight(20)
    box.Check=GUI:GetClass('CheckBox'):New(box); box.Check:SetText(key)
    -- EX's roleFunc saves the filter, but does not refresh/search the results.
    box.Check:SetScript('OnClick',function() box.saved=box.Check:GetChecked() end)
    table.insert(browse.MD,box)
end
function main:IsPanelRegistered() return self.options~=nil end
function main:RegisterPanel(_,panel)
    self.options=panel; panel.root=true; panel:SetSize(892,321)
end
function browsePass()
    for i=1,30 do
        local name,value=debug.getupvalue(ns.Boot,i)
        if name=='PASSES' then
            for _,pass in ipairs(value) do if pass[1]=='BrowsePanel' then return pass[2](browse) end end
        end
    end
    error('Browse pass not found')
end

function ns.Module(name) if name=='BrowsePanel' then return browse end end
function ns.EnvGet() end

-- Presentation contracts shared by the settings and controls tests.
function Frame:SetEnabled(on) if on then self:Enable() else self:Disable() end end
function Frame:SetLabel(text)
    self.Label=self.Label or self:CreateFontString(); self.Label:SetText(text); self.Label:SetShown(text~='')
end
function Frame:ClearFocus() if self.focused then self.focused=nil; self:RunScript('OnEditFocusLost') end end
function Frame:SetFocus() self.focused=true; self:RunScript('OnEditFocusGained') end
function Frame:SetAlpha(v) self.alpha=v end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:SetColorTexture(...) self.color={...} end
function Frame:SetHitRectInsets(...) self.hitRect={...} end
function Frame:IsForbidden() return false end
function GUI:CallMessageDialog(text,callback) confirmation={text=text,callback=callback} end
function ns.Mark(f) ns.D(f).done=true end
function ns.Accent(tex,alpha) tex:SetColorTexture(0,.82,.62,alpha or 1) end
ns.SetLabelFonts=noop
local states={'Normal','Pushed','Highlight','Disabled','Checked','DisabledChecked'}
for _,state in ipairs(states) do
    Frame['Get'..state..'Texture']=function(self) return self[state..'Texture'] end
end
function ns.HideStates(f)
    for _,state in ipairs(states) do local t=f[state..'Texture']; if t then t:SetAlpha(0) end end
end
function ns.S.FadeRegions(f) for _,r in ipairs(f.regions) do if r.kind=='Texture' then r:SetAlpha(0) end end end
function ns.S.Dropdown(f) f.dropdownPaints=(f.dropdownPaints or 0)+1; ns.S.FadeRegions(f) end
function ns.S.EditBox(f)
    if f.editPainted then return end
    f.editPainted=true; ns.S.FadeRegions(f)
end
function ns.S.OnLooksChanged(fn) looksChanged=fn end

function Frame:SetTexture(path) self.texture=path end
function Frame:GetTexture() return self.texture end
function Frame:SetAtlas(path) self.atlas=path end
function Frame:SetDesaturated(on) self.desaturated=on end
function Frame:SetVertexColor(r,g,b,a) self.vertexColor={r,g,b,a} end

function GUI:CallWarningDialog(text,_,_,callback) warning=text; warningCallback=callback end

function Frame:SetRotation(radians) self.rotation=radians end

-- Font metrics are separate from text/color and shared font identity.
function Frame:GetFont()
    if self.fontPath then return self.fontPath,self.fontSize,self.fontFlags end
    if type(self.font)=='table' then return self.font:GetFont() end
    return 'Fonts/stock.ttf',14,'OUTLINE'
end
function Frame:SetFont(path,size,flags) self.fontPath=path; self.fontSize=size; self.fontFlags=flags or '' end
function Frame:GetFontObject() return self.font end
function Frame:SetNormalFontObject(font) self.normalFont=font; if self.Text then self.Text:SetFontObject(font) end end
function Frame:SetHighlightFontObject(font) self.highlightFont=font end
function Frame:SetDisabledFontObject(font) self.disabledFont=font end
function CreateFont(name) return CreateFrame('Font',name) end
function ns.S.GetFont() return 'Fonts/theme.ttf','' end
function ns.ClaimFont(f) if f then ns.D(f).claimed=true end end

function Frame:RegisterEvent(event) self.events=self.events or {}; self.events[event]=true end
function fireEvent(event,...)
    for _,f in ipairs(frames) do
        if f.events and f.events[event] then f:RunScript('OnEvent',event,...) end
    end
end
