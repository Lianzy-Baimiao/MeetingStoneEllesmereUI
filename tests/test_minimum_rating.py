"""EX minimum-rating persistence, using native row/init/save callbacks."""
import unittest
import test_regressions as fixtures


class MinimumRatingTests(unittest.TestCase):
    run_lua = fixtures.RegressionTests.run_lua

    def setUp(self):
        fixtures.RegressionTests.setUp(self)
        for name in ('minimum_rating_mock.lua', 'fixtures/FilterBox-20261003.lua',
                     'fixtures/EXMinimumRating-20261003.lua'):
            self.lua.execute((fixtures.ROOT / 'tests' / name).read_text(encoding='utf-8-sig'))

    def test_disabled_rating_stays_off_after_reload_with_or_without_apply(self):
        for apply in (False, True):
            with self.subTest(apply=apply):
                self.setUp()
                self.run_lua('''
                    setupRating(1800)
                    assert(ratingRow.Check:GetChecked())
                    ratingRow.Check:Click()
                    assert(not ratingRow.Check:GetChecked())
                ''')
                if apply:
                    self.run_lua('browse.RefreshFilterButton:Click()')
                saved = self.lua.eval('savedFilter.minimumRating')
                self.setUp()  # RL: only the persisted Blizzard filter survives.
                self.lua.globals().reloadedRating = saved
                self.run_lua('''
                    setupRating(reloadedRating)
                    assert(not ratingRow.Check:GetChecked(),
                        'minimum rating re-enabled after disable/reload')
                    assert(savedFilter.minimumRating == 0, 'disabled rating still filters searches')
                ''')

    def test_disable_persists_immediately_without_apply_or_search(self):
        self.run_lua('''
            setupRating(1800)
            browse.RefreshButton:Disable()
            ratingRow.Check:Click()
            assert(savedFilter.minimumRating == 0, 'disable was not saved immediately')
            assert(browse.searches == 0, 'saving triggered a search during cooldown')
            assert(savedFilter.needsTank and savedFilter.activities[1] == 101)
            assert(savedFilter.customField == 'keep', 'unrelated filter data changed')
        ''')

    def test_later_native_role_and_apply_saves_do_not_restore_old_rating(self):
        self.run_lua('''
            setupRating(1800)
            ratingRow.Check:Click()
            for _, row in ipairs(browse.MD) do
                if row.dataValue == 'needsTank' then row.Check:Click() end
            end
            assert(savedFilter.minimumRating == 0, 'role save restored the captured rating')
            assert(not savedFilter.needsTank)
            browse.RefreshFilterButton:Click()
            assert(savedFilter.minimumRating == 0, 'apply restored the captured rating')
            assert(browse.searches == 1)
        ''')

    def test_reenable_and_lower_score_stay_in_sync_with_native_save(self):
        self.run_lua('''
            setupRating(1800)
            ratingRow.Check:Click()
            ratingRow.Check:Click()
            assert(savedFilter.minimumRating == 1800 and ratingRow.Check:GetChecked())
            ratingRow.MinBox:SetNumber(1200)
            assert(savedFilter.minimumRating == 1200, 'loaded score became a lower bound')
            browse.RefreshFilterButton:Click()
            assert(savedFilter.minimumRating == 1200, 'native save did not receive the edit')
        ''')

    def test_zero_edit_and_repeated_setup_do_not_reenable_or_resave(self):
        self.run_lua('''
            setupRating(1800)
            ratingRow.MinBox:SetNumber(0)
            assert(not ratingRow.Check:GetChecked() and savedFilter.minimumRating == 0)
            local saves = saveCount
            for i=1,100 do ns.SetupUnifiedFilters(browse) end
            assert(saveCount == saves, 'repeated layout saved or installed duplicate hooks')
            ratingRow.MinBox:SetNumber(900)
            assert(saveCount == saves + 1 and savedFilter.minimumRating == 900)
            assert(ratingRow.Check:GetChecked())
        ''')

    def test_positive_rating_survives_fresh_runtime(self):
        self.run_lua('setupRating(0); ratingRow.MinBox:SetNumber(2100)')
        saved = self.lua.eval('savedFilter.minimumRating')
        self.setUp()
        self.lua.globals().reloadedRating = saved
        self.run_lua('''
            setupRating(reloadedRating)
            assert(ratingRow.Check:GetChecked() and ratingRow.MinBox:GetNumber() == 2100)
            assert(saveCount == 0, 'loading changed the saved filter')
        ''')

    def test_advanced_reset_and_dungeon_bulk_leave_rating_alone(self):
        self.run_lua('''
            setupRating(1800)
            local u = ns.D(browse).unifiedFilters
            u.dungeonAll:Click(); u.dungeonNone:Click()
            browse.ResetFilterButton:Click()
            assert(savedFilter.minimumRating == 1800 and ratingRow.Check:GetChecked())
            assert(ratingRow.MinBox:GetNumber() == 1800)
        ''')

    def test_late_recreated_panel_gets_its_own_adapter(self):
        self.run_lua('''
            ns.SetupUnifiedFilters(browse)
            setupRating(1800)
            ratingRow.Check:Click()
            assert(savedFilter.minimumRating == 0)
            setupRating(savedFilter.minimumRating)
            assert(not ratingRow.Check:GetChecked())
            ratingRow.MinBox:SetNumber(600)
            browse.RefreshFilterButton:Click()
            assert(savedFilter.minimumRating == 600)
        ''')

    def test_fresh_zero_rating_can_be_enabled_and_saved(self):
        self.run_lua('''
            setupRating(0)
            ratingRow.Check:Click()
            assert(ratingRow.Check:GetChecked() and savedFilter.minimumRating > 0)
            browse.RefreshFilterButton:Click()
            assert(savedFilter.minimumRating == ratingRow.MinBox:GetNumber())
            ratingRow.Check:Click()
            assert(not ratingRow.Check:GetChecked() and savedFilter.minimumRating == 0)
        ''')

    def test_unrelated_range_with_hidden_maximum_is_not_adapted(self):
        self.run_lua('''
            local row = Addon:GetClass('FilterBox'):New(browse.BlzFilterPanel.Inset)
            row.Check:SetText('Other range')
            row.MinBox:SetMinMaxValues(100, 9999)
            row.MaxBox:SetMinMaxValues(9999, 9999); row.MaxBox:Hide()
            table.insert(browse.MD, row)
            ns.SetupUnifiedFilters(browse)
            assert(row.MinBox.minValue == 100 and row.MaxBox:GetNumber() == 9999)
            assert(not ns.D(row).minimumRating)
        ''')

    def test_missing_filter_api_does_not_break_filter_ui(self):
        self.run_lua('''
            C_LFGList = nil
            ns.SetupUnifiedFilters(browse)
            assert(ns.D(browse).unifiedFilters)
        ''')

    def test_zero_rating_initializes_disabled(self):
        self.run_lua('''
            setupRating(0)
            assert(not ratingRow.Check:GetChecked(), 'zero rating initialized enabled')
            assert(saveCount == 0, 'loading rewrote the saved filter')
        ''')


if __name__ == '__main__':
    unittest.main()
