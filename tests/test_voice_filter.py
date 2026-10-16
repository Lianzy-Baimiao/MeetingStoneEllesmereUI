"""Run: python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_voice_filter.py -v
Optional 屏蔽语音队伍: wraps the real NetEaseGUI Filter embed's predicate.
"""
import unittest
from lupa.lua51 import LuaRuntime
import test_regressions as regression

SETUP = r'''
function LibStub(name) if name=='NetEaseGUI-2.0' then return GUI end end
wipe = wipe or function(t) for k in pairs(t) do t[k]=nil end; return t end
tinsert = tinsert or table.insert
function GUI:NewEmbed() FilterEmbed={}; return FilterEmbed end
'''
LIST = r'''
list={}
for k,v in pairs(FilterEmbed) do list[k]=v end
function list:Refresh() self.refreshes=(self.refreshes or 0)+1 end
function list:GetItemCount() return self.filterList and #self.filterList or #self.itemList end
function list:GetItem(i) return (self.filterList or self.itemList)[i] end
function list:GetExcludeCount() return 0 end
browse.ActivityList=list
function activity(name, voice, extra)
    local a={name=name, voice=voice}
    for k,v in pairs(extra or {}) do a[k]=v end
    function a:GetVoiceChat() return self.voice end
    function a:IsSelf() return self.self end
    function a:IsApplication() return self.app end
    function a:IsApplicationFinished() return self.finished end
    return a
end
list.itemList={
    activity('plain'), activity('voice','|K123|k'), activity('ex-hidden'),
    activity('mine','vc',{self=true}), activity('applied','vc',{app=true}),
    activity('declined','vc',{app=true,finished=true}), activity('empty',''),
    activity('secret',SECRET),
}
-- MeetingStone registers first, MeetingStoneEX replaces it at load time.
list:RegisterFilter(function(a) return true end)
list:RegisterFilter(function(a, text) baseCalls=(baseCalls or 0)+1; return a.name~='ex-hidden' end)
function shown()
    list:SetFilterText('filters'); local out={}
    for i=1,list:GetItemCount() do out[#out+1]=list:GetItem(i).name end
    return table.concat(out,',')
end
'''


class VoiceFilterTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((regression.ROOT / 'tests/wow_mock.lua').read_text(encoding='utf-8-sig'))
        # Before VoiceFilter.lua: it captures issecretvalue at load, like the client global.
        self.lua.execute('SECRET={}; function issecretvalue(v) return v==SECRET end')
        for name in ('Config.lua', 'Controls.lua', 'BrowseInputs.lua', 'BrowseJoinControls.lua', 'TablePanels.lua',
                     'UnifiedFilters.lua', 'VoiceFilter.lua', 'AutoApplyDialog.lua', 'SettingsLayout.lua',
                     'NativeSettings.lua', 'Panels.lua', 'Options.lua'):
            self.lua.execute("local source=...; assert(loadstring(source))('MeetingStoneEllesmereUI', ns)",
                             (regression.ROOT / name).read_text(encoding='utf-8-sig'))
        self.lua.execute(SETUP)
        self.lua.execute((regression.ROOT / 'tests/fixtures/NetEaseFilterEmbed-20261016.lua')
                         .read_text(encoding='utf-8-sig'))
        self.lua.execute(LIST)

    def run_lua(self, source):
        return self.lua.execute(source)

    def test_off_by_default_keeps_every_native_result(self):
        self.run_lua('''
            assert(ns.DEFAULTS.hideVoiceGroups==false and ns.Get('hideVoiceGroups')==false)
            browsePass(); flush()
            assert(shown()=='plain,voice,mine,applied,declined,empty,secret', shown())
        ''')

    def test_on_hides_voice_groups_but_keeps_own_and_live_applications(self):
        self.run_lua('''
            browsePass(); flush(); baseCalls=0
            ns.Set('hideVoiceGroups',true)
            assert(list.refreshes and list.refreshes>=1, 'toggle did not refresh the list')
            assert(shown()=='plain,mine,applied,empty,secret', shown())
            assert(baseCalls>0, 'EX predicate no longer consulted')
            assert(list:GetItemCount()==5, 'auto-apply would walk a different list')
            ns.Set('hideVoiceGroups',false)
            assert(shown()=='plain,voice,mine,applied,declined,empty,secret')
        ''')

    def test_reregistered_predicate_is_wrapped_once(self):
        self.run_lua('''
            browsePass(); flush(); ns.Set('hideVoiceGroups',true)
            local wrapped=list.filter
            browse:Hide(); browse:Show(); flush(); browsePass(); flush()
            assert(list.filter==wrapped, 'reopen stacked another wrapper')
            list:RegisterFilter(function(a) return a.name~='plain' end)
            assert(list.filter~=wrapped)
            assert(shown()=='ex-hidden,mine,applied,empty,secret', shown())
        ''')

    def test_reset_restores_hidden_groups(self):
        self.run_lua('''
            browsePass(); flush(); ns.Set('hideVoiceGroups',true)
            assert(not shown():find('voice'))
            ns.ResetAll()
            assert(ns.Get('hideVoiceGroups')==false and shown():find('voice'))
        ''')

    def test_option_row_is_listed_under_activity_list(self):
        self.run_lua('''
            ns.SetupOptions(main); local u=ns.D(main.options).skinOptions
            local row=assert(u.byKey.hideVoiceGroups)
            assert(row.category==3 and row.cfg.kind=='check' and not row.control:GetChecked())
            row.control:Click(); assert(ns.Get('hideVoiceGroups')==true)
        ''')


if __name__ == '__main__':
    unittest.main()
