"""Run: python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_data_broker.py -v
The 悬浮窗 (DataBroker.BrokerPanel) is painted by our shell, so the skin's window
colour and 背景不透明度 reach it live, without a title band.
"""
import unittest
import test_regressions as regression


class DataBrokerTests(unittest.TestCase):
    setUp = regression.RegressionTests.setUp
    run_lua = regression.RegressionTests.run_lua

    def boot(self):
        self.run_lua('''
            ns.skip={}
            ns.S.Panel=function(f,opts) f.panelOpts=opts; ns.S.FadeRegions(f) end
        ''')
        self.lua.execute("assert(loadstring(...))('MeetingStoneEllesmereUI',ns)",
                         (regression.ROOT/'Widgets.lua').read_text(encoding='utf-8'))
        self.run_lua('''
            function runPass(name, mod)
                for i=1,30 do
                    local n,value=debug.getupvalue(ns.Boot,i)
                    if n=='PASSES' then
                        for _,pass in ipairs(value) do if pass[1]==name then return pass[2](mod) end end
                    end
                end
                error(name..' pass not found')
            end
            panel=CreateFrame('Button',nil,main); panel:SetSize(160,26)
            panel.backdrop={}
            function panel:SetBackdrop(b) self.backdrop=b end
            broker={BrokerPanel=panel,BrokerText=panel:CreateFontString(),BrokerIcon=panel:CreateTexture()}
            runPass('DataBroker',broker)
        ''')

    def test_logo_stays_visible_through_restrip(self):
        self.boot()
        self.run_lua('''
            local icon, host = broker.BrokerIcon, ns.D(panel).iconHost
            assert(host and host:GetParent()==panel and host.allPoints==panel, 'logo host is not over the panel')
            assert(icon:GetParent()==host, 'logo still sits on the panel the skin fades')
            assert(icon:GetAlpha()==1, 'logo was left faded')
            for _,r in ipairs(panel.regions) do assert(r~=icon, 'logo still in the panel region list') end
            -- EllesmereUI's restrip fades every texture of a registered frame again.
            ns.S.FadeRegions(panel)
            assert(icon:GetAlpha()==1, 'restrip faded the logo')
            runPass('DataBroker',broker)
            assert(ns.D(panel).iconHost==host and icon:GetParent()==host and icon:GetAlpha()==1)
        ''')

    def test_floating_panel_follows_window_opacity_without_title_band(self):
        self.boot()
        self.run_lua('''
            local d=ns.D(panel)
            assert(panel.backdrop==nil, 'MeetingStone backdrop was left under ours')
            assert(panel.panelOpts and panel.panelOpts.noBg, 'EUI drew its own fixed-opacity fill')
            assert(ns.surfaces[panel], 'floating panel is not repainted by setting changes')
            assert(d.bg.color[4]==ns.Get('bgAlpha'))
            assert(not d.topBar or not d.topBar:IsShown(), '26px panel got the 25px title band')
            local _,host,_,x,y=unpack(d.bg.points.TOPLEFT)
            assert(host==d.bgHost and x==0 and y==0, 'body does not start at the panel top')
            assert(d.bgHost.allPoints==panel)

            ns.Set('bgAlpha',0.35)
            assert(d.bg.color[4]==0.35, 'opacity change did not reach the floating panel')
            ns.Set('bgColor',{0.2,0.3,0.4})
            local r,g,b,a=unpack(d.bg.color)
            assert(r==0.2 and g==0.3 and b==0.4 and a==0.35)
            ns.Set('topBar',true); assert(not d.topBar or not d.topBar:IsShown())
            assert(d.bg.points.TOPLEFT[5]==0)

            -- A repeat pass (setting reload, late module) neither stacks layers nor
            -- brings the band back.
            local host0, n=d.bgHost, #panel.children
            runPass('DataBroker',broker)
            assert(d.bgHost==host0 and #panel.children==n)
            assert(not d.topBar or not d.topBar:IsShown())
        ''')

    def test_title_band_option_is_per_frame(self):
        self.boot()
        self.run_lua('''
            local window=CreateFrame('Frame',nil,main); window:SetSize(400,300)
            ns.Shell(window)
            local d=ns.D(window)
            ns.Set('topBar',true)
            assert(d.topBar:IsShown() and d.bg.points.TOPLEFT[5]==-25)
            assert(not ns.D(panel).topBar or not ns.D(panel).topBar:IsShown())
            ns.Set('topBar',false)
            assert(not d.topBar:IsShown() and d.bg.points.TOPLEFT[5]==0)
        ''')

    def test_missing_module_or_panel_is_ignored(self):
        self.boot()
        self.run_lua('''
            runPass('DataBroker',{})
            runPass('DataBroker',nil)
        ''')


if __name__ == '__main__':
    unittest.main()
