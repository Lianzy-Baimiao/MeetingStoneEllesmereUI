"""Selection semantics and secondary page geometry; no live game actions."""
import unittest
import test_regressions as regression

class TablePanelTests(unittest.TestCase):
    setUp = regression.RegressionTests.setUp
    run_lua = regression.RegressionTests.run_lua

    def test_list_selection_is_square_not_a_switch(self):
        self.run_lua("""
            local view=CreateFrame('Frame',nil,main); ns.D(view).selectionList=true
            local row=CreateFrame('CheckButton',nil,view); row:SetSize(700,32)
            local cell=CreateFrame('Frame',nil,row)
            local cb=GUI:GetClass('CheckBox'):New(cell); cb:SetSize(32,32)
            ns.SkinSwitch(cb)
            local s=ns.D(cb).switch
            assert(s.host:GetWidth()==s.host:GetHeight(), 'multi-selection cell was painted as a switch')
            assert(s.selection and not s.knob:IsShown())
        """)


    def setup_pages(self):
        self.lua.execute((regression.ROOT/'tests/table_panels_mock.lua').read_text(encoding='utf-8'))
        self.lua.execute((regression.ROOT/'tests/fixtures/IgnoreListPanel-20261002.lua').read_text(encoding='utf-8'))
        self.run_lua('IgnoreListPanel:OnInitialize(); IgnoreListPanel.IgnoreList:Refresh()')

    def test_recent_toolbar_is_aligned_and_native_handlers_survive(self):
        self.setup_pages()
        self.run_lua("""
            local p=RecentPanel; local n=0; local changed=function() n=n+1 end
            p.SearchInput:SetText('healer'); p.SearchInput:SetFocus()
            p.SearchInput:SetCallback('OnTextChanged',changed)
            p.RoleDropdown:SetCallback('OnSelectChanged',changed)
            setupTablePages()
            for _,key in ipairs({'ActivityDropdown','ClassDropdown','RoleDropdown','SearchInput'}) do
                local f=p[key]; local skin=ns.D(f).browseChrome
                assert(f:GetHeight()==26 and f:GetTop()==p.ActivityDropdown:GetTop())
                assert(skin and skin.host:IsShown())
            end
            assert(p.SearchInput:GetRight()+10<=p.BatchDeleteButton:GetLeft())
            assert(p.MemberList.sortButtons[1]:GetTop()<p.SearchInput:GetBottom())
            assert(p.SearchInput:GetText()=='healer' and p.SearchInput.focused)
            assert(p.SearchInput.callbacks.OnTextChanged==changed and p.RoleDropdown.callbacks.OnSelectChanged==changed)
            assert(not p.BatchDeleteButton:IsEnabled() and n==0)
            p.SearchInput:Fire('OnTextChanged'); p.RoleDropdown:Fire('OnSelectChanged'); assert(n==2)
        """)

    def test_manager_sidebar_inputs_fit_and_footer_actions_do_not_overlap(self):
        self.setup_pages()
        self.run_lua("""
            local createClick=function() created=(created or 0)+1 end
            CreatePanel.CreateButton:SetScript('OnClick',createClick)
            CreatePanel.DisbandButton:Disable()
            setupTablePages()
            local p=CreatePanel
            assert(p:GetWidth()==208)
            for _,f in ipairs({p.ActivityType,p.GeneralPlaystyle,p.ItemLevel,p.Score,p.PrivateGroup,p.CrossFactionGroup}) do
                assert(f:GetLeft()>=p:GetLeft() and f:GetRight()<=p:GetRight(), 'sidebar control escaped card')
            end
            assert(p.ActivityType:GetWidth()==p.GeneralPlaystyle:GetWidth())
            assert(p.ActivityType:GetBottom()>p.GeneralPlaystyle:GetTop())
            assert(p.CreateButton:GetRight()+10<=p.DisbandButton:GetLeft())
            assert(p.CreateButton:GetTop()<p:GetBottom())
            assert(p:GetRight()<ApplicantPanel:GetLeft())
            assert(ManagerPanel.ApplicantListBlocker:GetLeft()==ApplicantPanel:GetLeft())
            assert(p.CreateButton:GetScript('OnClick')==createClick and not p.DisbandButton:IsEnabled() and not created)
            p.CreateButton:Click(); assert(created==1)
            assert(not ns.D(p.PrivateGroup).switch.selection, 'preference became a selection box')
        """)

    def test_headers_match_existing_and_newly_created_cell_columns(self):
        self.setup_pages()
        self.run_lua("""
            setupTablePages()
            for _,p in ipairs({ApplicantPanel,RecentPanel,IgnoreListPanel}) do
                local view=p.ApplicantList or p.MemberList or p.IgnoreList
                table.insert(view.items,{leader='late'}); view:Refresh()
                local previous
                for _,h in ipairs(view.sortButtons) do
                    assert(h:GetTop()==view:GetTop()+26 and h:GetHeight()==26)
                    if previous then assert(math.abs(h:GetLeft()-previous:GetRight())<.001) end
                    for _,row in ipairs(view.buttons) do
                        local cell=row[h.key]
                        assert(math.abs(cell:GetLeft()-h:GetLeft())<.001, 'pooled cell/header column mismatch')
                        assert(math.abs(cell:GetWidth()-h:GetWidth())<.001)
                    end
                    previous=h
                end
                assert(previous:GetRight()<=view:GetRight())
            end
        """)

    def test_original_ex_row_multiselect_and_remove_callbacks_are_unchanged(self):
        self.setup_pages()
        self.run_lua("""
            local p=IgnoreListPanel; local view=p.IgnoreList
            local cell1,cell2=view.buttons[1]['@'],view.buttons[2]['@']
            local click1,changed=cell1.Check:GetScript('OnClick'),cell1.callbacks.OnChanged
            local remove,select
            for _,f in ipairs({p:GetChildren()}) do
                if f:GetText()=='移除勾选玩家' then remove=f end
                if f:GetText()=='全选/取消全选' then select=f end
            end
            local removeClick,selectClick=remove:GetScript('OnClick'),select:GetScript('OnClick')
            setupTablePages()
            assert(cell1.Check:GetScript('OnClick')==click1 and cell1.callbacks.OnChanged==changed)
            assert(remove:GetScript('OnClick')==removeClick)
            -- 1.4.8 intentionally corrects the bulk button's mixed-state inversion.
            assert(select:GetScript('OnClick')~=selectClick)
            assert(#MEETINGSTONE_UI_DB.IGNORE_LIST==2 and not MEETINGSTONE_UI_DB.IGNORE_LIST[1].selected)
            cell1.Check:Click(); cell2.Check:Click()
            assert(MEETINGSTONE_UI_DB.IGNORE_LIST[1].selected and MEETINGSTONE_UI_DB.IGNORE_LIST[2].selected)
            for _,cell in ipairs({cell1,cell2}) do
                local skin=ns.D(cell.Check).switch
                assert(skin.selection and skin.tick:IsShown() and not skin.knob:IsShown())
                cell.Check:Disable(); assert(skin.host:GetAlpha()<1); cell.Check:Enable()
            end
            select:Click(); assert(not MEETINGSTONE_UI_DB.IGNORE_LIST[1].selected and not MEETINGSTONE_UI_DB.IGNORE_LIST[2].selected)
            assert(not ns.D(cell1.Check).switch.tick:IsShown())
            cell1.Check:Click(); remove:Click()
            assert(#MEETINGSTONE_UI_DB.IGNORE_LIST==1 and MEETINGSTONE_UI_DB.IGNORE_LIST[1].leader=='B')
            assert(browse.IgnoreWithLeader.A==nil and browse.IgnoreWithLeader.B)
            assert(view.SetSelectModeValue=='RADIO', 'skin changed row-selection mode')
            assert(select:GetHeight()==remove:GetHeight() and select:GetRight()<remove:GetLeft())
        """)

    def test_switch_created_before_list_registration_converts_without_new_hooks(self):
        self.setup_pages()
        self.run_lua("""
            local cb=IgnoreListPanel.IgnoreList.buttons[1]['@'].Check
            ns.SkinSwitch(cb); local skin=ns.D(cb).switch
            assert(not skin.selection)
            local hooks=#cb.hooks.OnClick
            setupTablePages()
            assert(ns.D(cb).switch==skin and skin.selection and #cb.hooks.OnClick==hooks)
            local row=IgnoreListPanel.IgnoreList.buttons[1]
            assert(not ns.D(row).switch, 'full row painted as checkbox')
        """)

    def test_borrowed_creation_inputs_release_art_font_and_height(self):
        self.setup_pages()
        self.run_lua("""
            local p=CreatePanel; local f=p.VoiceBox
            local original=function() voiceChanged=true end
            f:SetScript('OnTextChanged',original); f:SetText('voice'); f:SetFocus()
            setupTablePages()
            assert(f:GetHeight()==24 and f.Left:GetAlpha()==0)
            local skin=ns.D(f).browseChrome
            p:Hide()
            assert(f:GetHeight()==18 and f.Left:GetAlpha()==1 and not skin.host:IsShown())
            local path,size=f:GetFont(); assert(path=='stock' and size==13)
            p:Show(); flush(); assert(f:GetHeight()==24)
            f:SetParent(main)
            assert(f:GetHeight()==18 and not skin.host:IsShown() and f.Left:GetAlpha()==1)
            ns.ApplyTablePanels(); flush()
            assert(f:GetHeight()==18 and f:GetParent()==main)
            assert(f:GetText()=='voice' and f.focused and f:GetScript('OnTextChanged')==original and not voiceChanged)
            f:SetHeight(20); f:SetParent(VoiceCard); flush(); assert(f:GetHeight()==24)
            f:SetParent(main); assert(f:GetHeight()==20, 'did not restore latest borrow height')
        """)

    def test_late_native_onshow_art_and_late_borrow_are_repainted(self):
        self.setup_pages()
        self.run_lua("""
            local f=CreatePanel.TitleBox
            f:SetParent(main); setupTablePages()
            assert(not ns.D(f).browseChrome, 'borrowed a foreign editbox')
            f:Hide(); f:SetParent(TitleCard)
            f:HookScript('OnShow',function() f.Left:SetAlpha(1) end)
            f:Show(); flush(); flush()
            assert(ns.D(f).browseChrome.host:IsShown() and f.Left:GetAlpha()==0)
            local dd=RecentPanel.ActivityDropdown
            dd:Disable(); flush(); assert(ns.D(dd).browseChrome.host:GetAlpha()<1)
            dd:Enable(); flush(); assert(ns.D(dd).browseChrome.host:GetAlpha()==1)
        """)

    def test_resize_font_update_and_reopen_reuse_frames_and_handlers(self):
        self.setup_pages()
        self.run_lua("""
            setupTablePages()
            local function hooks()
                local n=0; for _,f in ipairs(frames) do for _,h in pairs(f.hooks) do n=n+#h end end; return n
            end
            local objects,handlers=#frames,hooks()
            for i=1,100 do
                RecentPanel:Hide(); RecentPanel:Show()
                IgnoreListPanel.IgnoreList:Refresh()
                main:SetSize(i%2==0 and 922 or 1000,447)
                setupTablePages()
            end
            assert(#frames==objects and hooks()==handlers and #C_Timer.pending==0, 'repeat page setup leaked')
            ns.Set('labelFontSize',18); flush()
            local _,size=RecentPanel.SearchInput:GetFont(); assert(size==18)
            assert(RecentPanel.SearchInput:GetBottom()>RecentPanel.MemberList.sortButtons[1]:GetTop())
        """)

    def test_list_and_footer_geometry_remain_inside_moved_main_window(self):
        self.setup_pages()
        self.run_lua("""
            main.x=47; main.y=81
            for _,font in ipairs({12,18}) do
                ns.Set('labelFontSize',font); setupTablePages()
                for _,p in ipairs({RecentPanel,IgnoreListPanel}) do
                    local view=p.MemberList or p.IgnoreList
                    assert(view:GetLeft()==main:GetLeft()+14)
                    assert(view:GetRight()==main:GetRight()-14)
                    assert(view:GetBottom()==main:GetBottom()+42)
                end
                local s=ns.D(IgnoreListPanel).tablePanel
                for _,button in ipairs({s.select,s.remove,CreatePanel.CreateButton,CreatePanel.DisbandButton}) do
                    assert(button:GetBottom()==main:GetBottom()+8)
                    assert(button:GetLeft()>=main:GetLeft()+14 and button:GetRight()<=main:GetRight()-14)
                end
                assert(SummaryCard:GetBottom()>VoiceCard:GetTop(), 'creation cards overlap')
            end
        """)

    def test_sort_invite_decline_callbacks_and_radio_rows_are_not_replaced(self):
        self.setup_pages()
        self.run_lua("""
            local view=ApplicantPanel.ApplicantList
            local calls=0; local action=function() calls=calls+1 end
            view:SetCallback('OnInviteClick',action); view:SetCallback('OnDeclineClick',action)
            local h=view.sortButtons[2]; h:SetScript('OnClick',action)
            local row=view.buttons[1]; row:SetChecked(true)
            local radio=CreateFrame('CheckButton',nil,row); radio:SetSize(20,20)
            radio:SetNormalTexture('Interface\\Buttons\\UI-RadioButton')
            setupTablePages(); view:Refresh()
            assert(view.callbacks.OnInviteClick==action and view.callbacks.OnDeclineClick==action)
            assert(h:GetScript('OnClick')==action and calls==0)
            assert(row:GetChecked() and not ns.D(row).switch and not ns.D(radio).switch)
            h:Click(); view:Fire('OnInviteClick'); view:Fire('OnDeclineClick'); assert(calls==3)
        """)

    def test_native_invitation_buttons_and_spinner_fit_operation_column(self):
        self.setup_pages()
        self.run_lua("""
            -- Exact dimensions/anchors from MeetingStone/Widget/OperationGrid.lua.
            local cell=ApplicantPanel.ApplicantList.buttons[1].Option
            local invite=CreateFrame('Button',nil,cell); invite:SetSize(70,22)
            invite:SetPoint('TOPLEFT',cell,'TOPLEFT',10,-5)
            local decline=CreateFrame('Button',nil,cell); decline:SetSize(24,22)
            decline:SetPoint('TOPLEFT',invite,'TOPRIGHT',3,0)
            local spinner=CreateFrame('Frame',nil,cell); spinner:SetSize(32,32)
            spinner:SetPoint('LEFT',decline,'RIGHT',-5,0)
            for _,width in ipairs({922,1000,840}) do
                main:SetSize(width,447); setupTablePages()
                assert(invite:GetRight()<decline:GetLeft())
                assert(spinner:GetRight()<=cell:GetRight(), 'invitation spinner escaped operation column')
                assert(cell:GetRight()<=ApplicantPanel:GetRight()-16)
            end
        """)

    def test_all_requested_panel_passes_install_new_presentation(self):
        self.setup_pages()
        self.run_lua("""
            for _,kind in ipairs({'ManagerPanel','CreatePanel','ApplicantPanel','RecentPanel','IgnoreListPanel'}) do
                panelPass(kind,ns.Module(kind))
                assert(ns.D(ns.Module(kind)).tablePanel, 'panel pass not integrated: '..kind)
            end
            flush(); flush()
        """)

if __name__ == '__main__': unittest.main()

