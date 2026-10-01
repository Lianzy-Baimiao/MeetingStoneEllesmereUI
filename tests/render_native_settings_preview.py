"""Coordinate-based native settings schematic; NOT a screenshot from WoW."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from test_native_settings import NativeSettingsTests
from schematic_switch import draw_switch

ROOT=Path(__file__).resolve().parent
S=2
FONT='C:/Windows/Fonts/msyh.ttc'
fonts={size:ImageFont.truetype(FONT,size*S) for size in (10,12,14)}
W,H=892,321
canvas=Image.new('RGB',(1840*S,1138*S),'#0c1318')
d=ImageDraw.Draw(canvas)
d.text((20*S,10*S),'原生「设置」改版 · Lua 实际坐标示意（非游戏截图）',font=fonts[14],fill='#eaf1f2')

def box(draw,x,y,w,h,fill,outline=None):
    draw.rectangle(tuple(round(v*S) for v in (x,y,x+w,y+h)),fill=fill,outline=outline,width=S)

def txt(draw,x,y,value,width=999,size=12,color='#dce5e9'):
    value=str(value)
    for j,line in enumerate(value.split('\n')):
        while line and draw.textlength(line,font=fonts[size])>width*S: line=line[:-1]
        draw.text((round(x*S),round((y+j*(size+5))*S)),line,font=fonts[size],fill=color)

def rect(f,panel):
    return (f.GetLeft(f)-panel.GetLeft(panel),panel.GetTop(panel)-f.GetTop(f),f.GetWidth(f),f.GetHeight(f))

for index in range(6):
    test=NativeSettingsTests(); test.setUp()
    test.run_lua('globalOptions.showclassico=true; loadedAddons={ElvUI_WindTools=true,NDui_Plus=true}; RaiderIO={}')
    test.init(index==5)
    cat=index+1 if index<5 else 4
    test.run_lua(f'u=ns.D(SettingPanel).nativeSettings; u.categories[{cat}].button:Click()')
    u=test.lua.globals().u; panel=test.lua.globals().SettingPanel
    if index==5:
        test.run_lua('u.scroll:SetVerticalScroll(math.max(0,u.content:GetHeight()-u.scroll:GetHeight()))')
    img=Image.new('RGB',(W*S,H*S),'#182127'); pen=ImageDraw.Draw(img)
    box(pen,*rect(u.nav,panel),'#111a20','#344049')
    for f,size,color in ((u.navTitle,12,'#92d4bd'),(u.title,14,'#eef5f6'),(u.subtitle,10,'#93a5ae'),(u.footer,10,'#83949e')):
        x,y,w,h=rect(f,panel); txt(pen,x,y,f.GetText(f),w,size,color)
    for _,c in u.categories.items():
        x,y,w,h=rect(c.button,panel)
        active=c.mark.IsShown(c.mark)
        box(pen,x,y,w,h,'#244338' if active else '#1a252d','#426a59' if active else '#34414b')
        if active: box(pen,x,y+3,3,h-6,'#50d1a7')
        txt(pen,x+18,y+7,c.button.GetText(c.button),w-24)
    x,y,w,h=rect(u.originalButton,panel); box(pen,x,y,w,h,'#25313a','#45545d'); txt(pen,x+38,y+4,'原版设置',w-44)
    sx,sy,sw,sh=rect(u.scroll,panel); scroll=u.scroll.GetVerticalScroll(u.scroll)
    body=Image.new('RGB',(int(sw*S),int(sh*S)),'#182127'); b=ImageDraw.Draw(body)
    for _,row in u.rows.items():
        if not row.frame.IsShown(row.frame): continue
        x,y,w,h=rect(row.frame,panel); x-=sx; y-=sy+scroll
        box(b,x,y,w,h,'#1d2931','#303f49')
        disabled=not row.control.IsEnabled(row.control)
        for f,size,color in ((row.label,12,'#69767e' if disabled else '#dce5e9'),(row.hint,10,'#7e929d')):
            tx,ty,tw,th=rect(f,panel); txt(b,tx-sx,ty-sy-scroll,f.GetText(f),tw,size,color)
        control=row.widget.frame if row.widget else row.control
        cx,cy,cw,ch=rect(control,panel); cx-=sx; cy-=sy+scroll
        kind=row.option.type
        if kind=='toggle':
            draw_switch(b,test.lua,row.control,panel,S,sx,sy+scroll)
        else:
            box(b,cx,cy,cw,ch,'#111b21','#425b60')
            value=row.control.GetNumber(row.control) if kind=='range' else row.control.GetText(row.control)
            txt(b,cx+7,cy+3,value,cw-18)
            if kind=='range': txt(b,cx+cw-12,cy+2,'↕',12,10,'#7e9b9f')
            if row.unit: txt(b,cx+cw+6,cy+2,'%',18,12)
    for f in (u.compatNote,u.keywordNote):
        if f.IsShown(f):
            x,y,w,h=rect(f,panel); txt(b,x-sx,y-sy-scroll,f.GetText(f),w,10,'#8faaa7')
    if u.keyword and u.keyword.IsShown(u.keyword):
        x,y,w,h=rect(u.keyword,panel); x-=sx; y-=sy+scroll
        box(b,x,y,w,h,'#1d2931','#344650'); txt(b,x+12,y+10,'关键词过滤',200)
        box(b,x+8,y+38,w-16,h-78,'#121d23','#344650')
        txt(b,x+18,y+52,'保留原版词库、列表事件与编辑逻辑',w-36,10,'#8faaa7')
        for _,button in enumerate(list(u.keyword.GetChildren(u.keyword))):
            if button.GetObjectType(button)!='Button': continue
            bx,by,bw,bh=rect(button,panel); bx-=sx; by-=sy+scroll
            box(b,bx,by,bw,bh,'#253a39','#48685e'); txt(b,bx+19,by+4,button.GetText(button),bw-24)
    img.paste(body,(round(sx*S),round(sy*S)))
    box(pen,sx+sw+10,sy,5,sh,'#0f181e')
    total=max(sh,u.content.GetHeight(u.content)); thumb=max(16,sh*sh/total)
    box(pen,sx+sw+10,sy+scroll/total*sh,5,thumb,'#699f8d')
    ox=20+(index%2)*912; oy=60+(index//2)*360
    txt(d,ox,oy-21,'关键词模块启用时（滚动至词库）' if index==5 else u.title.GetText(u.title),850,12,'#a3b8bb')
    canvas.paste(img,(ox*S,oy*S))
path=ROOT/'native-settings-preview.png'
canvas.save(path)
print(path)
