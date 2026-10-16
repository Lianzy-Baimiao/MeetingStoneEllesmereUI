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

    def test_button_row_uses_one_gap_including_late_auto_apply(self):
        self.run_lua('''
            local function anchored(b)
                b:ClearAllPoints()
                b:SetPoint('TOPRIGHT',browse.RefreshButton,'TOPLEFT',0,0)
                b:SetPoint('BOTTOMRIGHT',browse.RefreshButton,'BOTTOMLEFT',0,0)
                return b
            end
            local function check(b)
                local refresh, adv = browse.RefreshButton, browse.AdvButton
                local gap = adv:GetLeft() - refresh:GetRight()
                assert(gap > 0, 'refresh and filter buttons touch or overlap: '..gap)
                assert(b:GetNumPoints()==2, 'auto-apply anchors piled up')
                for i=1,2 do
                    local point, rel, relPoint, x, y = b:GetPoint(i)
                    assert(rel==refresh and y==0, point)
                    assert(x==-gap, ('%s gap %s, row gap %s'):format(point, -x, gap))
                end
            end
            browse.AutoApplyButton=anchored(CreateFrame('Button',nil,browse))
            browsePass(); flush(); check(browse.AutoApplyButton)
            browse:Hide(); browse:Show(); flush(); check(browse.AutoApplyButton)
            -- EX can build the button after the first pass; the next show adopts it.
            browse.AutoApplyButton=anchored(CreateFrame('Button',nil,browse))
            browse:Hide(); browse:Show(); flush(); check(browse.AutoApplyButton)
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
