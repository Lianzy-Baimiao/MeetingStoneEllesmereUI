"""Season dungeon bulk selection: native checkbox callbacks remain the owner."""
import unittest
import test_regressions as fixtures

class DungeonBulkTests(unittest.TestCase):
    setUp = fixtures.RegressionTests.setUp
    run_lua = fixtures.RegressionTests.run_lua

    def add_dungeons(self):
        self.run_lua('''
            dungeonRows={}; savedActivities={}; dungeonSaves=0
            -- Numeric activity group IDs are mixed with string role keys and
            -- the untagged minimum-rating row, as in MeetingStoneEX's MD array.
            local md={browse.MD[1]}
            for i,id in ipairs({101,205,309,412,518,620,723,827}) do
                local row=CreateFrame('Frame',nil,browse.BlzFilterPanel.Inset)
                row:SetHeight(20); row.dataValue=id
                row.Check=GUI:GetClass('CheckBox'):New(row)
                row.Check:SetChecked(i%2==0); savedActivities[id]=i%2==0
                row.Check:SetScript('OnClick',function(self)
                    savedActivities[id]=self:GetChecked(); dungeonSaves=dungeonSaves+1
                    row.labelAlpha=self:GetChecked() and 1 or .5
                end)
                table.insert(md,row); table.insert(dungeonRows,row)
            end
            for i=2,#browse.MD do table.insert(md,browse.MD[i]) end
            ratingRow=CreateFrame('Frame',nil,browse.BlzFilterPanel.Inset)
            ratingRow.MinBox=CreateFrame('EditBox',nil,ratingRow)
            ratingRow.MinBox:SetNumber(1800)
            ratingRow.Check=GUI:GetClass('CheckBox'):New(ratingRow)
            ratingRow.Check:SetChecked(true)
            ratingRow.Check:SetScript('OnClick',function() error('bulk touched minimum rating') end)
            table.insert(md,ratingRow); browse.MD=md
        ''')

    def test_all_and_none_save_only_changed_dungeon_checkboxes(self):
        self.add_dungeons()
        self.run_lua('''
            browsePass(); browse.AdvButton:Click(); local u=ns.D(browse).unifiedFilters
            assert(u.dungeonAll and u.dungeonNone, 'missing all/none actions')
            for _,row in ipairs(dungeonRows) do ns.SkinSwitch(row.Check) end
            u.dungeonAll:Click()
            for _,row in ipairs(dungeonRows) do
                assert(row.Check:GetChecked() and savedActivities[row.dataValue], 'checkbox not saved')
                local s=ns.D(row.Check).switch; assert(s.knob:GetLeft()>s.host:GetLeft()+2)
            end
            assert(dungeonSaves==4, 'already-selected dungeons were toggled')
            u.dungeonAll:Click(); assert(dungeonSaves==4, 'select all is not idempotent')
            u.dungeonNone:Click()
            for _,row in ipairs(dungeonRows) do
                assert(not row.Check:GetChecked() and not savedActivities[row.dataValue])
                assert(row.labelAlpha==.5, 'native label callback was skipped')
                local s=ns.D(row.Check).switch; assert(s.knob:GetLeft()==s.host:GetLeft()+2)
            end
            assert(dungeonSaves==12)
            u.dungeonNone:Click(); assert(dungeonSaves==12)
            assert(browse.searches==0, 'bulk selection launched per-dungeon searches')
            browse.RefreshFilterButton:Click(); assert(browse.searches==1)
        ''')

    def test_roles_minimum_rating_and_advanced_values_are_untouched(self):
        self.add_dungeons()
        self.run_lua('''
            browsePass(); browse.AdvButton:Click(); local u=ns.D(browse).unifiedFilters
            local bar=ns.D(browse).roleBar
            bar[1].real.Check:Click(); bar[5].real.Check:Click()
            browse.filters[1].MinBox:SetNumber(2400)
            u.dungeonAll:Click(); u.dungeonNone:Click()
            assert(bar[1].real.saved and bar[5].real.saved)
            assert(bar[1].proxy:GetChecked() and bar[5].proxy:GetChecked())
            assert(not bar[2].proxy:GetChecked() and not bar[3].proxy:GetChecked())
            assert(ratingRow.MinBox:GetNumber()==1800 and ratingRow.Check:GetChecked())
            assert(browse.filters[1].MinBox:GetNumber()==2400)
        ''')

    def test_actions_only_show_for_season_dungeons(self):
        self.add_dungeons()
        self.run_lua('''
            browsePass(); browse.AdvButton:Click(); local u=ns.D(browse).unifiedFilters
            assert(u.dungeonAll:IsVisible() and u.dungeonNone:IsVisible())
            assert(u.dungeonAll:GetRight()<u.dungeonNone:GetLeft(), 'bulk buttons overlap')
            assert(u.dungeonAll:GetBottom()>browse.BlzFilterPanel.Inset:GetTop(), 'bulk buttons cover rows')
            browse.ActivityDropdown:SetItem({value='custom-pve',categoryId=6})
            assert(not u.dungeonAll:IsVisible() and not u.dungeonNone:IsVisible())
            u.dungeonAll:Click(); assert(dungeonSaves==0, 'inactive dungeon action mutated state')
            browse.ActivityDropdown:SetItem({value='mplus',categoryId=2})
            assert(u.dungeonAll:IsVisible()); u.dungeonAll:Click()
            u.close:Click(); browse.AdvButton:Click()
            for _,row in ipairs(dungeonRows) do assert(row.Check:GetChecked()) end
        ''')

    def test_late_ex_init_and_repeated_setup(self):
        self.add_dungeons()
        self.run_lua('''
            local md,blz,ex,button=browse.MD,browse.BlzFilterPanel,browse.ExFilterPanel,browse.ExSearchButton
            browse.MD=nil; browse.BlzFilterPanel=nil; browse.ExFilterPanel=nil; browse.ExSearchButton=nil
            browse.EX_INIT=function(self)
                self.MD=md; self.BlzFilterPanel=blz; self.ExFilterPanel=ex; self.ExSearchButton=button
            end
            browsePass(); browse.AdvButton:Click(); local u=ns.D(browse).unifiedFilters
            assert(not u.dungeonAll:IsVisible())
            browse:EX_INIT(); assert(u.dungeonAll:IsVisible())
            local count=#frames
            browsePass(); browsePass(); assert(#frames==count, 'duplicate bulk controls')
            u.dungeonAll:Click(); assert(dungeonSaves==4, 'duplicate bulk callbacks')
        ''')

    def test_no_buttons_without_dungeon_ids(self):
        self.run_lua('''
            browsePass(); browse.AdvButton:Click(); local u=ns.D(browse).unifiedFilters
            assert(u.dungeonAll and not u.dungeonAll:IsVisible())
            assert(not u.dungeonNone:IsVisible())
        ''')

    def test_hidden_and_disabled_controls_are_not_changed(self):
        self.add_dungeons()
        self.run_lua('''
            dungeonRows[1]:Hide(); dungeonRows[2].Check:Hide(); dungeonRows[3].Check:Disable()
            browsePass(); browse.AdvButton:Click(); local u=ns.D(browse).unifiedFilters
            u.dungeonNone:Click(); u.dungeonAll:Click()
            assert(not savedActivities[101] and savedActivities[205] and not savedActivities[309])
            for i=4,#dungeonRows do assert(savedActivities[dungeonRows[i].dataValue]) end
        ''')

if __name__ == '__main__':
    unittest.main()
