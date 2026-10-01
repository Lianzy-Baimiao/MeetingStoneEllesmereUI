"""Offline retention probe; not an in-game addon-memory measurement.
Runs real settings/filter/control Lua against existing WoW/EUI doubles.
"""
from test_native_settings import NativeSettingsTests

def run():
    test=NativeSettingsTests(); test.setUp(); test.init()
    test.run_lua("""
        local register=main.RegisterPanel
        main.RegisterPanel=function(self,name,panel,...)
            register(self,name,panel,...); self.options=panel
        end
        ns.SetupOptions(main)
        local sp=CreateFrame('Frame',nil,main)
        local eb=CreateFrame('EditBox',nil,browse); browse.SearchBox=eb
        eb.Left=eb:CreateTexture(); eb.searchIcon=eb:CreateTexture()
        eb.Instructions=eb:CreateFontString(); eb:SetHeight(18)
        browse.ActivityDropdown:SetSize(170,26)
        browse.ActivityDropdown.Stock=browse.ActivityDropdown:CreateTexture()
        browse.ActivityDropdown.MenuButton=CreateFrame('Button',nil,browse.ActivityDropdown)
        local quick=GUI:GetClass('CheckBox'):New(browse); quick:SetText('双击加入(专精职责)')
        local auto=GUI:GetClass('CheckBox'):New(browse); auto:SetText('自动进组')
        local specRole='HEALER'
        GetSpecialization=function() return 1 end
        GetSpecializationInfo=function() return 123,'test',nil,nil,specRole end
        browsePass(); flush()
        local native=ns.D(SettingPanel).nativeSettings
        local beauty=ns.D(main.options).skinOptions
        function exercise()
            browse:Hide(); eb:SetParent(sp); browse:Show(); eb:SetParent(browse); browsePass()
            browse.ActivityDropdown:SetValue('custom-pve')
            browse.ActivityDropdown:SetValue('mplus')
            specRole='TANK'; fireEvent('PLAYER_SPECIALIZATION_CHANGED','player')
            specRole='HEALER'; fireEvent('PLAYER_SPECIALIZATION_CHANGED','player')
            browse.AdvButton:Click(); browse.AdvButton:Click()
            for _,c in ipairs(native.categories) do c.button:Click() end
            for _,c in ipairs(beauty.categories) do c.button:Click() end
            ns.SetupNativeSettings(SettingPanel)
            ns.RefreshSwitches(); flush()
        end
        function stats()
            local hooks=0
            for _,f in ipairs(frames) do
                for _,list in pairs(f.hooks) do hooks=hooks+#list end
            end
            return #frames,hooks,#C_Timer.pending,collectgarbage('count')
        end
    """)
    for batch in range(6):
        test.run_lua("for i=1,100 do exercise() end")
        before=test.lua.eval('collectgarbage("count")')
        test.run_lua('collectgarbage("collect"); collectgarbage("collect")')
        frames,hooks,timers,after=test.lua.eval('stats()')
        print(f'cycles={(batch+1)*100}: objects={frames}, script_hooks={hooks}, pending_timers={timers}, '
              f'Lua_KiB_before_GC={before:.1f}, after_GC={after:.1f}')
        if batch==0: baseline=frames,hooks,timers,after
        else:
            assert (frames,hooks,timers)==baseline[:3], 'retained controls/hooks/timers grew after warmup'
            assert after-baseline[3]<64, 'retained Lua memory grew after warmup'

if __name__=='__main__': run()
