"""Manager description height and the native three-piece vertical divider."""
import unittest
import test_regressions as regression
import test_table_panels as tables

class ManagerSpacingTests(unittest.TestCase):
    setUp = regression.RegressionTests.setUp
    run_lua = regression.RegressionTests.run_lua

    def pages(self):
        tables.TablePanelTests.setup_pages(self)
        self.run_lua(r"""
            VerticalLine = {}
            local Frame=getmetatable(main)
            function Frame:SetTexCoord(...) self.texCoords={...} end
        """)
        self.lua.execute((regression.ROOT/'tests/fixtures/VerticalLine-20261002.lua').read_text(encoding='utf-8'))
        self.lua.execute((regression.ROOT/'tests/fixtures/VerticalLineType-20261002.lua').read_text(encoding='utf-8'))
        self.run_lua(r"""
            local original=GUI.GetClass
            function GUI:GetClass(kind)
                if kind=='VerticalLine' then return VerticalLine end
                return original(self,kind)
            end
            NativeDivider=CreateFrame('Frame',nil,CreatePanel)
            AttachVerticalLineClass(VerticalLine, NativeDivider)
            VerticalLine.Constructor(NativeDivider)
            NativeDivider:SetPoint('TOPLEFT',CreatePanel,'TOPRIGHT',-3,5)
            NativeDivider:SetPoint('BOTTOMLEFT',CreatePanel,'BOTTOMRIGHT',-3,-5)
            ImportantIcon=CreatePanel:CreateTexture(); ImportantIcon:SetTexture('role-icon')
        """)

    def test_description_has_several_lines_without_overlapping_cards(self):
        self.pages()
        self.run_lua(r"""
            setupTablePages()
            for _,size in ipairs({12,14,18}) do
                ns.Set('labelFontSize',size); ns.ApplyTablePanels(); flush()
                assert(SummaryCard:GetHeight()>=80, 'description card is still too short')
                assert(Description:GetHeight()>=48, 'description viewport still loses its height to padding')
                assert(Description:GetTop()<=SummaryCard:GetTop()-size-10)
                assert(Description:GetBottom()>=SummaryCard:GetBottom()+6)
                assert(TitleCard:GetBottom()-4>=SummaryCard:GetTop())
                assert(SummaryCard:GetBottom()-4>=VoiceCard:GetTop())
                assert(CreatePanel:GetBottom()==VoiceCard:GetBottom())
                assert(CreatePanel.CreateButton:GetTop()<VoiceCard:GetBottom())
                assert(CreateAuto:GetBottom()>CreatePanel:GetTop())
            end
            local height=Description:GetHeight()
            main:SetHeight(main:GetHeight()+80); ns.ApplyTablePanels(); flush()
            assert(Description:GetHeight()==height+80, 'extra window height was not assigned to description')
        """)

    def test_description_keeps_editing_and_releases_borrowed_geometry(self):
        self.pages()
        self.run_lua(r"""
            local eb=CreatePanel.SummaryBox
            eb:SetHeight(500); eb:SetText('one\ntwo\nthree'); eb:SetFocus()
            local changed=function() end; eb:SetScript('OnTextChanged',changed)
            setupTablePages()
            local height=Description:GetHeight()
            assert(height>=48)
            assert(eb:GetHeight()==500 and eb:GetText()=='one\ntwo\nthree' and eb.focused)
            assert(eb:GetScript('OnTextChanged')==changed and Description.scrollChild==eb)
            CreatePanel:Hide()
            assert(Description.points.TOPLEFT[5]==-30 and Description.points.BOTTOMRIGHT[5]==15)
            CreatePanel:Show(); flush(); assert(Description:GetHeight()==height)
            local stock=CreateFrame('Frame',nil,main)
            Description:SetParent(stock)
            Description:ClearAllPoints()
            Description:SetPoint('TOPLEFT',stock,'TOPLEFT',7,-9)
            Description:SetPoint('BOTTOMRIGHT',stock,'BOTTOMRIGHT',-8,11)
            ns.ApplyTablePanels(); flush()
            assert(Description.points.TOPLEFT[2]==stock and Description.points.TOPLEFT[5]==-9)
            assert(not ns.D(Description).browseChrome.host:IsShown())
        """)

    def test_native_divider_is_removed_without_touching_other_art(self):
        self.pages()
        self.run_lua(r"""
            setupTablePages()
            assert(not NativeDivider:IsShown(), 'old Blizzard divider is still visible')
            assert(not ns.D(CreatePanel).tablePanel.divider, 'a replacement divider was created')
            assert(ImportantIcon:GetAlpha()==1 and ImportantIcon:IsShown())
            assert(ApplicantPanel:GetLeft()-CreatePanel:GetRight()==12)
            local count=#frames
            local hooks=#NativeDivider.hooks.OnShow
            for i=1,30 do setupTablePages() end
            assert(#frames==count and #NativeDivider.hooks.OnShow==hooks)
            assert(hooks==1)
        """)

    def test_native_reborrow_and_repeated_resize_do_not_accumulate_objects(self):
        self.pages()
        self.run_lua(r"""
            setupTablePages(); local count=#frames
            collectgarbage('collect'); local before=collectgarbage('count')
            for i=1,200 do
                CreatePanel:Hide()
                -- Native TitleWidget:SetObject runs again as the form opens.
                Description:ClearAllPoints()
                Description:SetPoint('TOPLEFT',SummaryCard,'TOPLEFT',10,-30)
                Description:SetPoint('BOTTOMRIGHT',SummaryCard,'BOTTOMRIGHT',-10,15)
                CreatePanel:Show(); Description:RunScript('OnShow'); flush()
                main:SetHeight(i%2==0 and 447 or 527)
                ns.ApplyTablePanels(); flush()
                assert(Description:GetHeight()>=48)
                assert(not NativeDivider:IsShown())
                assert(not ns.D(CreatePanel).tablePanel.divider)
            end
            collectgarbage('collect'); collectgarbage('collect')
            assert(#frames==count and #C_Timer.pending==0)
            assert(collectgarbage('count')-before<64)
        """)

    def test_divider_detection_does_not_hide_unrelated_child_art(self):
        self.pages()
        self.run_lua(r"""
            local other=CreateFrame('Frame',nil,CreatePanel); other:SetWidth(12)
            local art=other:CreateTexture()
            art:SetTexture([[Interface\FriendsFrame\UI-ChannelFrame-VerticalBar]])
            -- Remove the known divider so discovery must inspect this child.
            NativeDivider:SetParent(main)
            setupTablePages()
            assert(art:GetAlpha()==1 and not ns.D(CreatePanel).tablePanel.divider)
            NativeDivider:SetParent(CreatePanel); ns.ApplyTablePanels(); flush()
            assert(not NativeDivider:IsShown())
        """)

    def test_type_hiding_is_limited_to_create_panel_not_other_pages(self):
        self.pages()
        self.run_lua(r"""
            local elsewhere=CreateFrame('Frame',nil,RecentPanel)
            AttachVerticalLineClass(VerticalLine,elsewhere)
            VerticalLine.Constructor(elsewhere)
            setupTablePages()
            assert(elsewhere:IsShown() and not elsewhere.hooks.OnShow)
            assert(ImportantIcon:IsShown())
            assert(ManagerPanel.ApplicantListBlocker:IsShown())
        """)

    def test_missing_class_does_not_abort_layout_and_is_retried(self):
        self.pages()
        self.run_lua(r"""
            local lookup=GUI.GetClass
            GUI.GetClass=function() error('class not initialized') end
            setupTablePages()
            assert(NativeDivider:IsShown() and Description:GetHeight()>=48)
            GUI.GetClass=lookup
            setupTablePages()
            assert(not NativeDivider:IsShown())
        """)

    def test_fractional_client_width_does_not_leave_blizzard_divider(self):
        self.pages()
        self.run_lua(r"""
            -- WoW geometry is floating point, not necessarily exactly 12.
            NativeDivider:SetWidth(12.000001)
            GetFileIDFromPath=function() return 123456 end
            for _,r in ipairs({NativeDivider:GetRegions()}) do r:SetTexture(123456) end
            setupTablePages()
            assert(not NativeDivider:IsShown(), 'fractional-width Blizzard divider is still visible')
        """)

    def test_type_detection_does_not_depend_on_texture_lookup(self):
        self.pages()
        self.run_lua(r"""
            GetFileIDFromPath=nil
            for _,r in ipairs({NativeDivider:GetRegions()}) do r:SetTexture(123456) end
            setupTablePages()
            assert(not NativeDivider:IsShown(), 'numeric-texture divider escaped type detection')
        """)

    def test_remove_decoration_instead_of_drawing_another_vertical_line(self):
        self.pages()
        self.run_lua(r"""
            setupTablePages()
            local replacement=ns.D(CreatePanel).tablePanel.divider
            assert(not replacement or not replacement:IsShown(), 'skin still draws a replacement vertical line')
        """)

    def test_native_reshow_cannot_bring_back_divider(self):
        self.pages()
        self.run_lua(r"""
            local shows=0
            NativeDivider:SetScript('OnShow',function() shows=shows+1 end)
            local original=NativeDivider:GetScript('OnShow')
            setupTablePages()
            NativeDivider:SetAlpha(1)
            for _,r in ipairs({NativeDivider:GetRegions()}) do r:SetAlpha(1); r:Show() end
            NativeDivider:Show()
            assert(not NativeDivider:IsShown(), 'native Show brought back the old divider')
            assert(shows==1 and NativeDivider:GetScript('OnShow')==original)
        """)

    def test_divider_file_id_is_also_recognized(self):
        self.pages()
        self.run_lua(r"""
            GetFileIDFromPath=function() return 123456 end
            for _,r in ipairs({NativeDivider:GetRegions()}) do r:SetTexture(123456) end
            setupTablePages()
            assert(not NativeDivider:IsShown())
        """)

if __name__=='__main__': unittest.main()
