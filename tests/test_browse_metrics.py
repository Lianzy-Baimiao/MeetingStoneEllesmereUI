"""Screenshot regression: matching visible heights at the real borrow/return seam.

Dropdown 170x26 comes from installed BrowsePanel. Search 18px is a
screenshot-derived test input, not a claim to load Blizzard's XML template.
"""
import unittest
import test_regressions as regression


class BrowseMetricsTests(unittest.TestCase):
    setUp = regression.RegressionTests.setUp
    run_lua = regression.RegressionTests.run_lua

    def setup_borrow(self):
        self.run_lua("""
            sp=CreateFrame('Frame',nil,main)
            sp.CategoryName=sp:CreateFontString()
            eb=CreateFrame('EditBox',nil,sp); browse.SearchBox=eb
            eb:SetSize(319,18)
            eb.Left=eb:CreateTexture()
            eb.Instructions=eb:CreateFontString()
            dd=browse.ActivityDropdown; dd:SetSize(170,26)
            dd:SetPoint('TOPLEFT',browse,'TOPLEFT',20,-40)
            dd.Text=dd:CreateFontString()
            dd.MenuButton=CreateFrame('Button',nil,dd)
            LFGListFrame={SearchPanel=sp}; BrowsePanel=browse
        """)
        self.lua.execute((regression.ROOT/'tests/fixtures/BrowseOwnership-20261001.lua').read_text(encoding='utf-8'))
        self.run_lua("""
            browse:SetScript('OnShow',browse.OnShow)
            browse:SetScript('OnHide',browse.OnHide)
            browse:Hide(); ns.SkinBrowseInputs(browse); flush()
        """)

    def test_borrow_matches_control_and_visible_bounds_then_restores_height(self):
        self.setup_borrow()
        self.run_lua("""
            browse:Show(); flush()
            assert(eb:GetHeight()==dd:GetHeight(), 'homepage height mismatch: search='..eb:GetHeight()..', dropdown='..dd:GetHeight())
            local search=ns.D(eb).browseChrome.host
            local dropdown=ns.D(dd).browseChrome.host
            assert(search:GetTop()==dropdown:GetTop() and search:GetBottom()==dropdown:GetBottom(), 'painted top/bottom do not align')
            assert(eb:GetTop()==dd:GetTop() and eb:GetBottom()==dd:GetBottom(), 'hitboxes do not align')
            assert(eb:GetWidth()==220 and dd:GetWidth()==170)
            local point,relative,relpoint,x,y=eb:GetPoint()
            assert(point=='LEFT' and relative==dd and relpoint=='RIGHT' and x==20 and y==0)
            browse:Hide(); flush()
            assert(eb:GetParent()==sp and eb:GetHeight()==18 and eb:GetWidth()==319, 'borrowed geometry not restored')
        """)

    def test_resize_and_reborrow_use_latest_native_height_without_growth(self):
        self.setup_borrow()
        self.run_lua("""
            browse:Show(); flush()
            dd:SetSize(170,30)
            assert(eb:GetHeight()==30, 'search did not follow dropdown height')
            browse:Hide(); flush(); assert(eb:GetHeight()==18)
            eb:SetHeight(22)
            local objects=#frames
            for i=1,50 do
                browse:Show(); ns.SkinBrowseInputs(browse); flush()
                assert(eb:GetHeight()==30)
                browse:Hide(); flush(); assert(eb:GetHeight()==22)
            end
            assert(#frames==objects and #C_Timer.pending==0)
        """)

    def setup_fonts(self):
        # Load the actual shared label-font builder, not a no-op font facade.
        self.lua.execute("local source=...; assert(loadstring(source))('MeetingStoneEllesmereUI',ns)",
                         (regression.ROOT/'Widgets.lua').read_text(encoding='utf-8'))
        self.setup_borrow()
        self.run_lua("""
            eb:SetFont('Fonts/input.ttf',14,'OUTLINE')
            eb.Instructions:SetFont('Fonts/hint.ttf',15,'THICKOUTLINE')
            eb:SetText('keep query'); eb:SetFocus()
            eb.Instructions:SetText('search'); eb.Instructions:SetTextColor(.5,.5,.5)
            nativeObject=CreateFont('NativeSearchFont'); eb:SetFontObject(nativeObject)
            nativeChanged=function() end; eb:SetScript('OnTextChanged',nativeChanged)
        """)

    def test_input_hint_and_dropdown_use_same_metrics_live_and_restore(self):
        self.setup_fonts()
        self.run_lua("""
            browse:Show(); flush()
            local path,size,flags=dd.Text:GetFont()
            local ep,es,ef=eb:GetFont(); local hp,hs,hf=eb.Instructions:GetFont()
            assert(es==size and hs==size, 'search and dropdown font sizes differ')
            assert(ep==path and hp==path and ef==flags and hf==flags, 'search font face/outline not harmonized')
            ns.Set('labelFontSize',16)
            local _,s=dd.Text:GetFont(); local _,e=eb:GetFont(); local _,h=eb.Instructions:GetFont()
            assert(s==16 and e==16 and h==16, 'label font setting not applied live')
            browse:Hide(); flush()
            ep,es,ef=eb:GetFont(); hp,hs,hf=eb.Instructions:GetFont()
            assert(ep=='Fonts/input.ttf' and es==14 and ef=='OUTLINE')
            assert(hp=='Fonts/hint.ttf' and hs==15 and hf=='THICKOUTLINE')
            assert(eb:GetFontObject()==nativeObject and not ns.D(eb.Instructions).claimed)
            assert(eb:GetText()=='keep query' and eb.focused and eb:GetScript('OnTextChanged')==nativeChanged)
            ns.Set('labelFontSize',12)
            local _,e=eb:GetFont(); assert(e==14, 'setting changed font while Blizzard owns search')
            eb:SetFont('Fonts/foreign.ttf',17,'MONOCHROME')
            browse:Show(); flush(); browse:Hide(); flush()
            ep,es,ef=eb:GetFont()
            assert(ep=='Fonts/foreign.ttf' and es==17 and ef=='MONOCHROME', 'reborrow restored stale font')
        """)

    def test_hidden_page_does_not_resize_or_font_shared_input(self):
        self.setup_fonts()
        self.run_lua("""
            ns.SkinBrowseInputs(browse); flush()
            local path,size=eb:GetFont()
            assert(path=='Fonts/input.ttf' and size==14 and eb:GetHeight()==18)
            assert(not ns.D(eb.Instructions).claimed)
            browse:Show(); browse:Hide(); flush()
            path,size=eb:GetFont()
            assert(path=='Fonts/input.ttf' and size==14 and eb:GetHeight()==18)
        """)

    def test_theme_font_and_late_native_onshow_repaint(self):
        self.setup_fonts()
        self.run_lua("""
            browse:HookScript('OnShow',function()
                eb:SetHeight(18); eb:SetFont('Fonts/stock.ttf',14,'OUTLINE')
                eb.Instructions:SetFont('Fonts/stock.ttf',14,'OUTLINE')
            end)
            browse:Show(); flush()
            local _,size,flags=eb:GetFont()
            assert(eb:GetHeight()==26 and size==12 and flags=='')
            ns.S.GetFont=function() return 'Fonts/new-theme.ttf','MONOCHROME' end
            ns.RefreshAll()
            local dp,ds,df=dd.Text:GetFont(); local ep,es,ef=eb:GetFont()
            assert(dp==ep and ds==es and df==ef and ep=='Fonts/new-theme.ttf')
            -- A blanket fontDelta pass must not leave a previously tracked hint
            -- at its native-size-plus-delta instead of the common label size.
            ns.ApplyFonts=function() eb.Instructions:SetFont('Fonts/stock.ttf',20,'OUTLINE') end
            ns.Set('fontDelta',2)
            local hp,hs,hf=eb.Instructions:GetFont()
            assert(hp==ep and hs==es and hf==ef)
            browse:Hide(); flush()
            ep,es,ef=eb:GetFont()
            assert(ep=='Fonts/input.ttf' and es==14 and ef=='OUTLINE')
        """)

    def test_direct_reparent_and_effective_scale_keep_rendered_metrics(self):
        self.setup_fonts()
        self.run_lua("""
            dd.GetEffectiveScale=function() return 1.5 end
            eb.GetEffectiveScale=function() return .75 end
            browse:Show(); flush()
            assert(eb:GetHeight()*.75==dd:GetHeight()*1.5)
            local _,e=eb:GetFont(); local _,d=dd.Text:GetFont()
            assert(e*.75==d*1.5)
            eb:SetParent(sp); flush()
            local ep,es,ef=eb:GetFont()
            assert(eb:GetHeight()==18 and ep=='Fonts/input.ttf' and es==14 and ef=='OUTLINE')
            assert(not ns.D(eb).browseChrome.host:IsShown() and browse:IsVisible())
            eb:SetHeight(21); eb:SetParent(browse); flush()
            assert(eb:GetHeight()==52)
            eb.GetEffectiveScale=function() return 1.5 end
            ns.ApplyBrowseInputs()
            assert(eb:GetHeight()==26)
            eb:SetParent(sp); assert(eb:GetHeight()==21)
        """)


if __name__ == '__main__':
    unittest.main()
