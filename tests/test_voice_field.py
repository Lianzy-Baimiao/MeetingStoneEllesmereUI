"""Run: python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_voice_field.py -v
The borrowed 语音聊天 box is the third row of the item level/score column and
gets its native width and anchors back whenever it is released.
"""
import unittest
import test_regressions as regression
import test_table_panels as tables


class VoiceFieldTests(unittest.TestCase):
    setUp = regression.RegressionTests.setUp
    run_lua = regression.RegressionTests.run_lua
    setup_pages = tables.TablePanelTests.setup_pages

    def test_voice_row_matches_item_level_and_score(self):
        self.setup_pages()
        self.run_lua('''
            setupTablePages()
            local p=CreatePanel; local f,il,sc=p.VoiceBox,p.ItemLevel,p.Score
            for _,box in ipairs({il,sc}) do
                assert(f:GetLeft()==box:GetLeft() and f:GetWidth()==box:GetWidth(), 'voice box left the column')
                assert(f:GetHeight()==box:GetHeight())
            end
            assert(il:GetBottom()-sc:GetTop()==sc:GetBottom()-f:GetTop(), 'uneven row spacing')
            for _,cb in ipairs({p.PrivateGroup,p.CrossFactionGroup}) do
                assert(cb:GetTop()<=f:GetBottom(), 'checkbox overlaps the voice box')
                assert(cb:GetBottom()>=VoiceCard:GetBottom(), 'checkbox below the card')
            end
            local point,rel,relPoint,x=VoiceLabel:GetPoint(1)
            assert(point=='RIGHT' and rel==f and relPoint=='LEFT' and x==-5, 'label spacing differs from the column')
            local _,size=VoiceLabel:GetFont(); assert(size==ns.Get('labelFontSize'))
        ''')

    def test_release_restores_native_geometry(self):
        self.setup_pages()
        self.run_lua('''
            setupTablePages()
            local f=CreatePanel.VoiceBox; assert(f:GetWidth()==112)
            CreatePanel:Hide()
            local point,rel,relPoint,x,y=f:GetPoint(1)
            assert(f:GetWidth()==84 and f:GetHeight()==18)
            assert(point=='TOP' and rel==CreatePanel.Score and relPoint=='BOTTOM' and x==0 and y==-3)
            CreatePanel:Show(); flush(); assert(f:GetWidth()==112 and f:GetHeight()==24)
            f:SetParent(main); assert(f:GetWidth()==84, 'width kept after leaving the card')
        ''')

    def test_native_reanchor_is_corrected_in_the_same_pass(self):
        self.setup_pages()
        self.run_lua('''
            setupTablePages()
            local f=CreatePanel.VoiceBox; local left=f:GetLeft()
            VoiceCard:Hide(); VoiceCard:Show()
            assert(f:GetWidth()==112 and f:GetHeight()==24 and f:GetLeft()==left,
                'native voice geometry would be drawn for a frame')
        ''')


if __name__ == '__main__':
    unittest.main()
