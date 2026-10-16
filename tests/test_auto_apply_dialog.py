"""Run: python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_auto_apply_dialog.py -v
The real AutoApplyNote.lua popup gets the window shell and flat controls; the
borrowed Blizzard Description input only carries reversible chrome while open.
"""
import unittest
import test_regressions as regression

SETUP = r'''
local Frame=getmetatable(main)
for _,k in ipairs({'SetFrameStrata','SetBackdrop','SetAutoFocus','SetNumeric','SetMaxLetters'}) do
    Frame[k]=Frame[k] or function() end
end
function Frame:GetSize() return self.width, self.height end
calls={shell={},font={},button={},close={},marked={}}
ns.Shell=function(f) calls.shell[f]=(calls.shell[f] or 0)+1 end
ns.Font=function(fs,r) if fs then calls.font[fs]=r or true end end
ns.FontAll=function() end
ns.SkinButton=function(b) if b then calls.button[b]=(calls.button[b] or 0)+1 end end
ns.SkinClose=function(b) if b then calls.close[b]=(calls.close[b] or 0)+1 end end
local mark=ns.Mark
ns.Mark=function(f) calls.marked[f]=true; return mark(f) end
UIParent=CreateFrame('Frame'); UIParent.root=true; UIParent:SetSize(1920,1080)
LFGListApplicationDialog=CreateFrame('Frame',nil,UIParent); LFGListApplicationDialog:Hide()
Desc=CreateFrame('ScrollFrame',nil,LFGListApplicationDialog); Desc:SetSize(210,28)
Desc:SetPoint('BOTTOM',LFGListApplicationDialog,'BOTTOM',0,55)
DescArt=Desc:CreateTexture(); DescArt:SetAlpha(1)
DescEdit=CreateFrame('EditBox',nil,Desc); DescEdit:SetFont('stock',13,'')
Desc.EditBox=DescEdit; LFGListApplicationDialog.Description=Desc
function StaticPopupSpecial_Show(f) f:Show() end
function StaticPopupSpecial_Hide(f) f:Hide() end
C_LFGList={ClearApplicationTextFields=function() end}
function BuildEnv() end
controller={maxWaitSeconds=300}
function controller:GetStartRole() return 'HEALER' end
function controller:SetStatus(m) self.message=m end
function controller:Start() self.started=true end
browse.AutoApplyController=controller
Addon={GetModule=function() return browse end}
'''


class AutoApplyDialogTests(unittest.TestCase):
    setUp = regression.RegressionTests.setUp
    run_lua = regression.RegressionTests.run_lua

    def load(self):
        self.run_lua(SETUP)
        self.lua.execute((regression.ROOT / 'tests/fixtures/AutoApplyNote-20261016.lua')
                         .read_text(encoding='utf-8-sig'))

    def test_popup_is_skinned_once_with_title_in_band(self):
        self.load()
        self.run_lua('''
            browsePass(); flush()
            assert(controller.noteDialog==nil, 'skin created the popup')
            controller:RequestStart(); flush()
            local d=controller.noteDialog
            assert(d and d:IsShown() and calls.shell[d]==1)
            for _,key in ipairs({'WithNoteButton','WithoutNoteButton','CancelButton'}) do
                assert(calls.button[d[key]]==1 and calls.marked[d[key]], key)
            end
            local closes=0; for b,n in pairs(calls.close) do if b:GetParent()==d then assert(n==1); closes=closes+1 end end
            assert(closes==1, 'close button not styled exactly once')
            local title; for _,r in ipairs(d.regions) do
                local point,rel,_,_,y=r:GetPoint(1)
                if point=='TOP' and rel==d then title=r; assert(y==-6) end
            end
            assert(title and title:GetText():find('备注') and calls.font[title]==1)
            assert(ns.D(d.WaitInput).browseChrome.host:IsShown())
            d:Hide(); controller:RequestStart(); flush()
            assert(calls.shell[d]==1 and calls.button[d.WithNoteButton]==1, 'popup restyled on reopen')
        ''')

    def test_borrowed_description_releases_when_returned(self):
        self.load()
        self.run_lua('''
            browsePass(); controller:RequestStart(); flush()
            local d=controller.noteDialog; local s=ns.D(Desc).browseChrome
            assert(Desc:GetParent()==d and s and s.host:IsShown() and DescArt:GetAlpha()==0)
            local path=DescEdit:GetFont(); assert(path=='Fonts/theme.ttf')
            d:Hide()
            assert(Desc:GetParent()==LFGListApplicationDialog, 'note popup did not return the input')
            assert(not s.host:IsShown() and DescArt:GetAlpha()==1)
            local path,size=DescEdit:GetFont(); assert(path=='stock' and size==13)
            controller:RequestStart(); flush(); assert(s.host:IsShown() and DescArt:GetAlpha()==0)
            LFGListApplicationDialog:Show()
            assert(not d:IsShown() and not s.host:IsShown() and DescArt:GetAlpha()==1,
                'native application dialog opened over borrowed chrome')
        ''')

    def test_scripts_and_note_flow_stay_native(self):
        self.load()
        self.run_lua('''
            browsePass(); controller:RequestStart(); flush()
            local d=controller.noteDialog
            local onClick=d.WithoutNoteButton:GetScript('OnClick')
            d.WaitInput:SetText('45'); d.WithoutNoteButton:Click()
            assert(d.WithoutNoteButton:GetScript('OnClick')==onClick)
            assert(controller.started and controller.maxWaitSeconds==45 and not d:IsShown())
            assert(Desc:GetParent()==LFGListApplicationDialog and DescArt:GetAlpha()==1)
        ''')

    def test_missing_controller_is_ignored(self):
        self.run_lua('''
            browse.AutoApplyController=nil
            browsePass(); flush(); browse:Hide(); browse:Show(); flush()
            assert(ns.D(browse).roleBar, 'browse pass stopped without MeetingStoneEX auto-apply')
        ''')


if __name__ == '__main__':
    unittest.main()
