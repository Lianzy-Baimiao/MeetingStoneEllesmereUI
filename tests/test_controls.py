"""Presentation-only controls: exercise original callbacks and geometry."""
import unittest
import test_regressions as regression

class ControlsTests(unittest.TestCase):
    setUp=regression.RegressionTests.setUp
    run_lua=regression.RegressionTests.run_lua

    def test_switch_preserves_click_state_hitbox_and_programmatic_updates(self):
        self.run_lua('''
            local c=GUI:GetClass('CheckBox'):New(main); c:SetSize(20,20)
            c:SetText('需要坦克'); c:SetHitRectInsets(0,-48,0,0)
            c.CheckedTexture=c:CreateTexture(); c.NormalTexture=c:CreateTexture()
            local clicks=0; local cb=function() clicks=clicks+1 end
            c:SetScript('OnClick',cb)
            ns.SkinSwitch(c); local s=ns.D(c).switch
            assert(s and c:GetWidth()==20 and c.hitRect[2]==-48)
            assert(c:GetScript('OnClick')==cb and c.CheckedTexture:GetAlpha()==0)
            local off=s.knob:GetLeft(); c:Click()
            assert(clicks==1 and c:GetChecked() and s.knob:GetLeft()>off)
            c:SetChecked(false); assert(s.knob:GetLeft()==off and clicks==1)
            c:Disable(); assert(s.host:GetAlpha()<1); c:Click(); assert(clicks==1)
            c:Enable(); assert(s.host:GetAlpha()==1)
            local n=#frames; ns.SkinSwitch(c); assert(#frames==n)
            c:SetSize(32,22); c:RunScript('OnSizeChanged'); assert(s.host:GetWidth()==28)
        ''')

    def test_homepage_skins_actual_borrowed_search_without_rebinding(self):
        self.run_lua('''
            local sp=CreateFrame('Frame',nil,main)
            local eb=CreateFrame('EditBox',nil,browse); browse.SearchBox=eb
            eb:SetText('测试'); eb:SetPoint('LEFT',browse.ActivityDropdown,'RIGHT',20,0)
            eb.searchIcon=eb:CreateTexture(); eb.searchIcon:Hide()
            eb.Left=eb:CreateTexture(); eb.Instructions=eb:CreateFontString()
            local fn=function() end; eb:SetScript('OnTextChanged',fn); eb:SetFocus()
            local select=browse.ActivityDropdown.callbacks.OnSelectChanged
            ns.D(eb).skip=true
            browsePass()
            local skin=ns.D(eb).browseChrome
            assert(skin and skin.host:IsShown(), 'actual homepage SearchBox was not skinned')
            local dropdown=ns.D(browse.ActivityDropdown).browseChrome
            assert(dropdown and dropdown.host:IsShown())
            assert(eb:GetParent()==browse and eb.focused and eb:GetText()=='测试')
            assert(eb:GetScript('OnTextChanged')==fn and browse.ActivityDropdown.callbacks.OnSelectChanged==select)
            assert(eb.searchIcon:GetAlpha()==1 and not eb.searchIcon:IsShown())
            assert(eb.Left:GetAlpha()==0)
            eb:SetParent(browse); browse:Hide(); browse:Show(); browsePass()
            assert(ns.D(browse.ActivityDropdown).browseChrome==dropdown)
        ''')

    def test_only_actual_checkbox_art_is_recognized_for_raw_controls(self):
        self.run_lua(r'''
            local c=CreateFrame('CheckButton',nil,main)
            c.NormalTexture=c:CreateTexture()
            c.NormalTexture:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
            assert(ns.IsSwitchCheckbox(c))
            c:SetWidth(200); assert(not ns.IsSwitchCheckbox(c))
            c:SetWidth(20); c.NormalTexture:SetTexture('radio'); assert(not ns.IsSwitchCheckbox(c))
            c.NormalTexture:SetTexture('menu-tick'); assert(not ns.IsSwitchCheckbox(c))
        ''')

    def test_switch_rejected_save_reset_and_accent_changes(self):
        self.run_lua('''
            local c=GUI:GetClass('CheckBox'):New(main)
            c:SetScript('OnClick',function(self) self:SetChecked(false) end)
            ns.SkinSwitch(c); local s=ns.D(c).switch; local left=s.knob:GetLeft()
            c:Click(); assert(not c:GetChecked() and s.knob:GetLeft()==left)
            c:SetChecked(true); assert(s.knob:GetLeft()>left)
            UnitClass=function() return '战士','WARRIOR' end
            C_ClassColor={GetClassColor=function() return {r=.8,g=.2,b=.1} end}
            ns.Set('useClassColor',true)
            looksChanged(); assert(s.thumb[1].color[1]==.8)
            assert(s.track[1].color[1]==.18 and s.edge[1].color[1]==.22)
            c:SetChecked(false); assert(s.thumb[1].color[1]==.40)
            assert(s.track[1].color[1]==.10 and s.edge[1].color[1]==.22)
        ''')

    def test_stock_state_art_does_not_cover_switch_when_disabled(self):
        self.run_lua('''
            local c=GUI:GetClass('CheckBox'):New(main)
            c.DisabledCheckedTexture=c:CreateTexture()
            c:SetChecked(true); ns.SkinSwitch(c); c:Disable()
            assert(c.DisabledCheckedTexture:GetAlpha()==0)
            assert(ns.D(c).switch.knob:GetLeft()>ns.D(c).switch.host:GetLeft()+2)
        ''')

    def test_real_eui_primitives_coexist_with_reversible_search_layer_in_either_order(self):
        self.run_lua('''
            WSkin=ns.S; FadeRegions=ns.S.FadeRegions; GetFFD=ns.D
            Theme={bgR=.1,bgG=.1,bgB=.1,bgA=1}
            function SolidTex(f,layer,r,g,b,a)
                local t=f:CreateTexture(nil,layer); t:SetColorTexture(r,g,b,a); return t
            end
            function AddBorder(f) f.borders=(f.borders or 0)+1 end
            WSkin.White=function() end
        ''')
        self.lua.execute((regression.ROOT/'tests/fixtures/EUIControlPrimitives-20261001.lua').read_text(encoding='utf-8'))
        self.run_lua('''
            for _,alreadySkinned in ipairs({false,true}) do
                local p=CreateFrame('Frame',nil,main)
                p.ActivityDropdown=CreateFrame('Button',nil,p)
                p.ActivityDropdown.Text=p.ActivityDropdown:CreateFontString()
                p.ActivityDropdown.MenuButton=CreateFrame('Button',nil,p.ActivityDropdown)
                local mb=p.ActivityDropdown.MenuButton
                mb.NormalTexture=mb:CreateTexture(); local click=function() end
                mb:SetScript('OnClick',click)
                p.SearchBox=CreateFrame('EditBox',nil,p)
                local eb=p.SearchBox; eb.searchIcon=eb:CreateTexture(); eb.Left=eb:CreateTexture()
                if alreadySkinned then WSkin.EditBox(eb) end
                ns.SkinBrowseInputs(p); local skin=ns.D(eb).browseChrome
                assert(skin.host:IsShown() and eb.searchIcon:GetAlpha()==1 and eb.Left:GetAlpha()==0)
                WSkin.EditBox(eb); ns.SkinBrowseInputs(p); local bg=ns.D(eb).bg
                assert(bg and bg:GetAlpha()==0 and eb.borders==1)
                assert(eb.searchIcon:GetAlpha()==1)
                assert(ns.D(p.ActivityDropdown).browseChrome.arrow)
                assert(mb:GetScript('OnClick')==click and mb.NormalTexture:GetAlpha()==0)
                eb:SetParent(main)
                assert(not skin.host:IsShown() and bg:GetAlpha()==1)
                WSkin.EditBox(eb); assert(eb.borders==1)
            end
        ''')

    def test_widgets_dispatches_switch_without_painting_old_square(self):
        self.run_lua('ns.skip={}; ns.S.Checkbox=function() error("old square painter called") end')
        self.lua.execute("assert(loadstring(...))('MeetingStoneEllesmereUI',ns)",
                         (regression.ROOT/'Widgets.lua').read_text(encoding='utf-8'))
        self.run_lua('ns.SetLabelFonts=function() end')
        self.run_lua(r'''
            local c=CreateFrame('CheckButton',nil,main)
            c.NormalTexture=c:CreateTexture(); c.NormalTexture:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
            ns.SkinObject(c); assert(ns.D(c).switch)
            local n=#frames; ns.SkinObject(c); assert(#frames==n)
            local row=CreateFrame('CheckButton',nil,main); row:SetSize(300,22)
            ns.SkinObject(row); assert(not ns.D(row).switch)
        ''')

    def test_quick_filter_switches_mirror_original_saves_and_resets(self):
        self.run_lua('''
            browsePass(); local pair=ns.D(browse).roleBar[1]
            ns.SkinSwitch(pair.proxy); ns.SkinSwitch(pair.real.Check)
            pair.proxy:Click(); assert(pair.real.Check:GetChecked())
            local ps=ns.D(pair.proxy).switch; local rs=ns.D(pair.real.Check).switch
            assert(ps.knob:GetLeft()>ps.host:GetLeft()+2)
            assert(rs.knob:GetLeft()>rs.host:GetLeft()+2)
            pair.real.Check:SetChecked(false)
            assert(ps.knob:GetLeft()==ps.host:GetLeft()+2)
            assert(rs.knob:GetLeft()==rs.host:GetLeft()+2)
        ''')

if __name__=='__main__': unittest.main()
