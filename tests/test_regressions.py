"""Run: python -m unittest discover -s MeetingStoneEllesmereUI/tests -v
Requires lupa (Lua 5.1); no game, network, or live SavedVariables are used.
"""
from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

class RegressionTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((ROOT / 'tests/wow_mock.lua').read_text(encoding='utf-8-sig'))
        for name in ('Config.lua', 'Controls.lua', 'BrowseInputs.lua', 'BrowseJoinControls.lua', 'TablePanels.lua', 'UnifiedFilters.lua', 'SettingsLayout.lua', 'NativeSettings.lua', 'Panels.lua', 'Options.lua'):
            self.lua.execute("local source=...; assert(loadstring(source))('MeetingStoneEllesmereUI', ns)",
                             (ROOT / name).read_text(encoding='utf-8-sig'))

    def run_lua(self, source):
        self.lua.execute(source)

    def test_click_refreshes_results_after_saving_real_filter(self):
        self.run_lua('''
            browsePass()
            ns.D(browse).roleBar[1].proxy:Click(); flush()
            assert(browse.MD[1].saved==true, 'real EX filter was not saved')
            assert(browse.searches==1, 'quick filter did not refresh search results')
        ''')

    def test_shortcuts_follow_activity_not_popup_visibility(self):
        self.run_lua('''
            browsePass(); local proxy=ns.D(browse).roleBar[1].proxy
            assert(proxy:IsVisible())
            browse.BlzFilterPanel:Hide()
            assert(proxy:IsVisible(), 'closing dungeon search must not hide applicable shortcuts')
            proxy:Click(); assert(browse.MD[1].saved==true, 'hidden popup shortcut stopped working')
            browse.BlzFilterPanel:Show(); assert(proxy:IsVisible())
            browse.ActivityDropdown:SetValue('custom-pve')
            assert(not proxy:IsVisible(), 'shortcut leaked into custom PVE')
            browse.ActivityDropdown:SetValue('mplus'); assert(proxy:IsVisible())
        ''')

    def test_buttons_have_non_overlapping_bounds(self):
        self.run_lua('''
            browsePass()
            assert(browse.AdvButton:GetLeft()-browse.RefreshButton:GetRight()>=6,
                'filter and advanced-filter buttons overlap or lack a gap')
            assert(browse.AdvButton:GetRight()<=main:GetRight()-8, 'toolbar leaves window')
        ''')

    def test_options_have_readable_spacing(self):
        self.run_lua('''
            ns.SetupOptions(main)
            local u=ns.D(main.options).skinOptions
            assert(#u.rows==22 and #u.categories==3)
            for index,cat in ipairs(u.categories) do
                cat.button:Click(); local previous; local count=0
                for _,row in ipairs(u.rows) do
                    if row.frame:IsShown() then
                        if previous then assert(previous:GetTop()-row.frame:GetTop()>=56) end
                        previous=row.frame; count=count+1
                    end
                end
                assert(count==(index==1 and 8 or 7))
            end
        ''')

    def test_cooldown_coalesces_changes_and_uses_latest_state(self):
        self.run_lua('''
            browsePass(); local bar=ns.D(browse).roleBar
            bar[1].proxy:Click()
            bar[2].proxy:Click(); bar[1].proxy:Click()
            assert(browse.searches==1, 'bypassed the upstream cooldown')
            assert(browse.MD[1].saved==false and browse.MD[2].saved==true)
            assert(browse.ActivityList.refreshes==3, 'cached results were not refiltered')
            browse.RefreshButton:Enable(); flush()
            assert(browse.searches==2, 'latest filter state was not searched after cooldown')
            browse.RefreshButton:Enable(); flush()
            assert(browse.searches==2, 'duplicate refresh without pending changes')
        ''')

    def test_pending_search_does_not_leak_to_other_categories(self):
        self.run_lua('''
            browsePass(); browse.RefreshButton:Disable()
            ns.D(browse).roleBar[1].proxy:Click()
            browse.ActivityDropdown:SetValue('custom-pve')
            browse.RefreshButton:Enable(); flush()
            assert(browse.searches==0, 'pending role search ran in custom PVE')
            browse.ActivityDropdown:SetValue('mplus'); browsePass(); flush()
            assert(browse.searches==0, 'stale pending search survived a category switch')
        ''')

    def test_user_dropdown_selection_even_without_popup_transition(self):
        self.run_lua('''
            browsePass()
            browse.ActivityDropdown:SetCallback('OnSelectChanged', function() end)
            browse.ActivityDropdown:SetItem({value='custom-pve'})
            assert(not ns.D(browse).roleBar[1].proxy:IsVisible(), 'direct menu selection was not tracked')
        ''')

    def test_shortcut_toggle_is_live_and_preserves_filters(self):
        self.run_lua('''
            browsePass(); local bar=ns.D(browse).roleBar
            bar[1].proxy:Click()
            ns.Set('roleFilterBar', false)
            for _,pair in ipairs(bar) do assert(not pair.proxy:IsVisible()) end
            assert(browse.MD[1].saved==true)
            ns.Set('roleFilterBar', true)
            assert(bar[1].proxy:IsVisible() and bar[1].proxy:GetChecked())
            assert(#ns.D(browse).roleBar==5)
        ''')

    def test_option_initially_disabled_can_be_enabled_without_reload(self):
        self.run_lua('''
            ns.Set('roleFilterBar', false); browsePass()
            assert(not ns.D(browse).roleBar)
            ns.Set('roleFilterBar', true)
            assert(#ns.D(browse).roleBar==5)
        ''')

    def test_native_checkbox_and_programmatic_reset_stay_in_sync(self):
        self.run_lua('''
            browsePass(); local proxy=ns.D(browse).roleBar[1].proxy
            browse.MD[1].Check:Click(); assert(proxy:GetChecked())
            browse.MD[1].Check:SetChecked(false); assert(not proxy:GetChecked())
            assert(browse.searches==0, 'synchronizing state triggered an unwanted search')
        ''')

    def test_lazy_ex_init_while_browser_is_already_open(self):
        self.run_lua('''
            local md,filter,popup=browse.MD,browse.ExSearchButton,browse.BlzFilterPanel
            browse.MD=nil; browse.ExSearchButton=nil; browse.BlzFilterPanel=nil
            browse.EX_INIT=function(self) self.MD=md; self.ExSearchButton=filter; self.BlzFilterPanel=popup end
            browsePass(); assert(not ns.D(browse).roleBar)
            browse:EX_INIT()
            assert(#ns.D(browse).roleBar==5 and ns.D(browse).roleBar[1].proxy:IsVisible())
            assert(not filter:IsVisible()); assert(ns.D(browse).unifiedFilters)
            browsePass(); browsePass()
            assert(#md[1].Check.hooks.OnClick==1, 'duplicate click hooks')
        ''')

    def test_without_ex_keeps_advanced_conditions_accessible(self):
        self.run_lua('''
            browse.MD=nil; browse.ExSearchButton=nil; browse.BlzFilterPanel=nil
            browse.ExFilterPanel=nil
            browsePass(); assert(not ns.D(browse).roleBar)
            browse.AdvButton:Click(); ns.D(browse).unifiedFilters.advancedToggle:Click(); assert(browse.AdvFilterPanel.Inset:IsVisible())
        ''')

    def test_options_preserve_all_keys_and_value_conversions(self):
        self.run_lua('''
            local reads={}; local get=ns.Get
            ns.Get=function(key) reads[key]=true; return get(key) end
            ns.SetupOptions(main)
            local count=0; for key in pairs(ns.DEFAULTS) do
                assert(reads[key], 'missing option: '..key); count=count+1
            end
            assert(count==22)
            local nums={}; for _,f in ipairs(frames) do
                if f.widgetKind=='NumericBox' then table.insert(nums,f) end
            end
            nums[1]:SetNumber(75); assert(ns.Get('bgAlpha')==0.75)
            nums[8]:SetNumber(3); assert(ns.Get('fontDelta')==-3)
            ns.ResetAll(); assert(ns.Get('bgAlpha')==0.92 and ns.Get('fontDelta')==0)
            local options=main.options; ns.SetupOptions(main); assert(main.options==options)
        ''')

    def test_controls_and_captions_stay_inside_page_above_footer(self):
        self.run_lua('''
            ns.SetupOptions(main)
            local u=ns.D(main.options).skinOptions
            assert(u.scroll:GetBottom()>u.hint:GetTop())
            assert(u.scroll:GetTop()<u.subtitle:GetBottom())
            assert(u.nav:GetRight()<u.scroll:GetLeft())
            for _,cat in ipairs(u.categories) do
                cat.button:Click()
                for _,row in ipairs(u.rows) do if row.frame:IsShown() then
                    assert(row.label:GetRight()<row.control:GetLeft())
                    assert(row.label:GetStringWidth()<=row.label:GetWidth(), row.cfg.key)
                    assert(row.control:GetRight()<=u.content:GetRight()-12)
                end end
            end
            assert(u.content:GetHeight()>u.scroll:GetHeight())
        ''')

    def test_shortcuts_follow_individual_source_controls_not_ancestors(self):
        self.run_lua('''
            browsePass(); local bar=ns.D(browse).roleBar
            browse.BlzFilterPanel:Hide()
            assert(bar[1].proxy:IsVisible())
            browse.MD[1]:Hide()
            assert(not bar[1].proxy:IsVisible(), 'explicitly hidden source row was still mirrored')
            assert(bar[2].proxy:IsVisible(), 'hiding one source row hid all shortcuts')
            browse.MD[1]:Show(); assert(bar[1].proxy:IsVisible())
            browse.MD[1].Check:Hide(); assert(not bar[1].proxy:IsVisible())
            browse.MD[1].Check:Show(); assert(bar[1].proxy:IsVisible())
        ''')

    def test_shortcuts_are_built_even_when_dungeon_popup_starts_closed(self):
        self.run_lua('''
            browse.BlzFilterPanel:Hide(); browsePass()
            for _,pair in ipairs(ns.D(browse).roleBar) do assert(pair.proxy:IsVisible()) end
            browse.AdvButton:Click(); browse.AdvButton:Click()
            assert(not browse.BlzFilterPanel:IsVisible())
            assert(ns.D(browse).roleBar[1].proxy:IsVisible())
        ''')

    def test_auto_popup_suppression_does_not_suppress_shortcuts(self):
        self.run_lua('''
            ns.Set('noAutoFilterPopup',true)
            browse.LFG_LIST_AVAILABILITY_UPDATE=function(self) self.ActivityDropdown:SetValue('mplus') end
            browsePass(); browse:LFG_LIST_AVAILABILITY_UPDATE()
            assert(not browse.BlzFilterPanel:IsVisible())
            assert(ns.D(browse).roleBar[1].proxy:IsVisible())
        ''')

if __name__ == '__main__':
    unittest.main()

