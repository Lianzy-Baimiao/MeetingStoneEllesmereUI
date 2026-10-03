"""Browse-list cancel action: native SummaryGrid, state machine and callback."""
import unittest
import test_applicant_actions as actions


class SummaryCancelTests(unittest.TestCase):
    run_lua = actions.ApplicantActionTests.run_lua
    load = actions.ApplicantActionTests.load

    def setUp(self):
        actions.ApplicantActionTests.setUp(self)
        self.run_lua("""
            local original = CreateFrame
            function CreateFrame(kind, name, parent, template)
                local f = original(kind, name, parent, template)
                if template == 'LoadingSpinnerTemplate' then
                    f.Anim = {Play=function() f.playing=true end, Stop=function() f.playing=false end}
                end
                return f
            end
            LFG_LIST_PENDING='已申请'; LFG_LIST_ROLE_CHECK='职责确认'
            LFG_LIST_APP_UNEMPOWERED='没有取消权限'
            for _, key in ipairs({'CANCELLED','DECLINED','TIMED_OUT','INVITED',
                'INVITE_ACCEPTED','INVITE_DECLINED'}) do _G['LFG_LIST_APP_'..key]=key end
            RED_FONT_COLOR={r=1,g=0,b=0}; GREEN_FONT_COLOR={r=0,g=1,b=0}
            NORMAL_FONT_COLOR={r=1,g=.8,b=0}
            LFGListUtil_IsAppEmpowered=function() return empowered ~= false end
            C_LFGList={GetRoleCheckInfo=function() return roleCheck end,
                CancelApplication=function(id) cancelled=cancelled or {}; table.insert(cancelled,id) end}
            browse.ActivityList=CreateFrame('Frame',nil,browse)
            GetTime=function() return 100 end
            function makeActivity(status, pending, id)
                return {
                    GetApplicationStatus=function() return status end,
                    GetPendingStatus=function() return pending end,
                    GetApplicationExpiration=function() return 225 end,
                    GetVoiceChat=function() return nil end,
                    GetComment=function() return 'Test group comment' end,
                    IsDelisted=function() return false end,
                    IsApplicationFinished=function() return false end,
                    IsApplication=function() return status=='applied' end,
                    GetID=function() return id or 12345 end,
                }
            end
        """)
        self.load('tests/fixtures/SummaryGrid-20261003.lua')
        self.load('tests/fixtures/BrowseCancelApplication-20261003.lua')
        self.run_lua("""
            ns.BuildDispatch()
            summaryRow=CreateFrame('Frame',nil,browse); summaryRow:SetSize(660,32)
            summaryRow:SetPoint('TOPLEFT',main,'TOPLEFT',0,-100)
            function summaryRow:FireHandler(handler)
                self.calls=(self.calls or 0)+1
                browse.ActivityList:Fire(handler,self,activity)
            end
            summary=makeNative('SummaryGrid',summaryRow); summary:SetSize(208,32)
            summary:SetPoint('RIGHT',summaryRow,'RIGHT',0,0)
            cancel=summary.CancelButton
            for _,t in ipairs(cancel.regions) do
                if t.atlas=='groupfinder-icon-redx' then oldCancelX=t end
            end
            activity=makeActivity('applied'); summary:SetActivity(activity)
        """)

    def test_dispatch_skins_late_created_cancel_button_and_centers_small_x(self):
        self.run_lua("""
            ns.SkinObject(summary)
            assert(cancel.NormalTexture:GetAlpha()==0, 'cancel retains raised template art')
            assert(oldCancelX:GetAlpha()==0, 'cancel retains old red-X atlas')
            assert(cancel.darkBorder, 'cancel not connected to button skin')
            local art=assert(ns.D(summary).cancelAction, 'summary cancel not explicitly skinned')
            assert(art.icon.atlas=='uitools-icon-close')
            assert(art.icon:GetWidth()==12 and art.icon:GetHeight()==12)
            local p,relative,rp,x,y=art.icon:GetPoint()
            assert(p=='CENTER' and relative==art.host and rp=='CENTER' and x==0 and y==0)
            assert(cancel:GetWidth()==22 and cancel:GetHeight()==22)
        """)

    def test_cancel_has_clear_gap_from_timer_and_stays_inside_row(self):
        self.run_lua("""
            ns.SkinObject(summary)
            assert(cancel:GetLeft()-summary.ExpirationTime:GetRight()>=5,
                'cancel touches application countdown')
            assert(summary:GetRight()-cancel:GetRight()>=8)
            assert(cancel:GetTop()<=summary:GetTop()-4 and cancel:GetBottom()>=summary:GetBottom()+4)
            assert(summary.PendingLabel:IsShown() and summary.ExpirationTime:IsShown())
        """)

    def test_hover_disable_and_hide_have_clear_feedback_without_changing_handlers(self):
        self.run_lua("""
            local click,enable,disable=cancel:GetScript('OnClick'),cancel:GetScript('OnEnable'),cancel:GetScript('OnDisable')
            ns.SkinObject(summary); local art=assert(ns.D(summary).cancelAction)
            local normal=art.icon.vertexColor[2]
            cancel:RunScript('OnEnter')
            assert(art.icon.vertexColor[2]>normal, 'hover does not brighten icon')
            cancel:RunScript('OnLeave'); assert(art.icon.vertexColor[2]==normal)
            empowered=false; summary:SetActivity(activity)
            assert(not cancel:IsEnabled() and art.host:GetAlpha()==.4)
            assert(cancel.tooltip==LFG_LIST_APP_UNEMPOWERED)
            cancel:RunScript('OnEnter'); assert(art.icon.vertexColor[2]==normal)
            cancel:Click(); assert(not cancelled)
            cancel:Hide(); empowered=true; summary:SetActivity(activity)
            assert(art.host:GetAlpha()==1 and art.icon.vertexColor[2]==normal)
            cancel:Click(); assert(#cancelled==1 and cancelled[1]==12345)
            assert(cancel:GetScript('OnClick')==click and cancel:GetScript('OnEnable')==enable)
            assert(cancel:GetScript('OnDisable')==disable)
        """)

    def test_native_application_statuses_keep_cancel_spinner_and_labels_authoritative(self):
        self.run_lua("""
            ns.SkinObject(summary)
            for _,status in ipairs({'cancelled','failed','declined','declined_full','declined_delisted',
                'timedout','invited','inviteaccepted','invitedeclined','none'}) do
                summary:SetActivity(makeActivity(status))
                assert(not cancel:IsShown(), 'cancel shown for '..status)
            end
            roleCheck=true; summary:SetActivity(makeActivity('none','applied'))
            assert(not cancel:IsShown() and summary.Spinner:IsShown())
            assert(summary.Spinner.playing and summary.PendingLabel:GetText()==LFG_LIST_ROLE_CHECK)
            assert(not summary.ExpirationTime:IsShown())
            roleCheck=false; summary:SetActivity(makeActivity('applied','cancelled'))
            assert(not cancel:IsShown())
            summary:SetActivity(activity); summary:UpdateExpiration()
            assert(cancel:IsShown() and not summary.Spinner:IsShown())
            assert(summary.PendingLabel:GetText()==LFG_LIST_PENDING and summary.ExpirationTime:GetText()=='2:05')
            assert(summary.Summary:GetText()=='Test group comment')
        """)

    def test_reused_rows_and_engine_repaint_keep_art_and_current_activity(self):
        self.run_lua("""
            ns.SkinObject(summary); local art=assert(ns.D(summary).cancelAction)
            local count=#frames; local hooks=#cancel.hooks.OnEnable
            for i=1,200 do
                activity=makeActivity('applied',nil,i)
                summary:SetActivity(activity)
                if i%50==0 then GetFFD(cancel).skinned=nil end
                ns.SkinSummaryGrid(summary); ns.SkinButton(cancel); ns.SkinObject(cancel)
                assert(art.icon:GetAlpha()==1 and oldCancelX:GetAlpha()==0)
                assert(cancel:IsShown() and art.host:GetParent()==cancel)
            end
            assert(#frames==count and #cancel.hooks.OnEnable==hooks and #C_Timer.pending==0)
            cancel:Click(); assert(#cancelled==1 and cancelled[1]==200)
        """)

    def test_class_colour_setting_does_not_recolour_destructive_action(self):
        self.run_lua("""
            ns.SkinObject(summary); local art=assert(ns.D(summary).cancelAction)
            local r,g,b=unpack(art.icon.vertexColor)
            ns.Set('useClassColor',true); ns.Set('useClassColor',false)
            assert(art.icon.vertexColor[1]==r and art.icon.vertexColor[2]==g and art.icon.vertexColor[3]==b)
            assert(r>g and r>b)
        """)


if __name__ == '__main__':
    unittest.main()
