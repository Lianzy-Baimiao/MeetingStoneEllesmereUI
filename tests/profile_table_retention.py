"""Secondary-page retention probe using real skin Lua and isolated WoW doubles.
Does not create activities, send invitations or touch live SavedVariables.
"""
from test_manager_feedback import ManagerFeedbackTests

def run():
    test = ManagerFeedbackTests(); test.setUp(); test.core_fonts(strict=False); test.pages()
    test.run_lua("""
        setupTablePages()
        function tableExercise(i)
            ManagerPanel:Hide(); CreatePanel:Hide(); ApplicantPanel:Hide()
            RecentPanel:Show(); IgnoreListPanel:Hide()
            RecentPanel.MemberList:Refresh()
            RecentPanel:Hide(); IgnoreListPanel:Show()
            IgnoreListPanel.IgnoreList:Refresh()
            IgnoreListPanel:Hide(); ManagerPanel:Show(); CreatePanel:Show(); ApplicantPanel:Show()
            ApplicantPanel.ApplicantList:Refresh()
            main:SetSize(i%2==0 and 922 or 1000,447)
            ns.Set('labelFontSize',i%2==0 and 12 or 18)
            ns.ApplyTablePanels()
            ns.QueueWalk(ManagerPanel); ns.QueueWalk(RecentPanel); ns.QueueWalk(IgnoreListPanel)
            flush(); flush()
            assert(#errors==0, errors[1])
        end
        function tableStats()
            local hooks=0
            for _,f in ipairs(frames) do
                for _,list in pairs(f.hooks) do hooks=hooks+#list end
            end
            return #frames,hooks,#C_Timer.pending,collectgarbage('count')
        end
    """)
    for batch in range(6):
        test.run_lua('for i=1,100 do tableExercise(i) end')
        before = test.lua.eval('collectgarbage("count")')
        test.run_lua('collectgarbage("collect"); collectgarbage("collect")')
        frames,hooks,timers,after = test.lua.eval('tableStats()')
        print(f'cycles={(batch+1)*100}: objects={frames}, script_hooks={hooks}, pending_timers={timers}, '
              f'Lua_KiB_before_GC={before:.1f}, after_GC={after:.1f}')
        if batch==0: baseline=frames,hooks,timers,after
        else:
            assert (frames,hooks,timers)==baseline[:3], 'retained controls/hooks/timers grew after warmup'
            assert after-baseline[3]<64, 'retained Lua memory grew after warmup'

def run_recent():
    from test_page_feedback import PageFeedbackTests
    test=PageFeedbackTests(); test.setUp(); test.recent()
    test.run_lua("""
        for _,manager in pairs(Recent.managers) do
            for i=2,150 do manager.players[i]={name='synthetic-'..i} end
        end
        setupTablePages()
        function recentExercise()
            RecentPanel.ActivityDropdown:SetValue('mplus')
            RecentPanel:LFG_LIST_AVAILABILITY_UPDATE()
            RecentPanel.ActivityDropdown:SetValue('2-0-0-0')
            RecentPanel.ActivityDropdown:SetValue(0)
            RecentPanel:Hide(); RecentPanel:Show(); setupTablePages()
            assert(#RecentPanel.MemberList.items==450)
            assert(#RecentPanel.ActivityDropdown:GetMenuTable()==5)
        end
    """)
    for batch in range(6):
        test.run_lua('for i=1,100 do recentExercise() end; collectgarbage("collect"); collectgarbage("collect")')
        stats=test.lua.eval('function() return #frames, #C_Timer.pending, collectgarbage("count") end')()
        print(f'recent_cycles={(batch+1)*100}: objects={stats[0]}, pending_timers={stats[1]}, after_GC_KiB={stats[2]:.1f}')
        if batch==0: baseline=stats
        else:
            assert stats[:2]==baseline[:2], 'recent view objects/timers grew'
            assert stats[2]-baseline[2]<64, 'recent view retention grew'

if __name__=='__main__':
    run()
    run_recent()

