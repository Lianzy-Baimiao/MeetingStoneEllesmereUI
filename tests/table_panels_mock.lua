-- Original layout dimensions/field names, no login/network/console side effects.
local Frame=getmetatable(main)
-- RegisterPanel is not a new screen-coordinate root. Match normal child panels
-- here without changing the settings-specific shortcut in wow_mock.lua.
function main:RegisterPanel(_,p) p:SetSize(892,321) end
function Frame:SetScale(n) self.scale=n end
function Frame:GetEffectiveScale() return self.scale or (self.parent and self.parent:GetEffectiveScale()) or 1 end
function Frame:RegisterForClicks() end
function Frame:SetFontString(fs) self.Text=fs end
function Frame:SetItemList(list) self.items=list end
function Frame:SetHeaderPoint(...) if self.sortButtons[1] then self.sortButtons[1]:SetPoint(...) end end
for _,state in ipairs({'Normal','Checked','Highlight','DisabledChecked','Pushed'}) do
    Frame['Set'..state..'Texture']=function(self,path)
        local t=self:CreateTexture(); t:SetTexture(path); self[state..'Texture']=t
    end
end
function Frame:InitHeader(headers)
    self.sortButtons={}
    for _,data in ipairs(headers) do
        local h=CreateFrame('Button',nil,self)
        for k,v in pairs(data) do h[k]=v end
        h:SetSize(data.width,19); h:SetText(data.text or data.key)
        self.sortButtons[#self.sortButtons+1]=h
    end
end
function Frame:UpdateItems()
    self.buttons=self.buttons or {}
    for i,data in ipairs(self.items or {}) do
        local row=self.buttons[i]
        if not row then
            row=CreateFrame('CheckButton',nil,self); row:SetSize(self:GetWidth()-16,32)
            self.buttons[i]=row
            local x=0
            for _,h in ipairs(self.sortButtons) do
                local cell=h.class and h.class:New(row) or CreateFrame('Button',nil,row)
                cell.key=h.key; cell:SetPoint('TOPLEFT',row,'TOPLEFT',x,0); cell:SetSize(h.width,32)
                row[h.key]=cell; x=x+h.width-1
            end
        end
        row:SetPoint('TOPLEFT',self,'TOPLEFT',0,-(i-1)*33)
        for _,h in ipairs(self.sortButtons) do
            if h.formatHandler then h.formatHandler(row[h.key],data) end
        end
    end
end
function Frame:Refresh() self.refreshCount=(self.refreshCount or 0)+1; self:UpdateItems() end
for _,key in ipairs({'SetItemHighlightWithoutChecked','SetItemHeight','SetItemSpacing','SetItemClass','SetSelectMode','SetScrollStep'}) do
    Frame[key]=function(self,value) self[key..'Value']=value end
end
local guiGet=GUI.GetClass
function GUI:GetClass(kind)
    if kind=='DataGridView' then
        return {New=function(_,parent)
            local f=CreateFrame('Frame',nil,parent); f:SetSize(890,320)
            f.ScrollBar=CreateFrame('Slider',nil,f); return f
        end}
    end
    return guiGet(self,kind)
end
Addon={}
function Addon:GetClass(kind)
    if kind=='CheckBox' then
        return {New=function(_,parent)
            local cell=CreateFrame('Frame',nil,parent)
            local cb=CreateFrame('CheckButton',nil,cell); cb:SetSize(22,22)
            cb:SetNormalTexture('Interface\\Buttons\\UI-CheckBox-Up')
            cb:SetCheckedTexture('Interface\\Buttons\\UI-CheckBox-Check')
            cell.Check=cb
            cb:SetScript('OnClick',function() cell:Fire('OnChanged') end)
            return cell
        end}
    end
    return {}
end
local function panel(parent) local f=CreateFrame('Frame',nil,parent); f:SetSize(894,340); return f end
ManagerPanel=panel(main); CreatePanel=panel(ManagerPanel); ApplicantPanel=panel(ManagerPanel)
RecentPanel=panel(main); IgnoreListPanel=panel(main)
MainPanel=main; BrowsePanel=browse
local modules={ManagerPanel=ManagerPanel,CreatePanel=CreatePanel,ApplicantPanel=ApplicantPanel,
    RecentPanel=RecentPanel,IgnoreListPanel=IgnoreListPanel,BrowsePanel=browse}
ns.Module=function(name) return modules[name] end
NORMAL_FONT_COLOR={r=1,g=1,b=1}
MEETINGSTONE_UI_DB={IGNORE_LIST={{leader='A',selected=false},{leader='B',selected=false}}}
browse.IgnoreWithLeader={A=true,B=true}; browse.IgnoreLeaderOnly={A=true,B=true}
function makeTable(parent,headers)
    local f=GUI:GetClass('DataGridView'):New(parent); f:InitHeader(headers)
    f:SetItemList({{name='one'}}); f:UpdateItems(); return f
end
function button(parent,text)
    local f=CreateFrame('Button',nil,parent); f:SetSize(120,22); f:SetText(text); return f
end
function titled(parent,text)
    local f=CreateFrame('Frame',nil,parent); f.Text=f:CreateFontString(); f:SetText(text)
    f.Bg=f:CreateTexture(); return f
end
function input(parent,w,h)
    local f=CreateFrame('EditBox',nil,parent); f:SetSize(w,h); f.Left=f:CreateTexture()
    f.Prompt=f:CreateFontString(); f:SetFont('stock',13,'OUTLINE')
    return f
end
function dropdown(parent,w)
    local f=CreateFrame('Button',nil,parent); f:SetSize(w,26)
    f.Stock=f:CreateTexture(); f.MenuButton=CreateFrame('Button',nil,f)
    return f
end
ManagerPanel.RefreshButton=button(ManagerPanel,'刷新')
ManagerPanel.ApplicantListBlocker=panel(ManagerPanel)
ManagerPanel.FullBlocker=panel(ManagerPanel)
CreatePanel:SetSize(169,340)
CreatePanel.CreateWidget=panel(CreatePanel)
CreatePanel.CreateWidget:SetAllPoints(CreatePanel)
local activity=titled(CreatePanel.CreateWidget,'请选择活动属性'); activity:SetSize(169,96)
CreatePanel.ActivityType=dropdown(activity,170)
CreatePanel.GeneralPlaystyle=dropdown(CreatePanel.ActivityType,170)
TitleCard=titled(CreatePanel.CreateWidget,'活动标题'); TitleCard:SetSize(169,56)
SummaryCard=titled(CreatePanel.CreateWidget,'活动说明'); SummaryCard:SetSize(169,90)
VoiceCard=titled(CreatePanel.CreateWidget,''); VoiceCard:SetSize(169,100)
CreatePanel.TitleBox=input(TitleCard,150,26)
-- Real description is a ScrollFrame with a separately sized scrolling child.
-- TitleWidget:SetObject(description,10,10,15,10) yields top=30,bottom=15
-- (the upstream widget uses top for bottom). Model its two-anchor viewport.
Description=CreateFrame('ScrollFrame',nil,SummaryCard)
Description:SetPoint('TOPLEFT',SummaryCard,'TOPLEFT',10,-30)
Description:SetPoint('BOTTOMRIGHT',SummaryCard,'BOTTOMRIGHT',-10,15)
function Description:GetNumPoints() return 2 end
function Description:GetPoint(i)
    return unpack(self.points[i==2 and 'BOTTOMRIGHT' or 'TOPLEFT'])
end
function Description:Rect()
    local top,bottom=self.points.TOPLEFT,self.points.BOTTOMRIGHT
    return top[2]:GetLeft()+top[4], bottom[2]:GetBottom()+bottom[5],
        bottom[2]:GetRight()+bottom[4]-top[2]:GetLeft()-top[4],
        top[2]:GetTop()+top[5]-bottom[2]:GetBottom()-bottom[5]
end
function Description:GetHeight() local _,_,_,h=self:Rect(); return h end
function Description:GetWidth() local _,_,w=self:Rect(); return w end
CreatePanel.SummaryBox=input(Description,150,60)
Description.EditBox=CreatePanel.SummaryBox
Description:SetScrollChild(CreatePanel.SummaryBox)
CreatePanel.ItemLevel=input(VoiceCard,88,23); CreatePanel.ItemLevel:SetLabel('最低装等')
CreatePanel.Score=input(VoiceCard,88,23); CreatePanel.Score:SetLabel('最低分数')
CreatePanel.VoiceBox=input(VoiceCard,84,18)
CreatePanel.VoiceBox:SetPoint('TOP',CreatePanel.Score,'BOTTOM',0,-3)
CreatePanel.PrivateGroup=GUI:GetClass('CheckBox'):New(VoiceCard); CreatePanel.PrivateGroup:SetText('仅好友')
CreatePanel.CrossFactionGroup=GUI:GetClass('CheckBox'):New(VoiceCard); CreatePanel.CrossFactionGroup:SetText('跨阵营')
CreatePanel.CreateButton=button(CreatePanel,'创建活动'); CreatePanel.DisbandButton=button(CreatePanel,'解散活动')
CreateAuto=GUI:GetClass('CheckBox'):New(CreatePanel); CreateAuto:SetText('自动邀请(需开语言过滤)')
local ah={}
for _,v in ipairs({{'Icon',30},{'Name',95},{'Role',40},{'Class',40},{'FactionGroup',40},{'Level',140},{'ItemLevel',52},{'Msg',169},{'Option',130}}) do
    ah[#ah+1]={key=v[1],width=v[2]}
end
ApplicantPanel.ApplicantList=makeTable(ApplicantPanel,ah)
for i,v in ipairs({{'ActivityDropdown','活动类型',180},{'ClassDropdown','职业',100},{'RoleDropdown','职责',100},{'SearchInput','搜索',150}}) do
    local label=RecentPanel:CreateFontString(); label:SetText(v[2]); label:SetPoint('TOPLEFT',main,'TOPLEFT',70+(i-1)*120,-30)
    local f=i==4 and input(RecentPanel,v[3],15) or dropdown(RecentPanel,v[3])
    f:SetPoint('TOPLEFT',label,'BOTTOMLEFT',i==4 and 10 or 0,i==4 and -10 or -5)
    RecentPanel[v[1]]=f
end
RecentPanel.BatchDeleteButton=button(RecentPanel,'批量删除'); RecentPanel.BatchDeleteButton:Disable()
local rh={}
for _,v in ipairs({{'Flag',30},{'Name',150},{'Class',50},{'Role',50},{'ItemLevel',50},{'Activity',150},{'Time',150},{'Notes',120}}) do
    rh[#rh+1]={key=v[1],width=v[2]}
end
RecentPanel.MemberList=makeTable(RecentPanel,rh)
function setupTablePages()
    for _,kind in ipairs({'ManagerPanel','CreatePanel','ApplicantPanel','RecentPanel','IgnoreListPanel'}) do ns.SkinTablePanel(modules[kind],kind) end
    flush(); flush()
end
function panelPass(kind,p)
    for i=1,30 do
        local name,value=debug.getupvalue(ns.Boot,i)
        if name=='PASSES' then for _,v in ipairs(value) do if v[1]==kind then return v[2](p) end end end
    end
    error('Missing panel pass')
end
