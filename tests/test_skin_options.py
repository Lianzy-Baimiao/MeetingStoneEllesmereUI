"""The beauty tab shares the native settings layout, but owns only its own DB."""
import unittest
import test_regressions as regression

class SkinOptionsTests(unittest.TestCase):
    setUp=regression.RegressionTests.setUp
    run_lua=regression.RegressionTests.run_lua

    def init(self):
        self.run_lua('ns.SetupOptions(main); u=ns.D(main.options).skinOptions')

    def test_open_navigation_reopen_never_save_or_reset(self):
        self.run_lua('''
            local set=ns.Set; writes=0
            ns.Set=function(...) writes=writes+1; return set(...) end
            ns.SetupOptions(main); local u=ns.D(main.options).skinOptions
            for _,c in ipairs(u.categories) do c.button:Click() end
            main.options:Hide(); main.options:Show()
            assert(writes==0 and u.selected==3)
            assert(u.byKey.skinRows.control:GetWidth()==32)
            assert(ns.D(u.byKey.skinRows.control).switch.host:GetWidth()==28)
        ''')

    def test_draft_cancel_commit_and_navigation_commit(self):
        self.init()
        self.run_lua('''
            u.categories[2].button:Click(); local c=u.byKey.listFontSize.control
            local old=ns.Get('listFontSize'); c:SetFocus(); c:SetNumber(1)
            assert(ns.Get('listFontSize')==old)
            c:SetNumber(16); c:RunScript('OnEscapePressed')
            assert(ns.Get('listFontSize')==old and c:GetNumber()==old)
            c:SetFocus(); c:SetNumber(16); c:ClearFocus(); assert(ns.Get('listFontSize')==16)
            c:SetFocus(); c:SetNumber(15); u.categories[1].button:Click()
            assert(not c.focused and ns.Get('listFontSize')==15)
        ''')

    def test_scroll_clamps_on_category_and_resize(self):
        self.init()
        self.run_lua('''
            u.scroll:RunScript('OnMouseWheel',-99)
            assert(u.scroll:GetVerticalScroll()==u.content:GetHeight()-u.scroll:GetHeight())
            u.categories[2].button:Click(); assert(u.scroll:GetVerticalScroll()==0)
            main.options:SetSize(760,500)
            assert(u.scroll:GetVerticalScroll()==0 and u.scroll:GetBottom()>u.hint:GetTop())
            for _,r in ipairs(u.rows) do if r.frame:IsShown() then
                assert(r.label:GetRight()<r.control:GetLeft())
            end end
        ''')

    def test_reset_confirmation_scoped_to_skin_database(self):
        self.init()
        self.run_lua('''
            unrelated={dungeons={a=true},rating=100}; local marker=unrelated.dungeons
            ns.Set('bgAlpha',.4); u.reset:Click(); confirmation.callback(false)
            assert(ns.Get('bgAlpha')==.4)
            u.reset:Click(); confirmation.callback(true)
            assert(ns.Get('bgAlpha')==ns.DEFAULTS.bgAlpha)
            assert(unrelated.dungeons==marker and unrelated.rating==100)
        ''')

    def test_color_picker_cancel_restores_original(self):
        self.init()
        self.run_lua('''
            ns.Set('bgColor',{.1,.2,.3})
            ColorPickerFrame={SetupColorPickerAndShow=function(_,info) picker=info end,
                GetColorRGB=function() return .4,.5,.6 end}
            u.byKey.bgColor.control:Click(); picker.swatchFunc()
            local r=ns.GetColor('bgColor'); assert(r==.4)
            picker.cancelFunc(); local r,g,b=ns.GetColor('bgColor')
            assert(r==.1 and g==.2 and b==.3)
        ''')

if __name__=='__main__': unittest.main()
