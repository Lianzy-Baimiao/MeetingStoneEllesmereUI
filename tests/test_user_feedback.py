"""Reproduce 1.4.0 feedback against upstream registration and role saves."""
import unittest
import test_native_settings as native
import test_regressions as regression
ROOT=regression.ROOT

class FeedbackTests(unittest.TestCase):
    setUp=regression.RegressionTests.setUp
    run_lua=regression.RegressionTests.run_lua

    def roles(self):
        self.run_lua('''
            enabled={activities={}}; Dungeons={}; savedFilters={}; warnings={}
            function GUI:CallWarningDialog(text) warnings[#warnings+1]=text end
            C_LFGList={SaveAdvancedFilter=function(data)
                local copy={}; for k,v in pairs(data) do copy[k]=v end
                savedFilters[#savedFilters+1]=copy
            end}
        ''')
        self.lua.execute((ROOT/'tests/fixtures/EXRoleSave-20261001.lua').read_text(encoding='utf-8'))
        self.run_lua('''
            byRole={}
            for _,row in ipairs(browse.MD) do
                byRole[row.dataValue]=row
                row:SetCallback('OnChanged',roleFunc)
                row.Check:SetScript('OnClick',function() row:Fire('OnChanged') end)
            end
        ''')

    def test_conflict_rejects_new_tank_choice_before_saving(self):
        self.roles()
        self.run_lua('''
            browsePass()
            byRole.hasTank.Check:Click(); byRole.needsTank.Check:Click()
            assert(not byRole.needsTank.Check:GetChecked(), 'new conflicting choice stayed checked')
            assert(byRole.hasTank.Check:GetChecked(), 'old valid choice lost')
            assert(not enabled.needsTank and enabled.hasTank, 'invalid role data was saved')
            assert(#warnings==1)
            for _,save in ipairs(savedFilters) do assert(not (save.needsTank and save.hasTank)) end
        ''')

    def test_conflict_from_quick_filter_is_reverted_without_search(self):
        self.roles()
        self.run_lua('''
            browsePass(); local proxies={}
            for _,pair in ipairs(ns.D(browse).roleBar) do proxies[pair.real.dataValue]=pair.proxy end
            byRole.hasTank.Check:Click(); proxies.needsTank:Click()
            assert(not proxies.needsTank:GetChecked(), 'quick filter still selected rejected role')
            assert(not byRole.needsTank.Check:GetChecked())
            assert(browse.searches==0, 'rejected change triggered a search')
        ''')

    def test_switch_has_no_stair_stepped_rounding(self):
        self.run_lua('''
            local cb=GUI:GetClass('CheckBox'):New(main); ns.SkinSwitch(cb)
            local s=ns.D(cb).switch
            assert(#s.edge==1 and #s.track==1 and #s.thumb==1,
                'switch is still drawn from stepped round-corner slices')
        ''')
    def test_both_role_pairs_both_directions_keep_first_choice(self):
        self.roles()
        self.run_lua('''
            ns.Set('roleFilterBar',false); browsePass()
            assert(not ns.D(browse).roleBar)
            for _,keys in ipairs({{'needsTank','hasTank'},{'hasTank','needsTank'},
                {'needsHealer','hasHealer'},{'hasHealer','needsHealer'}}) do
                for _,row in pairs(byRole) do row.Check:SetChecked(false) end
                enabled={activities={}}; warnings={}; savedFilters={}
                local first,second=byRole[keys[1]].Check,byRole[keys[2]].Check
                first:Click(); second:Click()
                assert(first:GetChecked() and not second:GetChecked())
                assert(enabled[keys[1]] and not enabled[keys[2]] and #warnings==1)
                assert(#savedFilters==1, 'invalid click reached upstream save')
                first:Click(); second:Click()
                assert(not enabled[keys[1]] and enabled[keys[2]], 'valid swap was blocked')
                assert(#savedFilters==3)
            end
        ''')

    def test_role_guard_late_init_repeated_setup_and_valid_other_roles(self):
        self.roles()
        self.run_lua('''
            local md=browse.MD; browse.MD=nil; browsePass()
            browse.MD=md; browsePass()
            local cb=byRole.hasHealer.Check:GetScript('OnClick')
            browsePass(); browsePass(); assert(byRole.hasHealer.Check:GetScript('OnClick')==cb)
            byRole.needsHealer.Check:Click(); byRole.hasHealer.Check:Click()
            assert(#warnings==1 and not byRole.hasHealer.Check:GetChecked())
            byRole.needsTank.Check:Click(); byRole.needsDamage.Check:Click()
            assert(enabled.needsHealer and enabled.needsTank and enabled.needsDamage)
            assert(#warnings==1 and #savedFilters==3)
        ''')

    def test_switch_edges_snap_to_physical_pixels_at_different_scales(self):
        self.run_lua('''
            GetPhysicalScreenSize=function() return 2560,1440 end
            local cb=GUI:GetClass('CheckBox'):New(main)
            cb:SetPoint('BOTTOMLEFT',main,'BOTTOMLEFT',13.3,24.1)
            for _,scale in ipairs({.64,1,1.25}) do
                cb.GetEffectiveScale=function() return scale end
                for _,width in ipairs({20,32}) do
                    cb:SetSize(width,22); ns.SkinSwitch(cb)
                    local pixel=768/1440/scale
                    local function aligned(value)
                        local v=value/pixel
                        assert(math.abs(v-math.floor(v+.5))<.00001, 'edge is on a fractional pixel')
                    end
                    for _,on in ipairs({false,true}) do
                        cb:SetChecked(on); local s=ns.D(cb).switch
                        for _,f in ipairs({s.host,s.knob,s.edge[1],s.track[1],s.thumb[1]}) do
                            aligned(f:GetLeft()); aligned(f:GetRight()); aligned(f:GetTop()); aligned(f:GetBottom())
                        end
                        assert(math.abs((s.host:GetWidth()-s.track[1]:GetWidth())-2*pixel)<.00001)
                    end
                end
            end
        ''')


    def test_same_size_settings_layout_resnaps_moved_switch(self):
        self.run_lua("""
            GetPhysicalScreenSize=function() return 2560,1440 end
            local content=CreateFrame('Frame',nil,main)
            content:SetSize(600,300)
            content:SetPoint('TOPLEFT',main,'TOPLEFT',13.3,-24.1)
            local row={frame=CreateFrame('Frame',nil,content)}
            row.label=row.frame:CreateFontString(); row.hint=row.frame:CreateFontString()
            row.control=GUI:GetClass('CheckBox'):New(row.frame)
            local cb=row.control; cb:SetSize(32,22)
            cb.GetEffectiveScale=function() return .64 end
            local size=cb.SetSize
            cb.SetSize=function(self,w,h)
                if self:GetWidth()~=w or self:GetHeight()~=h then size(self,w,h) end
            end
            ns.SkinSwitch(cb)
            for _,x in ipairs({13.3,14.7}) do
                content:SetPoint('TOPLEFT',main,'TOPLEFT',x,-24.1)
                ns.SettingsLayout.Row(row,content,0,600,'check')
                local pixel=768/1440/.64
                for _,f in ipairs({ns.D(cb).switch.host,ns.D(cb).switch.knob}) do
                    for _,value in ipairs({f:GetLeft(),f:GetRight(),f:GetTop(),f:GetBottom()}) do
                        local v=value/pixel
                        assert(math.abs(v-math.floor(v+.5))<.00001, 'moving layout left a fractional edge')
                    end
                end
            end
        """)


