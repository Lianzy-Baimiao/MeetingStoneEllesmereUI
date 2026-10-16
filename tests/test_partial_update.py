"""Run: python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_partial_update.py -v
After updating with only /reload, WoW keeps the old TOC file list: VoiceFilter.lua
and AutoApplyDialog.lua are not loaded. Every other file must still work.
"""
import unittest
from lupa.lua51 import LuaRuntime
import test_regressions as regression

WITHOUT_NEW_FILES = ('Config.lua', 'Controls.lua', 'BrowseInputs.lua', 'BrowseJoinControls.lua', 'TablePanels.lua',
                     'UnifiedFilters.lua', 'SettingsLayout.lua', 'NativeSettings.lua', 'Panels.lua', 'Options.lua')


class PartialUpdateTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((regression.ROOT / 'tests/wow_mock.lua').read_text(encoding='utf-8-sig'))
        for name in WITHOUT_NEW_FILES:
            self.lua.execute("local source=...; assert(loadstring(source))('MeetingStoneEllesmereUI', ns)",
                             (regression.ROOT / name).read_text(encoding='utf-8-sig'))

    def run_lua(self, source):
        self.lua.execute(source)

    def test_skin_runs_without_the_files_new_in_1_4_21(self):
        self.run_lua('''
            assert(ns.SetupVoiceFilter == nil and ns.SetupAutoApplyDialog == nil)
            browse.AutoApplyController = { RequestStart = function() end }
            browsePass(); flush(); browse:Hide(); browse:Show(); flush()
            assert(ns.D(browse).roleBar, 'browse pass broke without the new files')
            ns.SetupOptions(main); local u = ns.D(main.options).skinOptions
            u.byKey.hideVoiceGroups.control:Click()
            assert(ns.Get('hideVoiceGroups') == true, 'option row stopped saving')
            ns.ResetAll(); assert(ns.Get('hideVoiceGroups') == false)
        ''')

    def test_create_page_layout_runs_without_the_new_files(self):
        self.lua.execute((regression.ROOT / 'tests/table_panels_mock.lua').read_text(encoding='utf-8'))
        self.lua.execute((regression.ROOT / 'tests/fixtures/IgnoreListPanel-20261002.lua').read_text(encoding='utf-8'))
        self.run_lua('''
            IgnoreListPanel:OnInitialize(); IgnoreListPanel.IgnoreList:Refresh()
            setupTablePages(); assert(CreatePanel.VoiceBox:GetWidth() == 112)
        ''')


if __name__ == '__main__':
    unittest.main()
