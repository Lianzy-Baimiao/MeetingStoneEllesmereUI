"""Behavioral acceptance tests: execute the real unified UI, never game data."""
import unittest
import test_regressions as fixtures

class UnifiedFilterTests(unittest.TestCase):
    setUp = fixtures.RegressionTests.setUp
    run_lua = fixtures.RegressionTests.run_lua

    def test_one_entry_and_one_host_with_original_controls(self):
        self.run_lua('''
            browsePass(); local u=assert(ns.D(browse).unifiedFilters, 'unified UI not created')
            assert(browse.AdvButton:IsVisible() and not browse.ExSearchButton:IsVisible())
            assert(not u.host:IsVisible(), 'filters opened without a click')
            browse.AdvButton:Click()
            assert(u.host:IsVisible() and browse.BlzFilterPanel.Inset:IsVisible())
            assert(browse.MD[1]:GetParent()==browse.BlzFilterPanel.Inset, 'original controls replaced')
            for _,panel in ipairs({browse.BlzFilterPanel,browse.ExFilterPanel,browse.AdvFilterPanel}) do
                panel:Show(); assert(not panel:IsVisible(), 'old popup escaped its hidden parent')
            end
            assert(u.host:IsVisible())
        ''')

    def test_switch_activity_in_open_and_closed_window(self):
        self.run_lua('''
            browsePass(); local u=ns.D(browse).unifiedFilters
            browse.AdvButton:Click(); u.advancedToggle:Click()
            browse.ActivityDropdown:SetItem({value='custom-pve',categoryId=6})
            assert(u.host:IsVisible() and browse.ExFilterPanel.Inset:IsVisible())
            assert(not browse.BlzFilterPanel.Inset:IsVisible())
            assert(browse.AdvFilterPanel.Inset:IsVisible(), 'type switch collapsed advanced section')
            assert(not ns.D(browse).roleBar[1].proxy:IsVisible())
            u.close:Click(); browse.ActivityDropdown:SetItem({value='mplus',categoryId=2})
            assert(not u.host:IsVisible(), 'category selection reopened the window')
            assert(ns.D(browse).roleBar[1].proxy:IsVisible())
            browse.AdvButton:Click(); assert(browse.BlzFilterPanel.Inset:IsVisible())
        ''')

    def test_closing_keeps_shortcuts_and_saved_conditions(self):
        self.run_lua('''
            browsePass(); local u=ns.D(browse).unifiedFilters
            browse.AdvButton:Click(); browse.MD[1].Check:Click(); u.close:Click()
            assert(browse.MD[1].saved and not u.host:IsVisible())
            local proxy=ns.D(browse).roleBar[1].proxy
            assert(proxy:IsVisible() and proxy:GetChecked()); proxy:Click()
            assert(browse.MD[1].saved==false and browse.searches==1)
        ''')

    def test_advanced_reset_only_clears_advanced(self):
        self.run_lua('''
            browsePass(); local u=ns.D(browse).unifiedFilters
            browse.AdvButton:Click(); u.advancedToggle:Click()
            assert(browse.AdvFilterPanel.Inset:IsVisible())
            browse.MD[1].Check:Click(); browse.filters[1].MinBox:SetNumber(2000)
            browse.ResetFilterButton:Click()
            for _,row in ipairs(browse.filters) do assert(row.cleared) end
            assert(browse.MD[1].saved and browse.MD[1].Check:GetChecked())
            u.advancedToggle:Click(); assert(not browse.AdvFilterPanel.Inset:IsVisible())
        ''')

    def test_unified_apply_saves_dungeon_state_before_search(self):
        self.run_lua('''
            browsePass(); browse.AdvButton:Click(); browse.rating=1800
            browse.RefreshFilterButton:Click()
            assert(browse.savedRating==1800 and browse.saves==1, 'minimum rating bypassed native save')
            assert(browse.searches==1)
            browse.RefreshFilterButton:Click(); assert(browse.searches==1, 'cooldown bypassed')
            browse.RefreshButton:Enable(); browse.RefreshFilterButton:Enable(); flush()
            browse.ActivityDropdown:SetItem({value='custom-pve',categoryId=6})
            browse.RefreshFilterButton:Click()
            assert(browse.searches==2 and browse.saves==1, 'party search invoked dungeon save')
        ''')

    def test_category_values_load_without_opening_popup(self):
        self.run_lua('''
            browse.savedCategories[2]=2000; browse.savedCategories[6]=100
            browsePass(); browse.AdvButton:Click()
            assert(browse.loadedCategory==2 and browse.filters[1].MinBox:GetNumber()==2000)
            browse.ActivityDropdown:SetItem({value='custom-pve',categoryId=6})
            assert(browse.loadedCategory==6 and browse.filters[1].MinBox:GetNumber()==100)
            browse.ActivityDropdown:SetItem({value='mplus',categoryId=2})
            assert(browse.filters[1].MinBox:GetNumber()==2000)
        ''')

    def test_long_content_scrolls_and_collapsing_clamps_scroll(self):
        self.run_lua('''
            for i=1,25 do
                local row=CreateFrame('Frame',nil,browse.BlzFilterPanel.Inset); row:SetHeight(20)
                row.Check=GUI:GetClass('CheckBox'):New(row); table.insert(browse.MD,row)
            end
            browsePass(); local u=ns.D(browse).unifiedFilters
            browse.AdvButton:Click(); u.advancedToggle:Click()
            assert(u.host:GetHeight()<=main:GetHeight())
            assert(u.content:GetHeight()>u.scroll:GetHeight())
            assert(u.advancedToggle:GetParent()==u.host, 'advanced entry scrolled out of reach')
            u.scroll:RunScript('OnMouseWheel',-100)
            assert(u.scroll:GetVerticalScroll()>0)
            browse.ActivityDropdown:SetItem({value='custom-pve',categoryId=6})
            u.advancedToggle:Click()
            assert(u.scroll:GetVerticalScroll()<=math.max(0,u.content:GetHeight()-u.scroll:GetHeight()))
            assert(browse.RefreshFilterButton:IsVisible(), 'apply must stay outside scrolling content')
        ''')

    def test_roll_tool_and_late_ex_init(self):
        self.run_lua('''
            local md,blz,ex,button=browse.MD,browse.BlzFilterPanel,browse.ExFilterPanel,browse.ExSearchButton
            blz:Hide(); ex:Hide(); button:Hide()
            browse.MD=nil; browse.BlzFilterPanel=nil; browse.ExFilterPanel=nil; browse.ExSearchButton=nil
            browse.EX_INIT=function(self)
                self.MD=md; self.BlzFilterPanel=blz; self.ExFilterPanel=ex; self.ExSearchButton=button
            end
            browsePass(); local u=ns.D(browse).unifiedFilters; browse.AdvButton:Click()
            assert(u.host:IsVisible()); browse:EX_INIT()
            assert(u==ns.D(browse).unifiedFilters and u.host:IsVisible())
            assert(blz.Inset:IsVisible() and browse.rollButton:IsVisible())
            browse.rollButton:Click(); assert(browse.rollClicks==1)
            assert(not button:IsVisible() and not blz:IsVisible())
        ''')

    def test_repeated_setup_does_not_duplicate_or_reload_edits(self):
        self.run_lua('''
            browsePass(); local u=ns.D(browse).unifiedFilters; browse.AdvButton:Click()
            browse.filters[1].MinBox:SetNumber(1234)
            local count=#frames; local hooks=#browse.MD[1].Check.hooks.OnClick
            for i=1,5 do browsePass() end
            assert(#frames==count and #browse.MD[1].Check.hooks.OnClick==hooks)
            assert(browse.filters[1].MinBox:GetNumber()==1234, 'layout reload erased an edit')
            browse.AdvButton:Click(); assert(not u.host:IsVisible())
            browse.AdvButton:Click(); assert(u.host:IsVisible())
        ''')

    def test_repeated_type_switches_never_expose_old_shells(self):
        self.run_lua('''
            browsePass(); local u=ns.D(browse).unifiedFilters
            for i=1,100 do
                if i%7==0 then browse.AdvButton:Click() end
                if i%5==0 then u.advancedToggle:Click() end
                local shown=u.host:IsShown()
                browse.ActivityDropdown:SetItem({value=i%2==0 and 'mplus' or 'custom-pve',categoryId=i%2==0 and 2 or 6})
                assert(u.host:IsShown()==shown, 'type switch changed window visibility')
                for _,panel in ipairs({browse.BlzFilterPanel,browse.ExFilterPanel,browse.AdvFilterPanel}) do
                    assert(not panel:IsVisible(), 'old popup overlapped unified host')
                end
                assert(ns.D(browse).roleBar[1].proxy:IsVisible()==(i%2==0))
            end
        ''')

    def test_native_cooldown_and_pending_shortcut_share_one_apply(self):
        self.run_lua('''
            browsePass(); browse.AdvButton:Click()
            browse.RefreshFilterButton:Click()
            ns.D(browse).roleBar[1].proxy:Click()
            assert(browse.searches==1 and not browse.RefreshFilterButton:IsEnabled())
            browse.RefreshButton:Enable(); browse.RefreshFilterButton:Enable(); flush()
            assert(browse.searches==2 and not browse.RefreshFilterButton:IsEnabled())
            browse.RefreshFilterButton:Click(); assert(browse.searches==2)
        ''')

    def test_no_auto_popup_option_or_shortcuts_required(self):
        self.run_lua('''
            ns.Set('noAutoFilterPopup',true); ns.Set('roleFilterBar',false)
            browse.LFG_LIST_AVAILABILITY_UPDATE=function(self) self.ActivityDropdown:SetValue('mplus') end
            browsePass(); browse.AdvButton:Click(); local u=ns.D(browse).unifiedFilters
            browse:LFG_LIST_AVAILABILITY_UPDATE()
            assert(u.host:IsVisible() and browse.BlzFilterPanel.Inset:IsVisible())
            assert(not browse.BlzFilterPanel:IsVisible())
            for _,pair in ipairs(ns.D(browse).roleBar or {}) do assert(not pair.proxy:IsVisible()) end
        ''')

if __name__ == '__main__':
    unittest.main()
