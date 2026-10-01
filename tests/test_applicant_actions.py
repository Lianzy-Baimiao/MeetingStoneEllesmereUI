"""Native pooled OperationGrid actions and manager refresh, screenshot 5dff0550."""
import unittest
import test_regressions as regression
import test_table_panels as tables

class ApplicantActionTests(unittest.TestCase):
    run_lua=regression.RegressionTests.run_lua

    def load(self,name,addon=False):
        source=(regression.ROOT/name).read_text(encoding='utf-8-sig')
        if addon: self.lua.execute("assert(loadstring(...))('MeetingStoneEllesmereUI',ns)",source)
        else: self.lua.execute(source)

    def setUp(self):
        regression.RegressionTests.setUp(self)
        tables.TablePanelTests.setup_pages(self)
        self.run_lua("""
            local Frame=getmetatable(main)
            local original=CreateFrame
            function CreateFrame(kind,name,parent,template)
                local f=original(kind,name,parent)
                if template=='UIMenuButtonStretchTemplate' then
                    f.Text=f:CreateFontString(); f.Text:SetPoint('CENTER',f,'CENTER')
                    f.LeftSeparator=f:CreateTexture(); f.RightSeparator=f:CreateTexture()
                    f.NormalTexture=f:CreateTexture(); f.HighlightTexture=f:CreateTexture()
                elseif template=='LoadingSpinnerTemplate' then f.Anim={Play=function() end} end
                return f
            end
            function Frame:SetFormattedText(fmt,...) self:SetText(string.format(fmt,...)) end
            function Frame:SetTooltipAnchor() end
            function Frame:FireHandler(handler) self.lastHandler=handler; self.calls=(self.calls or 0)+1 end
            BuildEnv=function() end; classes={}
            Addon={NewClass=function(_,name) local c=setmetatable({},{__index=Frame}); classes[name]=c; return c end}
            L=setmetatable({},{__index=function(_,key) return key end})
            INVITE='邀请'; REFRESH='刷新'; LFG_LIST_INVITE_GROUP='邀请（%d）'
            ns.skip={}
            ns.GetClass=function() end; ns.MSClass=function(name) return classes[name] end
            ns.ListFontString=function(f) f:SetFont('Fonts/theme.ttf',ns.Get('listFontSize'),'') end
            ns.SetLabelFonts=function(f)
                if f.Text then f.Text:SetFont('Fonts/theme.ttf',ns.Get('labelFontSize'),'') end
            end
            -- Engine setup utilities; the actual ApplyButton/state functions are fixtures.
            WSkin=ns.S; Theme={bgR=.06,bgG=.06,bgB=.06,bgA=1}
            local data=setmetatable({},{__mode='k'})
            GetFFD=function(f) data[f]=data[f] or {}; return data[f] end
            function FadeRegions(f,keep)
                for _,t in ipairs(f.regions) do
                    if t.kind=='Texture' and not (keep and keep[t]) then t:SetAlpha(0) end
                end
            end
            AddBorder=function(f) f.darkBorder=true end; Register=function() end
            function WSkin.CompleteSetup(f,key,apply,keep)
                local d=GetFFD(f); if d[key] then return end
                d[key]=true; apply(f,d,keep)
            end
            function WSkin.White(f,r,g,b) f:SetTextColor(r or 1,g or 1,b or 1) end
            function makeNative(name,parent)
                local f=CreateFrame('Button',nil,parent,'UIMenuButtonStretchTemplate')
                for key,value in pairs(classes[name]) do f[key]=value end
                f.GetType=function() return classes[name] end
                f.IsType=function(_,c) return c==classes[name] end
                f:Constructor(); return f
            end
        """)
        for name in ('OperationGrid','RefreshButton','EUIActionButton'):
            self.load('tests/fixtures/'+name+'-20261002.lua')
        self.load('Widgets.lua',addon=True)
        self.run_lua("""
            ns.BuildDispatch()
            row=CreateFrame('Frame',nil,ApplicantPanel); row:SetSize(660,32)
            row.bg=CreateFrame('Frame',nil,row); row.bg:SetAllPoints(row)
            op=makeNative('OperationGrid',row); op:SetSize(136,32)
            invite=op.InviteButton; decline=op.DeclineButton
            for _,t in ipairs(decline.regions) do if t.atlas=='groupfinder-icon-redx' then oldX=t end end
            refresh=makeNative('RefreshButton',ManagerPanel); ManagerPanel.RefreshButton=refresh
        """)

    def test_late_created_cell_dispatch_replaces_both_native_button_skins(self):
        self.run_lua("""
            op:SetInviteButton(true,1); ns.SkinObject(op)
            assert(invite.NormalTexture:GetAlpha()==0,'invite retains raised template art')
            assert(decline.NormalTexture:GetAlpha()==0 and oldX:GetAlpha()==0,'native red X remains')
            assert(invite.darkBorder and decline.darkBorder)
            assert(invite:GetText()=='邀请' and invite:GetWidth()==70 and decline:GetWidth()==24)
            local art=assert(ns.D(op).operationActions)
            assert(art.icon.atlas=='uitools-icon-close' and art.icon:GetWidth()==12)
            assert(art.icon.vertexColor[1]>art.icon.vertexColor[2])
        """)

    def test_native_handlers_pending_state_and_status_messages_remain_authoritative(self):
        self.run_lua("""
            local a,b=invite:GetScript('OnClick'),decline:GetScript('OnClick')
            op:SetInviteButton(true,3); ns.SkinObject(op)
            assert(invite:GetText()=='邀请（3）')
            invite:Click(); assert(row.lastHandler=='OnInviteClick' and op.Spinner:IsShown())
            assert(not invite:IsEnabled() and not decline:IsEnabled())
            local art=assert(ns.D(op).operationActions); assert(art.host:GetAlpha()==.4)
            decline:Click(); assert(row.calls==1)
            op:SetSpinner(false); decline:Click(); assert(row.lastHandler=='OnDeclineClick' and row.calls==2)
            op:SetText('已拒绝'); assert(not invite:IsShown() and not decline:IsShown())
            assert(op.StatusText:GetText()=='已拒绝' and not op.Spinner:IsShown())
            assert(invite:GetScript('OnClick')==a and decline:GetScript('OnClick')==b)
        """)

    def test_repeated_pool_reuse_does_not_erase_icon_or_accumulate_hooks(self):
        self.run_lua("""
            ns.SkinObject(op); local art=assert(ns.D(op).operationActions)
            local count=#frames; local hooks=#decline.hooks.OnEnable
            for i=1,200 do
                op:SetInviteButton(true,i%5+1); op:SetSpinner(i%2==0)
                if i%50==0 then GetFFD(decline).skinned=nil end -- engine re-application
                ns.SkinOperationGrid(op); ns.SkinButton(decline); ns.SkinObject(decline)
                assert(art.icon:GetAlpha()==1 and oldX:GetAlpha()==0)
            end
            assert(#frames==count and #decline.hooks.OnEnable==hooks and #C_Timer.pending==0)
            assert(art.host:GetParent()==decline)
        """)

    def test_icon_does_not_inherit_selection_class_colour(self):
        self.run_lua("""
            ns.SkinObject(op); local art=assert(ns.D(op).operationActions)
            local r,g=art.icon.vertexColor[1],art.icon.vertexColor[2]
            UnitClass=function() return '牧师','PRIEST' end
            C_ClassColor={GetClassColor=function() return {r=1,g=1,b=1} end}
            ns.Set('useClassColor',true); ns.Set('useClassColor',false)
            assert(art.icon.vertexColor[1]==r and art.icon.vertexColor[2]==g)
        """)

    def test_refresh_fits_label_and_centers_without_legacy_icon_offset(self):
        self.run_lua("""
            for _,size in ipairs({8,12,20}) do
                ns.Set('labelFontSize',size); ns.SkinTablePanel(ManagerPanel,'ManagerPanel'); flush()
                local label=refresh:GetFontString()
                assert(refresh:GetWidth()>=label:GetStringWidth()+24,'refresh label spills outside button')
                assert(refresh:GetWidth()>=76 and refresh:GetHeight()>=size+8)
                local point,relative,relpoint,x,y=label:GetPoint()
                assert(point=='CENTER' and relative==refresh and relpoint=='CENTER' and x==0 and y==0)
                assert(refresh:GetRight()<=main:GetRight()-14)
                assert(refresh:GetBottom()>=ManagerPanel:GetTop())
            end
        """)

    def test_refresh_preserves_click_disable_and_never_revives_hidden_stock_icon(self):
        self.run_lua("""
            local count=0; local click=function() count=count+1 end; refresh:SetScript('OnClick',click)
            refresh:SetTooltip('刷新申请者'); ns.SkinTablePanel(ManagerPanel,'ManagerPanel'); flush()
            for i=1,50 do
                refresh:Disable(); refresh:Click(); refresh:Enable()
                ManagerPanel:Hide(); ManagerPanel:Show(); flush()
                assert(not refresh.Icon:IsShown(),'native OnEnable revives obsolete icon')
                assert(refresh:GetWidth()>=76)
            end
            assert(count==0); refresh:Click(); assert(count==1 and refresh:GetScript('OnClick')==click)
            assert(refresh.tooltip=='刷新申请者')
        """)

if __name__=='__main__': unittest.main()
