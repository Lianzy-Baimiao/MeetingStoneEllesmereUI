"""Explicit homepage paint, stock art reapplication and borrowed ownership."""
import unittest
import test_regressions as regression

class BrowseChromeTests(unittest.TestCase):
    setUp=regression.RegressionTests.setUp
    run_lua=regression.RegressionTests.run_lua

    def setup_controls(self):
        self.run_lua("""
            sp=CreateFrame('Frame',nil,main)
            eb=CreateFrame('EditBox',nil,browse); browse.SearchBox=eb
            eb.Left=eb:CreateTexture(); eb.Left:SetAlpha(.8)
            eb.searchIcon=eb:CreateTexture(); eb.searchIcon:Hide()
            eb:SetText('test'); eb:SetFocus()
            entered=function() end; eb:SetScript('OnEnterPressed',entered)
            dd=browse.ActivityDropdown; dd.Stock=dd:CreateTexture()
            dd.MenuButton=CreateFrame('Button',nil,dd)
            dd.MenuButton.NormalTexture=dd.MenuButton:CreateTexture()
            clicked=function() end; dd.MenuButton:SetScript('OnClick',clicked)
        """)

    def test_repaint_after_stock_textures_are_reapplied(self):
        self.setup_controls()
        self.run_lua("""
            ns.SkinBrowseInputs(browse); eb.Left:SetAlpha(1); dd.Stock:SetAlpha(1)
            dd.MenuButton.NormalTexture:SetAlpha(1)
            browse:Hide(); browse:Show(); browsePass(); flush()
            assert(eb.Left:GetAlpha()==0, 'search stock art survived reopening')
            assert(dd.Stock:GetAlpha()==0, 'dropdown stock art survived reopening')
            assert(dd.MenuButton.NormalTexture:GetAlpha()==0)
        """)

    def test_explicit_paint_does_not_depend_on_primitive_guard_or_prior_mark(self):
        self.setup_controls()
        self.run_lua("""
            ns.S.EditBox=function() end; ns.S.Dropdown=function() end
            ns.Mark(dd) -- an earlier generic pass is not proof it has a dropdown skin
            ns.SkinBrowseInputs(browse)
            assert(eb.Left:GetAlpha()==0 and dd.Stock:GetAlpha()==0, 'facade call did not paint inputs')
            assert(ns.D(eb).browseChrome.host:IsShown())
            assert(ns.D(dd).browseChrome.host:IsShown())
            assert(eb:GetScript('OnEnterPressed')==entered and dd.MenuButton:GetScript('OnClick')==clicked)
            assert(eb:GetText()=='test' and eb.focused and not eb.searchIcon:IsShown())
        """)

    def test_return_to_blizzard_restores_art_and_hides_only_our_layer(self):
        self.setup_controls()
        self.run_lua("""
            ns.SkinBrowseInputs(browse); local layer=assert(ns.D(eb).browseChrome)
            eb:SetParent(sp)
            assert(not layer.host:IsShown() and eb.Left:GetAlpha()==.8)
            eb.Left:SetAlpha(.4); ns.SkinBrowseInputs(browse)
            assert(eb.Left:GetAlpha()==.4, 'modified search while another panel owns it')
            eb:SetParent(browse); assert(layer.host:IsShown() and eb.Left:GetAlpha()==0)
            eb:SetParent(sp); assert(eb.Left:GetAlpha()==.4)
        """)

    def test_repeated_show_and_borrow_reuses_controls_hooks_and_timers(self):
        self.setup_controls()
        self.run_lua("""
            ns.SkinBrowseInputs(browse); flush()
            local function count()
                local n=0; for _,f in ipairs(frames) do for _,h in pairs(f.hooks) do n=n+#h end end
                return n
            end
            local objects,hooks=#frames,count()
            for i=1,300 do
                eb:SetParent(sp); eb:SetParent(browse)
                ns.SkinBrowseInputs(browse); flush()
            end
            assert(#frames==objects and count()==hooks, 'chrome accumulates controls or hooks')
            assert(#C_Timer.pending==0)
        """)


    def test_real_browse_ownership_scripts_keep_anchors_and_restore_on_hide(self):
        self.setup_controls()
        self.run_lua("""
            BrowsePanel=browse
            LFGListFrame={SearchPanel=sp}; sp.CategoryName=sp:CreateFontString()
        """)
        self.lua.execute((regression.ROOT/'tests/fixtures/BrowseOwnership-20261001.lua').read_text(encoding='utf-8'))
        self.run_lua("""
            browse:SetScript('OnShow',browse.OnShow); browse:SetScript('OnHide',browse.OnHide)
            browse:Hide(); ns.SkinBrowseInputs(browse); flush()
            assert(eb:GetParent()==sp and eb:GetWidth()==319 and eb.Left:GetAlpha()==.8)
            browse:Show(); flush()
            assert(eb:GetParent()==browse and eb:GetWidth()==220 and eb.Left:GetAlpha()==0)
            local point,relative=eb:GetPoint(); assert(point=='LEFT' and relative==dd)
            browse:Hide(); flush()
            assert(eb:GetParent()==sp and eb:GetWidth()==319 and eb.Left:GetAlpha()==.8)
            assert(not ns.D(eb).browseChrome.host:IsShown())
        """)

    def test_deferred_refresh_catches_later_onshow_art_without_stale_takeover(self):
        self.setup_controls()
        self.run_lua("""
            browsePass(); flush()
            browse:HookScript('OnShow',function() dd.Stock:SetAlpha(1); eb.Left:SetAlpha(1) end)
            browse:Hide(); browse:Show(); flush()
            assert(dd.Stock:GetAlpha()==0 and eb.Left:GetAlpha()==0)
            browse:Hide(); eb:SetParent(sp); ns.SkinBrowseInputs(browse)
            local alpha=eb.Left:GetAlpha(); flush()
            assert(eb.Left:GetAlpha()==alpha and not ns.D(eb).browseChrome.host:IsShown())
        """)

if __name__=='__main__': unittest.main()
