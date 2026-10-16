"""Run: python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_auto_apply_button.py -v
MeetingStoneEX's optional auto-apply button is skinned once, whenever it appears.
"""
import unittest
import test_regressions as regression


class AutoApplyButtonTests(unittest.TestCase):
    setUp = regression.RegressionTests.setUp
    run_lua = regression.RegressionTests.run_lua

    def counting(self):
        self.run_lua('''
            skinCounts={}
            ns.SkinButton=function(b) if b then skinCounts[b]=(skinCounts[b] or 0)+1 end end
        ''')

    def test_existing_button_is_skinned_once(self):
        self.counting()
        self.run_lua('''
            browse.AutoApplyButton=CreateFrame('Button',nil,browse)
            browsePass(); flush()
            local b=browse.AutoApplyButton
            assert(skinCounts[b]==1, 'auto-apply button was not skinned exactly once')
            assert(ns.D(b).done, 'generic walk could restyle the auto-apply button')
            browse:Hide(); browse:Show(); flush()
            browsePass(); flush()
            assert(skinCounts[b]==1, 'auto-apply button was restyled on reopen')
        ''')

    def test_late_button_is_skinned_on_next_show(self):
        self.counting()
        self.run_lua('''
            browsePass(); flush()
            browse.AutoApplyButton=CreateFrame('Button',nil,browse)
            local b=browse.AutoApplyButton
            assert(not skinCounts[b])
            browse:Hide(); browse:Show(); flush()
            assert(skinCounts[b]==1, 'late auto-apply button was not skinned on show')
            browse:Hide(); browse:Show(); flush()
            assert(skinCounts[b]==1, 'late auto-apply button was skinned twice')
        ''')

    def test_missing_button_leaves_browse_pass_intact(self):
        self.counting()
        self.run_lua('''
            browse.AutoApplyButton=nil
            browsePass(); flush(); browse:Hide(); browse:Show(); flush()
            assert(ns.D(browse).roleBar, 'browse extras stopped without the optional button')
        ''')


if __name__ == '__main__':
    unittest.main()
