"""Fixed logo green vs player class colour; borders are always dark."""
import unittest
import test_regressions as regression
import test_browse_chrome as browse_tests


class AccentStyleTests(unittest.TestCase):
    run_lua = regression.RegressionTests.run_lua

    def setUp(self):
        regression.RegressionTests.setUp(self)
        source = (regression.ROOT / 'Core.lua').read_text(encoding='utf-8-sig')
        self.lua.execute('local ns=ns; '+source[source.index('local accents ='):source.index('local FONT_MIN')])
        self.lua.execute('local ns=ns; '+source[source.index('function ns.Tex('):source.index('-- Alpha a texture')])
        self.run_lua("""
            GREEN={12/255,210/255,157/255}
            UnitClass=function() return '法师','MAGE' end
            C_ClassColor={GetClassColor=function(token)
                if token=='MAGE' then return {r=.25,g=.78,b=.92} end
            end}
            function sameColor(tex,r,g,b,a)
                local c=assert(tex.color)
                assert(c[1]==r and c[2]==g and c[3]==b and c[4]==(a or 1),
                    'unexpected colour '..table.concat(c,','))
            end
            function green(tex,a) sameColor(tex,GREEN[1],GREEN[2],GREEN[3],a) end
            function dark(tex) sameColor(tex,.22,.22,.22) end
            -- This setting must not inherit even a class-coloured EUI theme.
            ns.S.GetAccentColor=function() error('EUI live theme must not be queried') end
        """)

    def test_default_green_and_opt_in_class_with_fallbacks(self):
        self.run_lua("""
            assert(ns.Get('useClassColor')==false and ns.DEFAULTS.useThemeColor==nil)
            local t=main:CreateTexture(); ns.Accent(t); green(t)
            ns.Set('useClassColor',true); sameColor(t,.25,.78,.92)
            C_ClassColor=nil; RAID_CLASS_COLORS={MAGE={r=.4,g=.6,b=.8}}
            ns.RefreshAccentStyle(); sameColor(t,.4,.6,.8)
            RAID_CLASS_COLORS=nil; ns.RefreshAccentStyle(); green(t)
            UnitClass=function() return nil end; ns.RefreshAccentStyle(); green(t)
            UnitClass=nil; ns.RefreshAccentStyle(); green(t)
        """)

    def test_old_theme_setting_does_not_enable_class_colour(self):
        self.run_lua("""
            for _,value in ipairs({true,false}) do
                MeetingStoneEllesmereUIDB={useThemeColor=value,bgAlpha=.75}
                assert(ns.Get('useClassColor')==false and ns.Get('bgAlpha')==.75)
                local t=main:CreateTexture(); ns.Accent(t); green(t)
            end
            ns.SetupOptions(main); local u=ns.D(main.options).skinOptions
            assert(not u.byKey.useThemeColor and not u.byKey.useClassColor.control:GetChecked())
        """)

    def test_real_option_click_recolours_selected_square_not_borders(self):
        browse_tests.BrowseChromeTests.setup_controls(self)
        self.run_lua("""
            ns.SkinBrowseInputs(browse); ns.SetupOptions(main)
            local u=ns.D(main.options).skinOptions; local row=assert(u.byKey.useClassColor)
            assert(row.label:GetText()=='选中状态使用职业色' and row.hint:GetText():find('边框'))
            local c=GUI:GetClass('CheckBox'):New(main); c:SetChecked(true); ns.SkinSwitch(c)
            local s=ns.D(c).switch; local mark=main:CreateTexture(); ns.Accent(mark,.08)
            green(s.thumb[1]); green(mark,.08); dark(s.edge[1])
            for _,edge in ipairs(ns.D(eb).browseChrome.edges) do dark(edge) end
            row.control:Click(); assert(ns.Get('useClassColor'))
            sameColor(s.thumb[1],.25,.78,.92); sameColor(mark,.25,.78,.92,.08)
            dark(s.edge[1]); for _,edge in ipairs(ns.D(eb).browseChrome.edges) do dark(edge) end
            row.control:Click(); green(s.thumb[1]); green(mark,.08)
            dark(s.edge[1]); for _,edge in ipairs(ns.D(eb).browseChrome.edges) do dark(edge) end
        """)

    def test_switch_unchecked_square_stays_grey_in_both_modes(self):
        self.run_lua("""
            local c=GUI:GetClass('CheckBox'):New(main); c:SetSize(32,22); ns.SkinSwitch(c)
            local s=ns.D(c).switch
            for _,mode in ipairs({false,true}) do
                ns.Set('useClassColor',mode); sameColor(s.thumb[1],.40,.40,.40)
                sameColor(s.track[1],.10,.10,.10); dark(s.edge[1])
                c:Click(); sameColor(s.track[1],.18,.18,.18); dark(s.edge[1])
                if mode then sameColor(s.thumb[1],.25,.78,.92) else green(s.thumb[1]) end
                c:Disable(); assert(s.host:GetAlpha()==.4 and c:GetChecked())
                c:Enable(); c:Click()
            end
        """)

    def test_multiselect_fill_follows_colour_but_card_and_checkbox_edges_do_not(self):
        self.run_lua("""
            local card=CreateFrame('Frame',nil,main); ns.SetControlChrome(card,true)
            local view=CreateFrame('Frame',nil,main); ns.D(view).selectionList=true
            local c=GUI:GetClass('CheckBox'):New(view); c:SetChecked(true); ns.SkinSwitch(c)
            local s=ns.D(c).switch; green(s.track[1]); dark(s.edge[1])
            assert(s.selection and s.tick:IsShown() and not s.knob:IsShown())
            ns.Set('useClassColor',true); sameColor(s.track[1],.25,.78,.92); dark(s.edge[1])
            for _,edge in ipairs(ns.D(card).browseChrome.edges) do dark(edge) end
            c:SetChecked(false); sameColor(s.track[1],.10,.10,.10); dark(s.edge[1])
            assert(not s.tick:IsShown() and s.host:GetWidth()==s.host:GetHeight())
        """)

    def test_both_settings_navigation_marks_repaint(self):
        for name in ('native_settings_mock.lua','fixtures/OptionPanel-20261001.lua'):
            self.lua.execute((regression.ROOT/'tests'/name).read_text(encoding='utf-8-sig'))
        self.run_lua("""
            main.RegisterPanel=function(self,name,panel)
                panel:SetSize(892,321); if name=='界面美化' then self.options=panel end
            end
            NO_SCAN_WORD=true; SettingPanel:OnInitialize(); ns.SetupNativeSettings(SettingPanel)
            ns.SetupOptions(main)
            local a=ns.D(SettingPanel).nativeSettings; local b=ns.D(main.options).skinOptions
            for _,u in ipairs({a,b}) do for _,cat in ipairs(u.categories) do green(cat.mark) end end
            ns.Set('useClassColor',true)
            for _,u in ipairs({a,b}) do for _,cat in ipairs(u.categories) do sameColor(cat.mark,.25,.78,.92) end end
            assert(#writes==0)
        """)

    def test_saved_preference_survives_reload_and_reset_returns_green(self):
        for value in ('false','true'):
            self.run_lua(f'MeetingStoneEllesmereUIDB={{useClassColor={value}}}')
            self.lua.execute("assert(loadstring(...))('MeetingStoneEllesmereUI',ns)",
                (regression.ROOT/'Config.lua').read_text(encoding='utf-8-sig'))
            self.run_lua(f"assert(ns.Get('useClassColor')=={value})")
        self.run_lua("""
            local t=main:CreateTexture(); ns.Accent(t,.3)
            ns.SetupOptions(main); local u=ns.D(main.options).skinOptions
            assert(u.byKey.useClassColor.control:GetChecked())
            u.reset:Click(); confirmation.callback(true)
            assert(ns.Get('useClassColor')==false and not u.byKey.useClassColor.control:GetChecked())
            green(t,.3)
        """)

    def test_theme_notifications_never_change_selected_colour_or_borders(self):
        self.run_lua("""
            local input=CreateFrame('EditBox',nil,main); ns.SetControlChrome(input,true)
            local c=GUI:GetClass('CheckBox'):New(main); c:SetChecked(true); ns.SkinSwitch(c)
            local s=ns.D(c).switch
            for _,mode in ipairs({false,true}) do
                ns.Set('useClassColor',mode)
                ns.S.GetAccentColor=function() return 1,0,0 end
                looksChanged(); ns.RefreshAccents()
                if mode then sameColor(s.thumb[1],.25,.78,.92) else green(s.thumb[1]) end
                dark(s.edge[1]); for _,edge in ipairs(ns.D(input).browseChrome.edges) do dark(edge) end
            end
        """)

    def test_returned_input_filters_and_global_theme_remain_untouched(self):
        browse_tests.BrowseChromeTests.setup_controls(self)
        self.run_lua("""
            browsePass(); flush(); eb:SetParent(sp); flush(); local s=ns.D(eb).browseChrome
            local searches=browse.searches; local fn=eb:GetScript('OnEnterPressed')
            EllesmereUIDB={accentColor={r=.3,g=.2,b=.1}}; local color=EllesmereUIDB.accentColor
            for i=1,20 do ns.Set('useClassColor',i%2==0) end
            assert(not s.host:IsShown() and eb.Left:GetAlpha()==.8)
            assert(eb:GetParent()==sp and eb:GetText()=='test' and eb.focused)
            assert(eb:GetScript('OnEnterPressed')==fn and browse.searches==searches)
            assert(EllesmereUIDB.accentColor==color and color.r==.3)
        """)


if __name__=='__main__': unittest.main()
