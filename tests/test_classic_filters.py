"""Classic unified-filter regression; pinned native constructor and callbacks."""
import unittest
import test_regressions as fixtures


class ClassicFilterTests(unittest.TestCase):
    run_lua = fixtures.RegressionTests.run_lua

    def setUp(self):
        fixtures.RegressionTests.setUp(self)
        for name in ('classic_filters_mock.lua', 'fixtures/ClassicCheckBox-20260820.lua',
                     'fixtures/ClassicEXSearch-20260820.lua'):
            self.lua.execute((fixtures.ROOT / 'tests' / name).read_text(encoding='utf-8-sig'))

    def test_classic_dungeon_filters_appear_inside_unified_window(self):
        self.run_lua('''
            setupClassic(); browsePass(); browse.AdvButton:Click()
            local u = ns.D(browse).unifiedFilters
            assert(u.host:IsVisible(), 'unified filter window did not open')
            assert(browse.ExSearchPanel.Inset:IsVisible(),
                'classic dungeon filters missing from unified window')
            assert(browse.ExSearchPanel.Inset:GetParent() == u.content)
            for _, row in ipairs(browse.MD) do assert(row.Check:IsVisible()) end
        ''')

    def test_native_dungeon_callbacks_keep_mdsearchs_and_refresh(self):
        self.run_lua('''
            setupClassic()
            local row = browse.MD[1]
            local callback = row.Check:GetScript('OnClick')
            browsePass(); browse.AdvButton:Click()
            assert(row.Check:GetScript('OnClick') == callback)
            row.Check:Click()
            assert(browse.MDSearchs[396] and browse.ActivityList.refreshes == 1)
            row.Check:Click()
            assert(browse.MDSearchs == nil and browse.ActivityList.refreshes == 2)
            assert(browse.searches == 0, 'classic local filters forced a server search')
        ''')

    def test_native_class_need_avoid_and_separate_reset(self):
        self.run_lua('''
            setupClassic()
            local reset
            for _, child in ipairs({browse.ExSearchPanel:GetChildren()}) do
                if child:GetText() == '重置' then reset = child end
            end
            local callback = reset:GetScript('OnClick')
            browsePass(); browse.AdvButton:Click()
            local u = ns.D(browse).unifiedFilters
            assert(u.classicReset == reset and reset:IsVisible())
            assert(reset:GetScript('OnClick') == callback)
            browse.MD[1].Check:Click(); browse.MD[9].Check:Click()
            assert(MEETINGSTONE_UI_DB.CLASS1)
            local need, avoid = browse.MD[22].Check, browse.MD[23].Check
            avoid:Click()
            assert(not MEETINGSTONE_UI_DB.ClassNeed and not need:GetChecked() and avoid:GetChecked())
            need:Click()
            assert(MEETINGSTONE_UI_DB.ClassNeed and need:GetChecked() and not avoid:GetChecked())
            browse.ResetFilterButton:Click()
            assert(browse.MDSearchs[396] and MEETINGSTONE_UI_DB.CLASS1,
                'advanced reset cleared classic filters')
            for _, row in ipairs(browse.filters) do row.MinBox:SetNumber(123) end
            reset:Click()
            assert(browse.MDSearchs == nil and not MEETINGSTONE_UI_DB.CLASS1)
            assert(need:GetChecked() and not avoid:GetChecked() and MEETINGSTONE_UI_DB.ClassNeed)
            assert(MEETINGSTONE_UI_DB.FILTER_TANK, 'reset changed independent footer role state')
            for _, row in ipairs(browse.filters) do assert(row.MinBox:GetNumber() == 123) end
        ''')

    def test_real_late_ex_init_does_not_steal_the_unified_button(self):
        self.run_lua('''
            browsePass(); browse.AdvButton:Click()
            local u = ns.D(browse).unifiedFilters
            browse:EX_INIT()
            assert(u == ns.D(browse).unifiedFilters and u.host:IsVisible())
            assert(browse.ExSearchPanel.Inset:IsVisible())
            browse.AdvButton:Click()
            assert(not u.host:IsShown(), 'native EX_INIT replaced the unified toggle')
            browse.AdvButton:Click()
            assert(u.host:IsVisible() and browse.MD[1].Check:IsVisible())
            assert(not browse.ExSearchButton:IsVisible())
            browse:SwitchPanel(browse.ExSearchPanel)
            assert(not browse.ExSearchPanel:IsVisible(), 'second native shell leaked')
        ''')

    def test_category_switch_retains_native_shared_class_filters(self):
        self.run_lua('''
            setupClassic(); browsePass(); browse.AdvButton:Click()
            local u = ns.D(browse).unifiedFilters
            browse.MD[1].Check:Click(); browse.MD[9].Check:Click()
            for _, category in ipairs({3, 4, 6, 2}) do
                browse.ActivityDropdown:SetItem({value=category..'-0-0-0', categoryId=category})
                assert(browse.ExSearchPanel.Inset:IsVisible())
                assert(browse.MDSearchs[396] and MEETINGSTONE_UI_DB.CLASS1)
                assert(not u.dungeonAll:IsVisible() and not u.dungeonNone:IsVisible())
                assert(not u.empty:IsVisible())
            end
            u.close:Click()
            browse.ActivityDropdown:SetItem({value='2-0-0-0', categoryId=2})
            assert(not u.host:IsShown(), 'category change opened filters automatically')
        ''')

    def test_all_rows_and_reset_are_reachable_without_moving_footer_actions(self):
        self.run_lua('''
            setupClassic(); browsePass(); browse.AdvButton:Click()
            local u = ns.D(browse).unifiedFilters
            local lastY = -1
            for _, row in ipairs(browse.MD) do
                local _, parent, _, x, y = row:GetPoint()
                assert(parent == browse.ExSearchPanel.Inset and -y > lastY)
                assert(x >= 0 and x + row:GetWidth() <= u.content:GetWidth())
                lastY = -y
            end
            assert(u.content:GetHeight() > u.scroll:GetHeight())
            for i=1,100 do u.scroll:RunScript('OnMouseWheel', -1) end
            assert(u.scroll:GetVerticalScroll() == u.content:GetHeight() - u.scroll:GetHeight())
            u.advancedToggle:Click()
            assert(browse.AdvFilterPanel.Inset:IsVisible())
            u.advancedToggle:Click()
            assert(u.scroll:GetVerticalScroll() <= u.content:GetHeight() - u.scroll:GetHeight())
            assert(browse.RefreshFilterButton:GetParent() == u.host)
            assert(browse.ResetFilterButton:GetParent() == u.host)
            assert(u.classicReset:GetParent() == u.content)
        ''')

    def test_native_footer_role_checkboxes_survive_and_keep_callbacks(self):
        self.run_lua('''
            setupClassic()
            local tank
            for _, child in ipairs({browse:GetChildren()}) do
                if child:GetText() == '坦克' then tank = child end
            end
            local callback = tank:GetScript('OnClick')
            browsePass(); browse.AdvButton:Click()
            assert(tank:IsVisible() and tank:GetParent() == browse)
            assert(tank:GetScript('OnClick') == callback)
            tank:Click()
            assert(not MEETINGSTONE_UI_DB.FILTER_TANK and browse.ActivityList.refreshes == 1)
            assert(not ns.D(browse).roleBar, 'new-UI proxies replaced classic footer controls')
        ''')

    def test_apply_keeps_native_search_and_does_not_save_blizzard_filters(self):
        self.run_lua('''
            setupClassic(); browsePass(); browse.AdvButton:Click()
            browse.MD[1].Check:Click()
            browse.RefreshButton:Disable(); browse.RefreshFilterButton:Click()
            assert(browse.searches == 0)
            browse.RefreshButton:Enable(); browse.RefreshFilterButton:Click()
            assert(browse.searches == 1 and browse.MDSearchs[396])
        ''')

    def test_repeated_setup_is_idempotent_and_preserves_native_state(self):
        self.run_lua('''
            setupClassic(); browsePass(); browse.AdvButton:Click()
            local u = ns.D(browse).unifiedFilters
            local count, reset = #frames, u.classicReset
            browse.MD[1].Check:Click()
            for i=1,100 do
                ns.SetupUnifiedFilters(browse); ns.SyncUnifiedFilters(browse)
            end
            assert(#frames == count and u.classicReset == reset)
            assert(browse.MDSearchs[396] and browse.MD[1].Check:IsVisible())
            browse:Hide(); browse:Show()
            assert(browse.ExSearchPanel.Inset:IsVisible())
            browse.AdvButton:Click(); assert(not u.host:IsShown())
        ''')

    def test_unknown_panel_layout_keeps_usable_native_entry(self):
        self.run_lua('''
            setupClassic(); browse.ExSearchPanel.Inset = nil
            browsePass()
            assert(browse.ExSearchButton:IsVisible(), 'unadopted native entry was hidden')
            assert(browse.ExSearchButton:GetRight() < browse.AdvButton:GetLeft())
            assert(browse.RefreshButton:GetRight() < browse.ExSearchButton:GetLeft())
            browse.ExSearchButton:Click()
            assert(browse.ExSearchPanel:IsVisible())
        ''')
