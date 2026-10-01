"""Join layout and specialization label must agree with native application."""
import unittest
import test_regressions as regression


class BrowseJoinTests(unittest.TestCase):
    setUp = regression.RegressionTests.setUp
    run_lua = regression.RegressionTests.run_lua

    def setup_controls(self):
        self.run_lua("""
            eb=CreateFrame('EditBox',nil,browse); browse.SearchBox=eb
            eb:SetSize(220,18)
            dd=browse.ActivityDropdown; dd:SetSize(170,26)
            dd:SetPoint('TOPLEFT',browse,'TOPLEFT',20,-40)
            eb:SetPoint('LEFT',dd,'RIGHT',20,0)
            LFGListFrame={SearchPanel={SearchBox=eb}}
            C_LFGList={}
            selected={false,true,false,true}
            roleReads=0; roleWrites=0; specReads=0; specIndex=2; specRole='HEALER'
            GetLFGRoles=function() roleReads=roleReads+1; return unpack(selected) end
            SetLFGRoles=function(...) selected={...}; roleWrites=roleWrites+1 end
            originalRoleWriter=SetLFGRoles
            GetSpecialization=function() return specIndex end
            GetSpecializationInfo=function(index)
                assert(index==specIndex, 'did not query the active specialization')
                specReads=specReads+1
                return 123,'test',nil,nil,specRole
            end
        """)
        maker=self.lua.execute((regression.ROOT/'tests/fixtures/BrowseJoinLayout-20261001.lua').read_text(encoding='utf-8'))
        quick,auto=maker(self.lua.globals().browse)
        self.lua.globals().quick=quick; self.lua.globals().auto=auto
        self.run_lua("""
            quickClick=function(self) quickSaved=self:GetChecked() end
            autoClick=function(self) autoSaved=self:GetChecked() end
            quick:SetScript('OnClick',quickClick); auto:SetScript('OnClick',autoClick)
        """)

    def test_two_row_group_is_centered_on_inputs_with_equal_left_edge(self):
        self.setup_controls()
        self.run_lua("""
            browsePass(); flush()
            local top,bottom=auto:GetTop(),quick:GetBottom()
            assert(math.abs((top+bottom)/2-(eb:GetTop()+eb:GetBottom())/2)<.001,
                'join group is not centered on the search row')
            assert(auto:GetLeft()==quick:GetLeft() and quick:GetLeft()>eb:GetRight())
            assert(auto:GetBottom()>=quick:GetTop(), 'join checkbox hitboxes overlap')
        """)

    def test_label_tracks_current_specialization_not_selected_roles(self):
        self.setup_controls()
        self.run_lua("""
            browsePass(); flush()
            assert(quick:GetText()=='双击加入（治疗）',
                'current specialization is HEALER, misleading label: '..quick:GetText())
            specIndex=3; specRole='TANK'
            fireEvent('PLAYER_SPECIALIZATION_CHANGED','player')
            assert(quick:GetText()=='双击加入（防御）')
            specIndex=1; specRole='DAMAGER'
            fireEvent('PLAYER_SPECIALIZATION_CHANGED','player')
            assert(quick:GetText()=='双击加入（输出）')
        """)

    def test_all_lfg_selections_leave_spec_label_and_role_apis_untouched(self):
        self.setup_controls()
        self.run_lua("""
            C_LFGList.GetAvailableRoles=function() error('availability is not specialization') end
            UnitGroupRolesAssigned=function() error('group role is not specialization') end
            browsePass(); flush(); assert(roleWrites==0 and roleReads==0)
            assert(SetLFGRoles==originalRoleWriter, 'unnecessary role writer hook')
            for i=0,7 do
                SetLFGRoles(true,i%2==1,math.floor(i/2)%2==1,i>=4)
                fireEvent('PLAYER_ROLES_ASSIGNED')
                browsePass(); flush()
                assert(quick:GetText()=='双击加入（治疗）')
                assert(roleWrites==i+1 and roleReads==0, 'display read or mutated LFG selection')
            end
            GetLFGRoles=nil; SetLFGRoles=nil
            fireEvent('PLAYER_ENTERING_WORLD')
            assert(quick:GetText()=='双击加入（治疗）')
        """)

    def test_actual_lfd_checkbox_writer_does_not_change_spec_label(self):
        self.setup_controls()
        self.lua.execute((regression.ROOT/'tests/fixtures/LFDFrame-reference.lua').read_text(encoding='utf-8'))
        self.run_lua("""
            browsePass(); flush()
            LFDQueueFrameRoleButtonLeader=CreateFrame('CheckButton')
            LFDQueueFrameRoleButtonTank=CreateFrame('CheckButton')
            LFDQueueFrameRoleButtonHealer=CreateFrame('CheckButton')
            LFDQueueFrameRoleButtonDPS=CreateFrame('CheckButton')
            LFGRole_GetChecked=function(button) return button:GetChecked() end
            LFDQueueFrameRoleButtonLeader:SetChecked(true)
            LFDQueueFrameRoleButtonTank:SetChecked(true)
            LFDQueueFrameRoleButtonDPS:SetChecked(true)
            LFDQueueFrame_SetRoles()
            assert(roleWrites==1 and selected[1] and selected[2] and not selected[3] and selected[4])
            assert(quick:GetText()=='双击加入（治疗）')
            LFDQueueFrameRoleButtonTank:SetChecked(false); LFDQueueFrame_SetRoles()
            assert(quick:GetText()=='双击加入（治疗）' and roleReads==0)
        """)

    def test_unavailable_specialization_never_falls_back_to_selected_roles(self):
        self.setup_controls()
        self.run_lua("""
            local getSpec,getInfo=GetSpecialization,GetSpecializationInfo
            GetSpecialization=nil
            browsePass(); flush()
            local function checkUnknown()
                fireEvent('PLAYER_ENTERING_WORLD')
                assert(quick:GetText()=='双击加入（专精未就绪）', quick:GetText())
                assert(roleReads==0 and roleWrites==0)
            end
            checkUnknown()
            GetSpecialization=getSpec; GetSpecializationInfo=nil; checkUnknown()
            GetSpecialization=function() error('not ready') end
            GetSpecializationInfo=getInfo; checkUnknown()
            GetSpecialization=getSpec; specIndex=nil
            local before=specReads; checkUnknown(); assert(specReads==before)
            specIndex=2; GetSpecializationInfo=function() error('not ready') end; checkUnknown()
            GetSpecializationInfo=function() return nil end; checkUnknown()
            GetSpecializationInfo=getInfo; specRole='NONE'; checkUnknown()
            specRole='HEALER'; fireEvent('PLAYER_SPECIALIZATION_CHANGED','player')
            assert(quick:GetText()=='双击加入（治疗）')
        """)

    def test_events_hidden_changes_and_reopen(self):
        self.setup_controls()
        self.run_lua("""
            browsePass(); flush(); browse:Hide()
            local reads=specReads
            specRole='DAMAGER'; fireEvent('PLAYER_SPECIALIZATION_CHANGED','player')
            assert(quick:GetText()=='双击加入（治疗）' and specReads==reads)
            browse:Show(); flush(); assert(quick:GetText()=='双击加入（输出）')
            specRole='TANK'; reads=specReads
            fireEvent('PLAYER_SPECIALIZATION_CHANGED','party1')
            assert(quick:GetText()=='双击加入（输出）' and specReads==reads)
            fireEvent('PLAYER_SPECIALIZATION_CHANGED','player')
            assert(quick:GetText()=='双击加入（防御）')
            specRole='HEALER'; fireEvent('PLAYER_ENTERING_WORLD')
            assert(quick:GetText()=='双击加入（治疗）')
        """)

    def test_label_agrees_with_unmodified_native_double_click_application(self):
        self.setup_controls()
        self.run_lua("""
            ActivityList=browse.ActivityList; Private_EnableQuickJoin=true
            ActivityList.callbacks={}
            function ActivityList:SetCallback(key,fn) self.callbacks[key]=fn end
            C_LFGList.GetSearchResultInfo=function() return nil end
            C_LFGList.ApplyToGroup=function(...) applied={...} end
            activity={GetID=function() return 42 end}
        """)
        self.lua.execute((regression.ROOT/'tests/fixtures/BrowseDoubleClick-20261001.lua').read_text(encoding='utf-8'))
        self.run_lua("""
            local original=ActivityList.callbacks.OnItemDoubleClick
            browsePass(); flush()
            assert(quick:GetScript('OnClick')==quickClick and auto:GetScript('OnClick')==autoClick)
            quick:Click(); auto:Click()
            assert(quickSaved and autoSaved)
            assert(quick:GetChecked() and auto:GetChecked() and not applied)
            assert(ActivityList.callbacks.OnItemDoubleClick==original)
            local cases={{'TANK','防御',true,false,false},
                {'HEALER','治疗',false,true,false}, {'DAMAGER','输出',false,false,true}}
            for _,case in ipairs(cases) do
                specRole=case[1]; applied=nil
                fireEvent('PLAYER_SPECIALIZATION_CHANGED','player')
                assert(not applied, 'label refresh applied to group')
                assert(quick:GetText()=='双击加入（'..case[2]..'）',
                    'display does not agree with native application: '..quick:GetText())
                original(nil,nil,activity)
                assert(applied[1]==42 and applied[2]==case[3] and applied[3]==case[4] and applied[4]==case[5],
                    'skin changed original specialization-based application')
            end
            Private_EnableQuickJoin=false; applied=nil
            original(nil,nil,activity); assert(not applied)
        """)

    def test_repeated_setup_reuses_frames_scripts_and_single_spec_listener(self):
        self.setup_controls()
        self.run_lua("""
            browsePass(); flush()
            local function hooks()
                local n=0; for _,f in ipairs(frames) do for _,h in pairs(f.hooks) do n=n+#h end end
                return n
            end
            local objects,handlers=#frames,hooks()
            for i=1,200 do
                browse:Hide(); browse:Show(); browsePass(); flush()
                specRole=i%2==0 and 'TANK' or 'DAMAGER'
                fireEvent('PLAYER_SPECIALIZATION_CHANGED','player')
            end
            assert(#frames==objects and hooks()==handlers and #C_Timer.pending==0)
            local before=specReads; fireEvent('PLAYER_SPECIALIZATION_CHANGED','player')
            assert(specReads==before+1, 'duplicate specialization listeners')
            before=specReads; SetLFGRoles(false,true,false,true)
            assert(specReads==before and roleReads==0 and SetLFGRoles==originalRoleWriter)
        """)

    def test_missing_control_leaves_layout_until_late_pair_arrives(self):
        self.setup_controls()
        self.run_lua("""
            auto:SetParent(main)
            local top=quick:GetTop()
            browsePass(); flush()
            assert(quick:GetTop()==top and quick:GetHeight()==24 and quick:GetText()=='双击加入(专精职责)')
            auto:SetParent(browse); browsePass(); flush()
            assert(quick:GetHeight()==20 and quick:GetText()=='双击加入（治疗）')
            dd:SetSize(170,30); flush()
            assert(math.abs((auto:GetTop()+quick:GetBottom())/2-(eb:GetTop()+eb:GetBottom())/2)<.001)
            assert(auto:GetLeft()==quick:GetLeft())
            local a=ns.D(auto).switch.host; local q=ns.D(quick).switch.host
            local center=(a:GetTop()+q:GetBottom())/2
            assert(math.abs(center-(eb:GetTop()+eb:GetBottom())/2)<=1, 'visible switches not centered to pixel precision')
        """)

    def test_tooltip_describes_specialization_without_selected_role_claim(self):
        self.setup_controls()
        self.run_lua("""
            function quick:SetTooltip(...) tooltip={...} end
            browsePass(); flush()
            assert(tooltip[1]=='双击加入')
            assert(tooltip[2]=='双击队伍时，按当前专精对应的职责申请加入。')
            assert(#tooltip==2, 'obsolete selected-role caveat remains')
        """)


if __name__ == '__main__': unittest.main()
