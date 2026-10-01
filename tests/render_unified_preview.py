"""Layout schematic from executed Lua coordinates, NOT a WoW screenshot."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from test_regressions import RegressionTests

ROOT = Path(__file__).resolve().parent
FONT = 'C:/Windows/Fonts/msyh.ttc'
SCALE = 2
font = ImageFont.truetype(FONT, 12 * SCALE)
title_font = ImageFont.truetype(FONT, 15 * SCALE)
canvas = Image.new('RGB', (980 * SCALE, 525 * SCALE), '#121b20')
pen = ImageDraw.Draw(canvas)
pen.text((18*SCALE, 10*SCALE), '统一筛选布局示意（Lua 坐标；非游戏截图）', font=title_font, fill='#ffffff')

def point(frame):
    p = frame.GetPoint(frame)
    return p[3], -p[4]

def rect(draw, x, y, w, h, fill, outline=None):
    draw.rectangle(tuple(int(v*SCALE) for v in (x,y,x+w,y+h)), fill=fill, outline=outline, width=1)

def text(draw, x, y, value, color='#e2e9e6'):
    draw.text((int(x*SCALE),int(y*SCALE)),str(value),font=font,fill=color)

for index, mode in enumerate(('赛季地下城', '高级条件展开', '普通组队')):
    test = RegressionTests(); test.setUp()
    test.run_lua('''
        local md={}
        for i=1,8 do
            local row=CreateFrame('Frame',nil,browse.BlzFilterPanel.Inset); row:SetHeight(20); row.dataValue=100+i
            row.Check=GUI:GetClass('CheckBox'):New(row); row.Check:SetText('赛季副本选项 '..i)
            table.insert(md,row)
        end
        local names={'缺坦克','缺治疗','缺DPS','已有坦克','已有治疗'}
        for i,row in ipairs(browse.MD) do row.Check:SetText(names[i]); table.insert(md,row) end
        browse.MD=md
        local names={'团长大秘境评分','装备等级','Boss击杀数量','活动创建时长','队伍人数'}
        for i,row in ipairs(browse.filters) do row.Check:SetText(names[i]) end
        local names={'坦克','治疗','输出','多选-“或”条件','显示屏蔽提示'}
        for i,row in ipairs({browse.ExFilterPanel.Inset:GetChildren()}) do row.Check:SetText(names[i]); row:SetPoint('TOPLEFT',10,10-20*i) end
        browsePass(); browse.AdvButton:Click()
    ''')
    if index == 1:
        test.run_lua('ns.D(browse).unifiedFilters.advancedToggle:Click()')
    if index == 2:
        test.run_lua("browse.ActivityDropdown:SetItem({value='custom-pve',categoryId=6})")
    u = test.lua.eval('ns.D(browse).unifiedFilters')
    w, h = u.host.GetWidth(u.host), u.host.GetHeight(u.host)
    image = Image.new('RGB',(int(w*SCALE),int(h*SCALE)),'#20282b')
    d = ImageDraw.Draw(image)
    rect(d,0,0,w-1,h-1,'#20282b','#547268')
    text(d,12,8,'筛选','#ffffff')
    rect(d,118,4,144,26,'#2a3e37','#577e6d')
    text(d,132,7,u.advancedToggle.GetText(u.advancedToggle))
    text(d,277,7,'×')
    sw, sh = u.scroll.GetWidth(u.scroll), u.scroll.GetHeight(u.scroll)
    sx, sy = point(u.scroll)
    scroll = u.scroll.GetVerticalScroll(u.scroll)
    body = Image.new('RGB',(int(sw*SCALE),int(sh*SCALE)),'#20282b')
    b = ImageDraw.Draw(body)
    for label in (u.activityTitle,u.advancedTitle):
        x,y=point(label); text(b,x,y-scroll,label.GetText(label),'#66dcae')
    if u.dungeonAll.IsShown(u.dungeonAll):
        x,y=point(u.dungeonLabel); text(b,x,y-scroll,u.dungeonLabel.GetText(u.dungeonLabel))
        for button in (u.dungeonAll,u.dungeonNone):
            x,y=point(button)
            rect(b,x,y-scroll,button.GetWidth(button),button.GetHeight(button),'#2b3e36','#526f60')
            text(b,x+20,y-scroll+2,button.GetText(button))
    for _,section in u.sections.items():
        if not section.inset.IsShown(section.inset): continue
        x,y=point(section.inset)
        rect(b,x,y-scroll,sw,section.height,'#182024')
        for _,row in test.lua.eval('function(f) return {f:GetChildren()} end')(section.inset).items():
            if not row.Check: continue
            rx,ry=point(row)
            rect(b,x+rx,y+ry-scroll+3,14,14,'#273933','#65927e')
            text(b,x+rx+24,y+ry-scroll,row.Check.GetText(row.Check))
            if row.MinBox:
                rect(b,x+rx+22,y+ry-scroll+27,60,20,'#101719','#50625a')
                rect(b,x+rx+104,y+ry-scroll+27,60,20,'#101719','#50625a')
                text(b,x+rx+87,y+ry-scroll+25,'–')
    if u.roll and u.roll.IsShown(u.roll):
        x,y=point(u.roll); rect(b,x,y-scroll,112,24,'#2b3e36','#526f60'); text(b,x+8,y-scroll+2,u.roll.GetText(u.roll))
    image.paste(body,(int(sx*SCALE),int(sy*SCALE)))
    rect(d,276,38,5,sh,'#111a1e')
    ratio=min(1,sh/u.content.GetHeight(u.content))
    rect(d,276,38+scroll/u.content.GetHeight(u.content)*sh,5,max(16,sh*ratio),'#53b38d')
    rect(d,12,h-38,112,26,'#2b3e36','#526f60'); text(d,27,h-35,'重置高级')
    rect(d,140,h-38,148,26,'#275c45','#65b78b'); text(d,174,h-35,'应用并刷新')
    x=(18+index*326)*SCALE
    text(pen,18+index*326,40,mode)
    canvas.paste(image,(x,65*SCALE))

path=ROOT/'unified-filter-preview.png'
canvas.save(path)
print(path)
