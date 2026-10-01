"""Execute the real upstream settings definitions and the replacement UI."""
from pathlib import Path
import unittest
import test_regressions as fixtures
ROOT=Path(__file__).resolve().parents[1]

class NativeSettingsTests(unittest.TestCase):
    def setUp(self):
        base=fixtures.RegressionTests(); base.setUp(); self.lua=base.lua
        self.lua.execute((ROOT/'tests/native_settings_mock.lua').read_text(encoding='utf-8-sig'))
        self.lua.execute((ROOT/'tests/fixtures/OptionPanel-20261001.lua').read_text(encoding='utf-8-sig'))
    def run_lua(self,source): self.lua.execute(source)
    def init(self,keywords=False):
        self.run_lua(f"NO_SCAN_WORD={'false' if keywords else 'true'}; SettingPanel:OnInitialize(); ns.SetupNativeSettings(SettingPanel)")

    def test_replaces_native_page_and_covers_every_option(self):
        self.init()
        self.run_lua('''
            local u=assert(ns.D(SettingPanel).nativeSettings,'missing redesigned native settings')
            assert(#u.categories==5)
            local count=0
            for key,option in pairs(registered.MeetingStone.args) do
                assert(u.byKey[key] and u.byKey[key].option==option,'lost option '..key); count=count+1
            end
            assert(count==19)
            for _,f in ipairs(u.originals) do f:Show(); assert(not f:IsVisible(),'old AceConfig UI overlaps') end
            assert(u.host:IsVisible() and #writes==0,'opening modified settings')
        ''')

    def test_native_getters_setters_dependencies_and_reload_prompt(self):
        self.init()
        self.run_lua('''
            local u=ns.D(SettingPanel).nativeSettings
            u.byKey.minimap.control:Click(); assert(profile.minimap.hide and minimapShown==false)
            u.byKey.panel.control:Click(); assert(not profile.settings.panel)
            assert(not u.byKey.panelLock.control:IsEnabled() and not u.byKey.globalPanelPos.control:IsEnabled())
            u.byKey.panel.control:Click(); assert(u.byKey.panelLock.control:IsEnabled())
            u.categories[2].button:Click()
            assert(not u.byKey.showspecico.frame:IsShown())
            u.byKey.showclassico.control:Click()
            assert(globalOptions.showclassico and warning and reloadCallback)
            assert(u.byKey.showspecico.frame:IsShown())
            assert(not u.byKey.enableRaiderIO.frame:IsShown())
            assert(not u.byKey.useWindSkin.frame:IsShown())
        ''')

    def test_scale_converts_percent_without_duplicate_or_initial_writes(self):
        self.init()
        self.run_lua('''
            local u=ns.D(SettingPanel).nativeSettings
            assert(#writes==0 and profile.settings.uiscale==1.2)
            u.categories[3].button:Click(); assert(u.byKey.uiScale.control:GetNumber()==120)
            u.byKey.uiScale.control:SetNumber(150); flush()
            assert(profile.settings.uiscale==1.5 and main.scale==1.5)
            ns.SetupNativeSettings(SettingPanel); assert(profile.settings.uiscale==1.5)
        ''')

    def test_clear_history_requires_original_confirmation(self):
        self.init()
        self.run_lua('''
            local u=ns.D(SettingPanel).nativeSettings; u.categories[5].button:Click()
            u.byKey.clearhistory.control:Click(); assert(confirmation and not historyCleared)
            confirmation.callback(false); assert(not historyCleared)
            u.byKey.clearhistory.control:Click(); confirmation.callback(true); assert(historyCleared==1)
        ''')

    def test_key_conflict_cancel_accept_and_capture_cleanup(self):
        self.init()
        self.run_lua('''
            local u=ns.D(SettingPanel).nativeSettings; u.categories[5].button:Click()
            local key=u.byKey.key.widget
            key:Fire('OnKeyChanged','CTRL-X'); assert(confirmation and bindings.MEETINGSTONE_TOGGLE=='CTRL-M')
            confirmation.callback(false); assert(key.key=='CTRL-M')
            key:Fire('OnKeyChanged','CTRL-X'); confirmation.callback(true)
            assert(bindings.MEETINGSTONE_TOGGLE=='CTRL-X' and savedBindingSet==2)
            key.waitingForKey=true; key.msgframe:Show(); key.button:EnableKeyboard(true)
            u.categories[1].button:Click()
            assert(not key.waitingForKey and not key.msgframe:IsShown() and not key.button.keyboard)
        ''')

    def test_keywords_keep_original_widget_and_all_actions(self):
        self.init(True)
        self.run_lua('''
            local u=ns.D(SettingPanel).nativeSettings; u.categories[4].button:Click()
            assert(u.keyword==SettingPanel.SpamWordList:GetParent():GetParent())
            assert(u.keyword:IsVisible() and u.byKey.spamWord)
            assert(not u.byKey.spamLength.control:IsEnabled())
            u.byKey.spamLengthEnabled.control:Click(); assert(u.byKey.spamLength.control:IsEnabled())
            local buttons={}
            for _,f in ipairs({u.keyword:GetChildren()}) do if f:GetObjectType()=='Button' then buttons[f:GetText()]=f end end
            buttons['添加']:Click(); assert(SettingPanel.InputSpamWord.openArgs)
            buttons['重置']:Click(); assert(not wordsReset); confirmation.callback(true); assert(wordsReset==1)
            assert(buttons['导入'] and buttons['导出'])
            buttons['导入']:Click(); buttons['导出']:Click()
            u.categories[1].button:Click(); assert(not u.keyword:IsVisible())
        ''')

    def test_disabled_keyword_module_stays_disabled(self):
        self.init()
        self.run_lua('''
            local u=ns.D(SettingPanel).nativeSettings; u.categories[4].button:Click()
            assert(not u.keyword and not u.byKey.spamWord and not registered['MeetingStone Filters'])
            assert(u.keywordNote:IsShown(),'missing explanation for disabled keyword module')
        ''')

    def test_reopen_resize_and_unknown_options_fallback(self):
        self.run_lua("SettingPanel:OnInitialize(); registered.MeetingStone.args.future={type='select',name='Future'}")
        self.run_lua('''
            ns.SetupNativeSettings(SettingPanel); local u=ns.D(SettingPanel).nativeSettings
            local n=#frames; for i=1,5 do ns.SetupNativeSettings(SettingPanel) end; assert(#frames==n)
            u.originalButton:Click(); assert(openedOriginal=='MeetingStone')
            profile.settings.panel=false; SettingPanel:Hide(); SettingPanel:Show()
            assert(not u.byKey.panel.control:GetChecked(),'reopen did not load external changes')
            SettingPanel:SetSize(750,300); SettingPanel:RunScript('OnSizeChanged',750,300)
            assert(u.scroll:GetWidth()>350 and u.scroll:GetHeight()>150)
            assert(u.scroll:GetRight()<SettingPanel:GetRight())
        ''')

    def test_missing_registry_leaves_native_settings_alone(self):
        self.run_lua('''
            SettingPanel:OnInitialize(); registered.MeetingStone=nil
            ns.SetupNativeSettings(SettingPanel)
            assert(not ns.D(SettingPanel).nativeSettings)
            for _,f in ipairs({SettingPanel:GetChildren()}) do assert(f:IsVisible()) end
        ''')

    def test_numeric_typing_is_not_clamped_after_the_first_digit(self):
        self.init()
        self.run_lua("""
            local u=ns.D(SettingPanel).nativeSettings; u.categories[3].button:Click()
            local c=u.byKey.uiScale.control
            assert(c.Label and not c.Label:IsShown())
            c:SetFocus(); c:SetNumber(1); c:SetNumber(15)
            assert(#writes==0 and c:GetNumber()==15, 'partial input was replaced')
            c:SetNumber(150); c:ClearFocus(); flush()
            assert(profile.settings.uiscale==1.5 and main.scale==1.5)
            c:SetFocus(); c:SetNumber(180); c:RunScript('OnEscapePressed'); flush()
            assert(profile.settings.uiscale==1.5 and c:GetNumber()==150, 'escape saved the draft')
            c:SetFocus(); c:SetNumber(170); u.categories[1].button:Click(); flush()
            assert(math.abs(profile.settings.uiscale-1.7)<.00001 and not c.focused, 'navigation lost completed input')
        """)

    def test_scale_clamps_and_rounds_to_native_step(self):
        self.init()
        self.run_lua("""
            local u=ns.D(SettingPanel).nativeSettings; local c=u.byKey.uiScale.control
            c:SetNumber(999); flush(); assert(profile.settings.uiscale==2 and c:GetNumber()==200)
            c:SetNumber(1); flush(); assert(profile.settings.uiscale==.5 and c:GetNumber()==50)
            c:SetNumber(123); flush(); assert(math.abs(profile.settings.uiscale-1.2)<.00001 and c:GetNumber()==120)
        """)

    def test_navigation_and_controls_stay_within_layout(self):
        self.init(True)
        self.run_lua("""
            local u=ns.D(SettingPanel).nativeSettings
            for _,size in ipairs({{892,321},{750,300}}) do
                SettingPanel:SetSize(unpack(size)); SettingPanel:RunScript('OnSizeChanged')
                for _,cat in ipairs(u.categories) do
                    cat.button:Click()
                    assert(cat.button:GetBottom()>u.originalButton:GetTop())
                    assert(u.scroll:GetLeft()>u.nav:GetRight())
                    assert(u.scroll:GetBottom()>u.footer:GetTop())
                    local last
                    for _,row in ipairs(u.rows) do
                        if row.frame:IsShown() then
                            local c=row.widget and row.widget.frame or row.control
                            assert(row.label:GetRight()+8<=c:GetLeft(),'label/control collision '..row.key)
                            assert(row.hint:GetRight()+8<=c:GetLeft(),'hint/control collision '..row.key)
                            assert(c:GetRight()<=row.frame:GetRight()-8)
                            if last then assert(last:GetBottom()>row.frame:GetTop()) end
                            last=row.frame
                        end
                    end
                end
            end
        """)

    def test_dependency_options_appear_without_rebuilding_or_mutating_registry(self):
        self.run_lua("""
            SettingPanel:OnInitialize(); snapshots={}
            for key,opt in pairs(registered.MeetingStone.args) do
                snapshots[key]={}; for k,v in pairs(opt) do snapshots[key][k]=v end
            end
            ns.SetupNativeSettings(SettingPanel)
            local u=ns.D(SettingPanel).nativeSettings
            loadedAddons={ElvUI_WindTools=true,NDui_Plus=true}; RaiderIO={}
            u.categories[3].button:Click()
            assert(u.byKey.useWindSkin.frame:IsShown() and u.byKey.useNDuiSkin.frame:IsShown())
            assert(u.byKey.showWindClassIco.control:IsEnabled())
            u.categories[2].button:Click(); assert(u.byKey.enableRaiderIO.frame:IsShown())
            for key,opt in pairs(registered.MeetingStone.args) do
                for k,v in pairs(opt) do assert(snapshots[key][k]==v,'mutated original option') end
                for k,v in pairs(snapshots[key]) do assert(opt[k]==v,'removed original option field') end
            end
            assert(#writes==0)
        """)

    def test_closing_settings_stops_global_key_capture_prompt(self):
        self.init()
        self.run_lua("""
            local u=ns.D(SettingPanel).nativeSettings; u.categories[5].button:Click()
            local key=u.byKey.key.widget
            key.waitingForKey=true; key.msgframe:Show(); key.button:EnableKeyboard(true); key.button:EnableMouseWheel(true)
            SettingPanel:Hide()
            assert(not key.waitingForKey and not key.msgframe:IsShown())
            assert(not key.button.keyboard and not key.button.mousewheel)
        """)

    def test_native_panel_skin_pass_retries_after_registry_becomes_available(self):
        self.run_lua("""
            local pass
            for i=1,30 do
                local name,value=debug.getupvalue(ns.Boot,i)
                if name=='PASSES' then
                    for _,v in ipairs(value) do if v[1]=='SettingPanel' then pass=v[2] end end
                end
            end
            assert(pass); pass(SettingPanel); assert(not ns.D(SettingPanel).nativeSettings)
            SettingPanel:OnInitialize(); SettingPanel:Hide(); SettingPanel:Show()
            assert(ns.D(SettingPanel).nativeSettings)
            local n=#frames; pass(SettingPanel); assert(#frames==n)
        """)

    def test_real_registry_allows_panel_takeover(self):
        self.assert_real_registry_takeover()

    def test_real_registry_allows_keyword_panel_takeover(self):
        self.run_lua('NO_SCAN_WORD=false')
        self.assert_real_registry_takeover()
        self.run_lua("""
            local u=ns.D(SettingPanel).nativeSettings
            u.categories[4].button:Click()
            assert(u.keyword:IsVisible() and u.byKey.spamWord.frame:IsShown())
            u.byKey.spamWord.control:Click(); assert(profile.settings.spamWord)
        """)

    def assert_real_registry_takeover(self):
        # Exercise the installed AceConfigRegistry, including its uiName contract.
        # A permissive GetOptionsTable double missed the complete 1.3.0 failure.
        self.run_lua("""
            LibStub=setmetatable({}, {__call=function(_,name) return libraries[name] end})
            function LibStub:NewLibrary(name) local lib={}; libraries[name]=lib; return lib end
            libraries['CallbackHandler-1.0']={New=function() return {Fire=function() end} end}
        """)
        self.lua.execute((ROOT/'tests/fixtures/AceConfigRegistry-3.0-20261001.lua').read_text(encoding='utf-8-sig'))
        self.run_lua("""
            SettingPanel:OnInitialize()
            local pass
            for i=1,30 do
                local name,value=debug.getupvalue(ns.Boot,i)
                if name=='PASSES' then
                    for _,v in ipairs(value) do if v[1]=='SettingPanel' then pass=v[2] end end
                end
            end
            -- Boot isolates pass failures: the user sees the unchanged old page.
            local ok,err=pcall(pass,SettingPanel)
            local u=ns.D(SettingPanel).nativeSettings
            assert(u and u.host:IsVisible(), 'settings still old: '..tostring(err))
            for _,row in ipairs(u.rows) do
                assert(row.info.uiName:match('[A-Za-z]%-[0-9]'), 'invalid callback caller identity')
            end
            for _,f in ipairs(u.originals) do assert(not f:IsVisible()) end
            assert(#writes==0)
        """)

if __name__=='__main__': unittest.main()
