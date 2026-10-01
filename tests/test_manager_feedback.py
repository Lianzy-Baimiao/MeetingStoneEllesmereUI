"""2026-10-02 client log: unset headings abort layout; -1 font reaches EUI."""
import unittest
import test_regressions as regression
import test_table_panels as tables

class ManagerFeedbackTests(unittest.TestCase):
    setUp = regression.RegressionTests.setUp
    run_lua = regression.RegressionTests.run_lua

    def load(self, name, addon=False):
        source=(regression.ROOT/name).read_text(encoding='utf-8-sig')
        if addon: self.lua.execute("assert(loadstring(...))('MeetingStoneEllesmereUI',ns)",source)
        else: self.lua.execute(source)

    def strict_fonts(self):
        self.load('tests/strict_fonts_mock.lua')

    def pages(self):
        tables.TablePanelTests.setup_pages(self)
        # The old native cover starts at x=180, before the widened 208px sidebar.
        self.run_lua("ManagerPanel.ApplicantListBlocker:SetPoint('TOPLEFT',ManagerPanel,'TOPLEFT',180,0)")
        self.strict_fonts()

    def core_fonts(self, strict=True):
        self.run_lua("""
            EllesmereUI={RegisterSkin=function() end}
            errors={}; geterrorhandler=function() return function(e) errors[#errors+1]=e end end
            SECRET={}; issecretvalue=function(value) return value==SECRET end
            Theme={fontPath='Fonts/theme.ttf',fontFlag='',fontShadow=false}
            EUI={PrimeFontShadow=function() shadowCalls=(shadowCalls or 0)+1 end}
            WSkin=ns.S
        """)
        self.load('Core.lua',addon=True)
        self.load('tests/fixtures/EUIFont-20261002.lua')
        if strict: self.strict_fonts()

    def test_first_show_does_not_abort_before_blocker_alignment(self):
        self.pages()
        self.run_lua("""
            setupTablePages()
            assert(ManagerPanel.ApplicantListBlocker:GetLeft()>CreatePanel:GetRight(), 'create overlay covers inputs')
            assert(ManagerPanel.ApplicantListBlocker:GetLeft()==ApplicantPanel:GetLeft())
            local h=ns.D(IgnoreListPanel).tablePanel.heading
            assert(h:GetText()=='屏蔽玩家列表 · 勾选后批量移除')
            local _,height=h:GetFont(); assert(height>0)
        """)

    def test_auto_invite_aligns_to_left_input_column_without_changing_click(self):
        tables.TablePanelTests.setup_pages(self)
        self.run_lua("""
            local clicks=0; local click=function() clicks=clicks+1 end
            CreateAuto:SetScript('OnClick',click); CreateAuto:SetChecked(true)
            setupTablePages()
            assert(CreateAuto:GetLeft()==CreatePanel:GetLeft(), 'auto invite is shifted away from sidebar left edge')
            assert(CreateAuto:GetBottom()>CreatePanel:GetTop())
            assert(CreateAuto:GetScript('OnClick')==click and CreateAuto:GetChecked() and clicks==0)
            CreateAuto:Click(); assert(clicks==1)
        """)

    def test_walk_skips_uninitialized_font_until_native_owner_sets_it(self):
        self.core_fonts()
        self.run_lua("""
            local f=CreateFrame('Frame',nil,main); local fs=f:CreateFontString()
            ns.Walk(f)
            assert(#errors==0, errors[1])
            assert(not ns.D(fs).baseSize and not ns.fonted[fs])
            fs:SetFont('Fonts/native.ttf',14,'OUTLINE'); fs:SetText('ready')
            ns.Walk(f)
            assert(#errors==0, errors[1])
            assert(ns.D(fs).baseSize==14 and ns.fonted[fs])
        """)

    def test_invalid_or_secret_metrics_are_not_sent_to_eui_or_cached(self):
        self.core_fonts()
        self.run_lua("""
            local owner=CreateFrame('Frame',nil,main)
            for _,size in ipairs({-1,0,0/0,math.huge,SECRET}) do
                local fs=owner:CreateFontString(nil,'OVERLAY','GameFontNormal')
                fs.fontPath='Fonts/native.ttf'; fs.fontSize=size
                ns.Font(fs)
                assert(not ns.D(fs).baseSize and not ns.fonted[fs])
            end
            local fs=owner:CreateFontString(nil,'OVERLAY','GameFontNormal')
            fs.fontPath=SECRET; fs.fontSize=14; ns.Font(fs)
            assert(not ns.fonted[fs] and not shadowCalls and #errors==0)
        """)

    def test_valid_font_delta_remains_noncompounding_and_widget_labels_owned(self):
        self.core_fonts()
        self.run_lua("""
            local f=CreateFrame('Frame',nil,main); local fs=f:CreateFontString()
            fs:SetFont('Fonts/native.ttf',14,'OUTLINE')
            ns.Set('fontDelta',-2); ns.Font(fs)
            local path,size=fs:GetFont(); assert(path=='Fonts/theme.ttf' and size==12)
            for i=1,10 do ns.Font(fs) end
            local _,size=fs:GetFont(); assert(size==12 and ns.D(fs).baseSize==14)
            ns.Set('fontDelta',4); local _,size=fs:GetFont(); assert(size==18)
            local cb=CreateFrame('CheckButton',nil,f)
            cb.Text=cb:CreateFontString(nil,'OVERLAY','GameFontNormal')
            cb.Text:SetFont('Fonts/button.ttf',13,'')
            ns.Font(cb.Text)
            assert(not ns.fonted[cb.Text] and cb.Text.fontSize==13)
            local owned=f:CreateFontString(); ns.ClaimFont(owned); ns.Font(owned)
            assert(not ns.fonted[owned] and owned.fontUnset)
            assert(#errors==0, errors[1])
        """)

    def test_real_visibility_methods_keep_full_blocker_and_right_only_cover(self):
        self.core_fonts(strict=False)
        self.pages()
        self.load('tests/fixtures/ManagerBlockers-20261002.lua')
        self.run_lua("""
            local p=ManagerPanel; local cover=p.ApplicantListBlocker
            local setBlocker,setApplicants=p.SetBlocker,p.SetApplicantListBlocker
            p.FullBlocker:Hide(); p:SetApplicantListBlocker('请创建活动')
            setupTablePages(); ns.QueueWalk(p); flush(); flush()
            assert(#errors==0, errors[1])
            for i=1,30 do
                p:Hide(); CreatePanel:Hide(); ApplicantPanel:Hide()
                main:SetSize(i%2==0 and 922 or 1000,447)
                p:Show(); CreatePanel:Show(); ApplicantPanel:Show()
                ns.Set('labelFontSize',i%2==0 and 12 or 18)
                ns.ApplyTablePanels(); ns.QueueWalk(p); flush(); flush()
                assert(cover:IsShown() and cover:GetText()=='请创建活动')
                assert(cover:GetLeft()==ApplicantPanel:GetLeft() and cover:GetLeft()>CreatePanel:GetRight())
                assert(cover:GetRight()==p:GetRight() and cover:GetBottom()==p:GetBottom())
                assert(CreateAuto:GetLeft()==CreatePanel:GetLeft())
            end
            p:SetBlocker('正在创建活动',true)
            ns.ApplyTablePanels()
            assert(p.FullBlocker:IsShown() and not cover:IsShown(), 'skin bypassed full activity blocker')
            p:SetBlocker(false); p:SetApplicantListBlocker('请创建活动')
            ns.ApplyTablePanels(); assert(not p.FullBlocker:IsShown() and cover:IsShown())
            p:SetApplicantListBlocker(false); ns.ApplyTablePanels(); assert(not cover:IsShown())
            assert(p.SetBlocker==setBlocker and p.SetApplicantListBlocker==setApplicants)
            assert(#errors==0, errors[1])
        """)

    def test_onshow_reports_skin_failure_once_and_recovers_without_breaking_native_show(self):
        self.core_fonts(strict=False); self.pages()
        self.run_lua("""
            setupTablePages()
            local original=ns.S.GetFont
            ns.S.GetFont=function() error('intentional test font-provider failure') end
            for i=1,3 do
                IgnoreListPanel:Hide()
                local ok=pcall(function() IgnoreListPanel:Show() end)
                assert(ok, 'OnShow leaked skin error into native tab switch')
                flush(); flush()
            end
            assert(#errors==1 and errors[1]:find('intentional test font%-provider failure'))
            ns.S.GetFont=original
            IgnoreListPanel:Hide(); IgnoreListPanel:Show(); flush(); flush()
            assert(#errors==1 and #C_Timer.pending==0)
            local h=ns.D(IgnoreListPanel).tablePanel.heading
            assert(h:GetText()=='屏蔽玩家列表 · 勾选后批量移除')
        """)

if __name__=='__main__': unittest.main()
