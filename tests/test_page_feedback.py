"""Regression: multiline viewport, submenu selection, bulk select, recent filters."""
import unittest
import test_regressions as regression
import test_table_panels as tables

class PageFeedbackTests(unittest.TestCase):
    setUp=regression.RegressionTests.setUp
    run_lua=regression.RegressionTests.run_lua

    def pages(self):
        tables.TablePanelTests.setup_pages(self)

    def behavior(self):
        self.run_lua("DropMenuItem={}; DropMenu={}; Recent={}; tinsert=table.insert; getmetatable(main).SetTexCoord=function(self,...) self.texCoords={...} end")
        self.lua.execute((regression.ROOT/'tests/fixtures/PageBehavior-20261002.lua').read_text(encoding='utf-8'))

    def test_multiline_chrome_tracks_viewport_not_scrolling_editbox(self):
        self.pages()
        self.run_lua(r"""
            Description.kind='ScrollFrame'
            Description.EditBox=CreatePanel.SummaryBox
            Description:SetScrollChild(CreatePanel.SummaryBox)
            Description.GetScrollChild=function(self) return self.scrollChild end
            Description:SetPoint('TOPLEFT',SummaryCard,'TOPLEFT',10,-30)
            Description:SetPoint('BOTTOMRIGHT',SummaryCard,'BOTTOMRIGHT',-10,15)
            Description.Bg=Description:CreateTexture()
            local eb=CreatePanel.SummaryBox
            eb:SetPoint('TOPLEFT',Description,'TOPLEFT',0,0); eb:SetHeight(260)
            eb:SetText('one\ntwo\nthree'); eb:SetFocus()
            local fn=function() end; eb:SetScript('OnTextChanged',fn)
            setupTablePages()
            local skin=ns.D(Description).browseChrome
            assert(skin and skin.host:IsShown(), 'multiline border was not applied to viewport')
            local inner=ns.D(eb).browseChrome
            assert(not inner or not inner.host:IsShown(), 'scrolling editbox has a second moving border')
            assert(skin.host:GetBottom()==Description:GetBottom() and skin.host:GetTop()==Description:GetTop())
            assert(eb:GetHeight()==260 and eb:GetText()=='one\ntwo\nthree' and eb.focused)
            assert(eb:GetScript('OnTextChanged')==fn)
            CreatePanel:Hide()
            assert(not skin.host:IsShown() and Description.Bg:GetAlpha()==1)
            local path,size=eb:GetFont(); assert(path=='stock' and size==13)
        """)

    def test_submenu_click_has_no_false_selection_fill(self):
        self.pages(); self.behavior()
        self.run_lua("ns.skip={}; ns.rows={}; ns.Track=function(t,v) t[v]=true end")
        self.lua.execute("assert(loadstring(...))('MeetingStoneEllesmereUI',ns)",
                         (regression.ROOT/'Widgets.lua').read_text(encoding='utf-8'))
        self.run_lua(r"""
            local row=CreateFrame('CheckButton',nil,main)
            row.CheckBox=row:CreateTexture(); row.Text=row:CreateFontString()
            row.SetCheckState=DropMenuItem.SetCheckState
            row:SetCheckState(false,false,false)
            local chosen=0; local owner={SetItem=function() chosen=chosen+1 end}
            local menu={GetOwner=function() return owner end,Hide=function() end}
            local data={notClickable=true,hasArrow=true,text='最近创建'}
            row.FireHandler=function(self) DropMenu.OnItemClick(menu,self,data) end
            row:SetScript('OnClick',DropMenuItem.OnClick)
            ns.SkinDropMenuItem(row); row:Click()
            assert(chosen==0)
            local d=ns.D(row)
            assert(not d.selBar or not d.selBar:IsShown(), 'submenu acquired a selected bar')
            assert(not d.selFill or d.selFill:GetAlpha()==0, 'submenu acquired a selected fill')
            assert(not row:GetChecked(), 'non-checkable menu row stayed checked after click')
        """)

    def test_ignore_bulk_button_selects_all_from_mixed_state(self):
        self.pages()
        self.run_lua(r"""
            setupTablePages()
            local p=IgnoreListPanel; local s=ns.D(p).tablePanel
            p.IgnoreList.buttons[1]['@'].Check:Click()
            assert(MEETINGSTONE_UI_DB.IGNORE_LIST[1].selected and not MEETINGSTONE_UI_DB.IGNORE_LIST[2].selected)
            s.select:Click()
            for _,v in ipairs(MEETINGSTONE_UI_DB.IGNORE_LIST) do assert(v.selected, 'bulk all button inverted mixed selection') end
            s.select:Click()
            for _,v in ipairs(MEETINGSTONE_UI_DB.IGNORE_LIST) do assert(not v.selected) end
        """)

    def recent(self):
        self.pages(); self.behavior()
        self.run_lua('Dropdown={}')
        self.lua.execute((regression.ROOT/'tests/fixtures/DropdownValues-20261002.lua').read_text(encoding='utf-8'))
        self.run_lua(r"""
            Recent.managers={}; Recent.groupManagers=setmetatable({},{__index=function(t,k) t[k]={}; return t[k] end})
            function seed(code,group,activity,name)
                local m={players={{name=name}},GetCategoryID=function() return group==0 and 6 or 2 end,
                    GetGroupID=function() return group end,GetActivityID=function() return activity end}
                function m:IteratePlayers() return ipairs(self.players) end
                function m:GetCode() return code end
                Recent.managers[code]=m
                Recent.groupManagers[code][m]=true
                Recent.groupManagers[(group==0 and '6' or '2')..'-0-0-0'][m]=true
            end
            seed('6-0-16-0',0,16,'custom'); seed('2-306-1176-0',306,1176,'season')
            seed('2-139-504-0',139,504,'old')
            local mod=ns.Module; ns.Module=function(n) return n=='Recent' and Recent or mod(n) end
            local p=RecentPanel; local dd=p.ActivityDropdown
            dd.SetMenuTable=Dropdown.SetMenuTable
            dd.GetMenuTable=Dropdown.GetMenuTable
            dd.GetValue=Dropdown.GetValue
            dd.SetItem=Dropdown.SetItem; dd.SetValue=Dropdown.SetValue
            dd.defaultValue=0
            dd:SetCallback('OnSelectChanged',function(_,data) p:SetActivity(data.value) end)
            p.Refresh=function(self) self:Update() end
            local nativeMenu={{text='自定义PVE',value='6-0-16-0'}}
            GetActivitesMenuTable=function() return nativeMenu end
            p:LFG_LIST_AVAILABILITY_UPDATE()
            p.MemberList.GetItemCount=function(self) return #self.items end
            Enum={LFGListFilter={CurrentSeason=8,PvE=1}}
            bit={bor=function() return 9 end}
            C_LFGList={GetAvailableActivityGroups=function() return {306} end}
        """)

    def test_recent_default_lists_all_actual_history(self):
        self.recent()
        self.run_lua(r"""
            setupTablePages(); RecentPanel:Update()
            assert(#RecentPanel.MemberList.items==3, 'default recent page did not include existing history')
            assert(RecentPanel.ActivityDropdown:GetItem().text=='全部活动')
        """)

    def test_recent_season_option_and_all_dungeons_use_existing_managers(self):
        self.recent()
        self.run_lua(r"""
            setupTablePages()
            local dd=RecentPanel.ActivityDropdown; local season,allDungeons
            for _,item in ipairs(dd:GetMenuTable()) do
                if item.text=='赛季地下城' then season=item end
                if item.text=='全部地下城（含历史）' then allDungeons=item end
            end
            assert(season, 'recent menu has no seasonal dungeon option')
            dd:SetItem(season); assert(#RecentPanel.MemberList.items==1 and RecentPanel.MemberList.items[1].name=='season')
            dd:SetItem(allDungeons); assert(#RecentPanel.MemberList.items==2)
            dd:SetItem({value='6-0-16-0'}); assert(#RecentPanel.MemberList.items==1 and RecentPanel.MemberList.items[1].name=='custom')
        """)


    def test_multiline_scroll_resize_reborrow_keep_fixed_border_and_restore(self):
        self.pages()
        self.run_lua(r"""
            Description.EditBox=CreatePanel.SummaryBox
            Description:SetPoint('TOPLEFT',SummaryCard,'TOPLEFT',10,-30)
            Description:SetPoint('BOTTOMRIGHT',SummaryCard,'BOTTOMRIGHT',-10,15)
            local f=CreatePanel.SummaryBox; f:SetHeight(240)
            f:SetPoint('TOPLEFT',Description,'TOPLEFT',0,0)
            setupTablePages()
            local skin=ns.D(Description).browseChrome
            local n=#frames
            for _,size in ipairs({12,18,14}) do
                ns.Set('labelFontSize',size); flush()
                main:SetHeight(500); setupTablePages()
                Description:SetVerticalScroll(100)
                assert((skin.host:GetTop()-skin.host:GetBottom())==Description:GetHeight())
                f:SetHeight(400); setupTablePages()
                assert(skin.host:GetBottom()>=SummaryCard:GetBottom())
                assert(f:GetHeight()==400 and Description:GetVerticalScroll()==100)
            end
            f:Disable(); flush(); assert(skin.host:GetAlpha()<1)
            f:Enable(); flush(); assert(skin.host:GetAlpha()==1)
            Description:SetParent(main)
            assert(not skin.host:IsShown())
            local path,size=f:GetFont(); assert(path=='stock' and size==13)
            Description:SetParent(SummaryCard); flush(); flush()
            assert(skin.host:IsShown() and #frames==n)
            assert(not Description.hooks.OnEnable, 'unsupported ScrollFrame script hooked')
        """)

    def test_menu_checkable_leaf_still_works_after_parent_row_reuse(self):
        self.pages(); self.behavior()
        self.run_lua('ns.skip={}')
        self.lua.execute("assert(loadstring(...))('MeetingStoneEllesmereUI',ns)",
                         (regression.ROOT/'Widgets.lua').read_text(encoding='utf-8'))
        self.run_lua(r"""
            local row=CreateFrame('CheckButton',nil,main)
            row.CheckBox=row:CreateTexture(); row.Text=row:CreateFontString()
            row.SetCheckState=DropMenuItem.SetCheckState
            row:SetCheckState(false,false,false); ns.SkinDropMenuItem(row)
            local chosen=0; local last
            local owner={SetItem=function(_,data) chosen=chosen+1; last=data end}
            local menu={GetOwner=function() return owner end,Hide=function() end}
            local data={value='specific-dungeon'}
            row.FireHandler=function(self) DropMenu.OnItemClick(menu,self,data) end
            row:SetScript('OnClick',DropMenuItem.OnClick)
            row:Click(); assert(chosen==1 and last==data and not row:GetChecked())
            data={value=0,checkable=true}; row:SetCheckState(true,false,false)
            row:Click(); assert(chosen==2 and row:GetChecked() and row.CheckBox:IsShown())
            row:SetCheckState(false,false,true)
            assert(not row:GetChecked() and not row.CheckBox:IsShown())
            local n=#frames; for i=1,30 do ns.SkinDropMenuItem(row) end
            assert(#frames==n)
        """)

    def test_recent_native_menu_refresh_keeps_filters_and_never_mutates_source(self):
        self.recent()
        self.run_lua(r"""
            local p=RecentPanel; local dd=p.ActivityDropdown
            local original=dd:GetMenuTable(); local changed=dd.callbacks.OnSelectChanged
            setupTablePages(); assert(#original==1 and #dd:GetMenuTable()==5)
            local objects=#frames; local update=p.Update
            dd:SetValue('mplus')
            for i=1,100 do
                p:LFG_LIST_AVAILABILITY_UPDATE(); setupTablePages()
                assert(#dd:GetMenuTable()==5 and #original==1 and p.code=='mplus')
            end
            assert(#frames==objects and p.Update==update and dd.callbacks.OnSelectChanged==changed)
            dd:SetValue('6-0-16-0'); setupTablePages()
            assert(p.code=='6-0-16-0' and #p.MemberList.items==1)
        """)

    def test_recent_aggregates_preserve_record_identity_and_native_delete_scope(self):
        self.recent()
        self.run_lua(r"""
            local p=RecentPanel
            local count=0
            for _,manager in pairs(Recent.managers) do
                for _,player in ipairs(manager.players) do
                    player.GetManager=function() return manager end
                    manager.RemoveUnit=function(self,v)
                        assert(self.players[1]==v); table.remove(self.players,1); count=count+1
                    end
                end
            end
            p.MemberList.GetItem=function(self,i) return self.items[i] end
            setupTablePages()
            local original=Recent.managers['2-306-1176-0'].players[1]
            p.ActivityDropdown:SetValue('mplus')
            assert(p.MemberList.items[1]==original, 'aggregate cloned the native record')
            p:BatchDelete(); p:Update()
            assert(count==1 and #p.MemberList.items==0)
            p.ActivityDropdown:SetValue(0)
            assert(#p.MemberList.items==2, 'season deletion removed unrelated records')
        """)

    def test_recent_missing_season_metadata_does_not_include_unrelated_history(self):
        self.recent()
        self.run_lua(r"""
            setupTablePages()
            C_LFGList=nil; RecentPanel.ActivityDropdown:SetValue('mplus')
            assert(#RecentPanel.MemberList.items==0)
            RecentPanel.ActivityDropdown:SetValue(0); assert(#RecentPanel.MemberList.items==3)
            C_LFGList={GetAvailableActivityGroups=function(category,flags)
                assert(category==2 and flags==9); return {139} end}
            RecentPanel.ActivityDropdown:SetValue('mplus')
            assert(#RecentPanel.MemberList.items==1 and RecentPanel.MemberList.items[1].name=='old')
        """)

    def test_ignore_empty_and_repeated_setup_do_not_install_multiple_callbacks(self):
        self.pages()
        self.run_lua(r"""
            setupTablePages(); local s=ns.D(IgnoreListPanel).tablePanel
            local click=s.select:GetScript('OnClick'); local n=#frames
            for i=1,30 do setupTablePages() end
            assert(s.select:GetScript('OnClick')==click and #frames==n)
            MEETINGSTONE_UI_DB.IGNORE_LIST={}; s.select:Click()
            assert(#MEETINGSTONE_UI_DB.IGNORE_LIST==0)
        """)

if __name__=='__main__': unittest.main()

