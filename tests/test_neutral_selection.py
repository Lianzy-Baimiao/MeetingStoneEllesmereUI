"""Selected state colour is independent of permanent dark borders."""
import unittest
import test_accent_style as accent


class SelectionStateTests(unittest.TestCase):
    setUp=accent.AccentStyleTests.setUp
    run_lua=accent.AccentStyleTests.run_lua

    def test_square_colour_and_position_in_both_compact_sizes(self):
        self.run_lua("""
            for _,size in ipairs({20,32}) do
                local c=GUI:GetClass('CheckBox'):New(main); c:SetSize(size,22); ns.SkinSwitch(c)
                local s=ns.D(c).switch; local left=s.knob:GetLeft()
                sameColor(s.thumb[1],.40,.40,.40); dark(s.edge[1])
                c:Click(); green(s.thumb[1]); dark(s.edge[1]); assert(s.knob:GetLeft()>left)
                c:SetChecked(false); sameColor(s.thumb[1],.40,.40,.40)
                assert(s.knob:GetLeft()==left)
            end
        """)

    def test_class_colour_resolves_player_token_not_localized_name(self):
        self.run_lua("""
            ns.Set('useClassColor',true)
            local c=GUI:GetClass('CheckBox'):New(main); c:SetChecked(true); ns.SkinSwitch(c)
            local s=ns.D(c).switch
            for _,case in ipairs({{'PRIEST',1,1,1},{'WARRIOR',.78,.61,.43},{'DEATHKNIGHT',.77,.12,.23}}) do
                UnitClass=function() return '本地化名称',case[1] end
                C_ClassColor.GetClassColor=function(token)
                    assert(token==case[1]); return {r=case[2],g=case[3],b=case[4]}
                end
                ns.RefreshAccentStyle(); sameColor(s.thumb[1],case[2],case[3],case[4]); dark(s.edge[1])
            end
        """)

    def test_multiselect_check_is_legible_on_light_and_dark_class_fills(self):
        self.run_lua("""
            local view=CreateFrame('Frame',nil,main); ns.D(view).selectionList=true
            local c=GUI:GetClass('CheckBox'):New(view); c:SetChecked(true); ns.SkinSwitch(c)
            local s=ns.D(c).switch; green(s.track[1]); assert(s.tick.desaturated)
            assert(s.tick.vertexColor[1]==.04 and s.tick:IsShown())
            ns.Set('useClassColor',true)
            C_ClassColor.GetClassColor=function() return {r=.77,g=.12,b=.23} end
            ns.RefreshAccentStyle(); assert(s.tick.vertexColor[1]==1)
            C_ClassColor.GetClassColor=function() return {r=1,g=1,b=1} end
            ns.RefreshAccentStyle(); assert(s.tick.vertexColor[1]==.04)
            dark(s.edge[1]); c:Disable(); assert(s.host:GetAlpha()==.4 and s.tick:IsShown())
        """)

    def test_rejected_click_resets_square_and_reset_does_not_change_feature(self):
        self.run_lua("""
            local c=GUI:GetClass('CheckBox'):New(main); ns.SkinSwitch(c); local s=ns.D(c).switch
            c:SetScript('OnClick',function(self) self:SetChecked(false) end)
            c:Click(); assert(not c:GetChecked()); sameColor(s.thumb[1],.40,.40,.40)
            c:SetChecked(true); c:Disable(); ns.Set('useClassColor',true); ns.ResetAll()
            green(s.thumb[1]); dark(s.edge[1]); assert(c:GetChecked() and s.host:GetAlpha()==.4)
        """)

    def test_repeated_clicks_and_repaints_do_not_accumulate_or_replace_controls(self):
        self.run_lua("""
            local view=CreateFrame('Frame',nil,main); ns.D(view).selectionList=true
            local a=GUI:GetClass('CheckBox'):New(main); local b=GUI:GetClass('CheckBox'):New(view)
            local count=0; local fn=function() count=count+1 end
            a:SetScript('OnClick',fn); b:SetScript('OnClick',fn); ns.SkinSwitch(a); ns.SkinSwitch(b)
            local sa,sb=ns.D(a).switch,ns.D(b).switch; local tick=sb.tick; local n=#frames
            for i=1,200 do
                a:Click(); b:Click(); ns.Set('useClassColor',i%2==0)
                ns.SkinSwitch(a); ns.SkinSwitch(b); dark(sa.edge[1]); dark(sb.edge[1])
            end
            assert(#frames==n and sb.tick==tick and count==400 and #C_Timer.pending==0)
            assert(a:GetScript('OnClick')==fn and b:GetScript('OnClick')==fn)
        """)


if __name__=='__main__': unittest.main()