class PageAlignmentTests(unittest.TestCase):
    setUp=native.NativeSettingsTests.setUp
    run_lua=native.NativeSettingsTests.run_lua

    def setup_registration(self,keywords=False):
        self.run_lua('''
            TabView={}; function GUI:NewEmbed() return TabView end
            libraries['NetEaseGUI-2.0']=GUI; tinsert=table.insert; max=math.max
        ''')
        self.lua.execute((ROOT/'tests/fixtures/TabPanel-20261001.lua').read_text(encoding='utf-8-sig'))
        self.run_lua('''
            for k,v in pairs(TabView) do if type(v)=='function' then main[k]=v end end
            main.UpdateTab=function() end; main.GetSelectedTab=function() end
            main.GetTopHeight=function() return 26 end
            main.GetBottomHeight=function() return 26 end
            main.Inset=CreateFrame('Frame',nil,main); main.Inset:SetSize(914,395)
            main.Inset:SetPoint('TOPLEFT',main,'TOPLEFT',4,-26)
            function GUI:Embed(panel) panel.SetOwner=function(self,owner) self.owner=owner end end
            -- The live engine resolves opposite anchors to size automatically.
            -- Do the same just for registered pages, without faking RegisterPanel.
            local register=main.RegisterPanel
            main.RegisterPanel=function(self,...)
                local data=register(self,...); local p=data.panel
                local a,b=p.points.TOPLEFT,p.points.BOTTOMRIGHT
                p:SetSize(p:GetParent():GetWidth()+b[4]-a[4],p:GetParent():GetHeight()+a[5]-b[5])
                return data
            end
        ''')
        self.run_lua(f"NO_SCAN_WORD={'false' if keywords else 'true'}; SettingPanel:OnInitialize(); ns.SetupNativeSettings(SettingPanel); ns.SetupOptions(main)")
        self.run_lua('''
            local _,data=main:IsPanelRegistered('界面美化'); BeautyPanel=data.panel
            nativeUI=ns.D(SettingPanel).nativeSettings; beautyUI=ns.D(BeautyPanel).skinOptions
        ''')

    def test_switching_tabs_keeps_absolute_label_and_nav_positions(self):
        self.setup_registration()
        self.run_lua('''
            for _,key in ipairs({'nav','navTitle','title','subtitle','scroll'}) do
                local a,b=nativeUI[key],beautyUI[key]
                assert(a:GetLeft()==b:GetLeft() and a:GetTop()==b:GetTop(), 'tab position jumps: '..key)
                assert(a:GetWidth()==b:GetWidth() and a:GetHeight()==b:GetHeight(), 'tab size jumps: '..key)
            end
            local a,b=nativeUI.rows[1].label,beautyUI.rows[1].label
            assert(a:GetLeft()==b:GetLeft() and a:GetTop()==b:GetTop(), 'row label jumps')
        ''')

    def test_keyword_variant_inherits_same_tab_inset_heights(self):
        self.setup_registration(True)
        self.run_lua('''
            local _,a=main:IsPanelRegistered('设置'); local _,b=main:IsPanelRegistered('界面美化')
            assert(a.topHeight==b.topHeight and a.bottomHeight==b.bottomHeight,
                'tab switch changes the MainPanel inset height')
        ''')

    def test_shared_layout_keeps_gutters_and_control_columns_aligned_after_resize(self):
        self.setup_registration()
        self.run_lua('''
            for _,size in ipairs({{906,389},{760,500}}) do
                SettingPanel:SetSize(unpack(size)); BeautyPanel:SetSize(unpack(size))
                SettingPanel:Show(); BeautyPanel:Show()
                local a,b=nativeUI,beautyUI
                assert(a.title:GetLeft()==a.rows[1].label:GetLeft())
                assert(b.title:GetLeft()==b.rows[1].label:GetLeft())
                assert(a.footer:GetBottom()-SettingPanel:GetBottom()==12)
                assert(b.hint:GetBottom()-BeautyPanel:GetBottom()==12)
                assert(a.nav:GetTop()-a.nav:GetBottom()==b.nav:GetHeight())
                assert(a.byKey.minimap.control:GetLeft()==b.byKey.topBar.control:GetLeft())
                a.categories[3].button:Click(); b.categories[1].button:Click()
                assert(a.byKey.uiScale.control:GetLeft()==b.byKey.bgAlpha.control:GetLeft())
                a.categories[1].button:Click()
            end
        ''')

if __name__=='__main__': unittest.main()
