"""Coordinate-based beauty settings schematic; NOT a screenshot from WoW."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from test_regressions import RegressionTests
from schematic_switch import draw_switch
ROOT=Path(__file__).resolve().parent
S=2
fonts={n:ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',n*S) for n in (10,12,14)}
W,H=892,321
canvas=Image.new('RGB',(1840*S,1144*S),'#0c1318')
d=ImageDraw.Draw(canvas)
def box(p,x,y,w,h,fill,outline=None):
    p.rectangle(tuple(round(v*S) for v in (x,y,x+w,y+h)),fill=fill,outline=outline,width=S)
def txt(p,x,y,value,width=999,size=12,color='#dce5e9'):
    value=str(value)
    while value and p.textlength(value,font=fonts[size])>width*S: value=value[:-1]
    p.text((round(x*S),round(y*S)),value,font=fonts[size],fill=color)
def rect(f,panel):
    return f.GetLeft(f)-panel.GetLeft(panel),panel.GetTop(panel)-f.GetTop(f),f.GetWidth(f),f.GetHeight(f)
txt(d,20,12,'界面美化 · Lua 实际坐标示意（非游戏截图）',1750,14)
for index in range(6):
    cat=index//2+1; bottom=index%2==1
    t=RegressionTests(); t.setUp(); t.run_lua('ns.SetupOptions(main); u=ns.D(main.options).skinOptions')
    t.run_lua(f'u.categories[{cat}].button:Click()')
    if bottom: t.run_lua("u.scroll:RunScript('OnMouseWheel',-99)")
    u=t.lua.globals().u; panel=t.lua.globals().main.options
    img=Image.new('RGB',(W*S,H*S),'#182127'); p=ImageDraw.Draw(img)
    box(p,*rect(u.nav,panel),'#111a20','#344049')
    for f,size,color in ((u.navTitle,12,'#92d4bd'),(u.title,14,'#eef5f6'),(u.subtitle,10,'#93a5ae'),(u.hint,10,'#83949e')):
        x,y,w,h=rect(f,panel); txt(p,x,y,f.GetText(f),w,size,color)
    for _,c in u.categories.items():
        x,y,w,h=rect(c.button,panel); active=c.mark.IsShown(c.mark)
        box(p,x,y,w,h,'#244338' if active else '#1a252d','#426a59' if active else '#34414b')
        if active: box(p,x,y+3,3,h-6,'#0cd29f')
        txt(p,x+18,y+7,c.button.GetText(c.button),w-24)
    for f in (u.reset,u.reload):
        x,y,w,h=rect(f,panel); box(p,x,y,w,h,'#25313a','#45545d'); txt(p,x+38,y+4,f.GetText(f),w-44)
    sx,sy,sw,sh=rect(u.scroll,panel); scroll=u.scroll.GetVerticalScroll(u.scroll)
    body=Image.new('RGB',(int(sw*S),int(sh*S)),'#182127'); b=ImageDraw.Draw(body)
    for _,r in u.rows.items():
        if not r.frame.IsShown(r.frame): continue
        x,y,w,h=rect(r.frame,panel); x-=sx; y-=sy+scroll
        box(b,x,y,w,h,'#1d2931','#303f49')
        for f,size,color in ((r.label,12,'#dce5e9'),(r.hint,10,'#7e929d')):
            tx,ty,tw,th=rect(f,panel); txt(b,tx-sx,ty-sy-scroll,f.GetText(f),tw,size,color)
        c=r.control; cx,cy,cw,ch=rect(c,panel); cx-=sx; cy-=sy+scroll
        if r.cfg.kind=='check': draw_switch(b,t.lua,c,panel,S,sx,sy+scroll)
        elif r.cfg.kind=='color': box(b,cx,cy,cw,ch,'#1c2023','#53656c')
        else:
            box(b,cx,cy,cw,ch,'#111b21','#425b60'); txt(b,cx+8,cy+3,int(c.GetNumber(c)),cw-22)
            txt(b,cx+cw-12,cy+2,'↕',12,10,'#7e9b9f')
    img.paste(body,(round(sx*S),round(sy*S)))
    box(p,sx+sw+10,sy,5,sh,'#0f181e')
    total=max(sh,u.content.GetHeight(u.content)); thumb=max(16,sh*sh/total)
    box(p,sx+sw+10,sy+scroll/total*sh,5,thumb,'#699f8d')
    ox=20+(index%2)*912; oy=65+(index//2)*360
    txt(d,ox,oy-23,u.title.GetText(u.title)+(' · 底部' if bottom else ' · 顶部'),850,12,'#a3b8bb')
    canvas.paste(img,(ox*S,oy*S))
path=ROOT/'options-layout-preview.png'; canvas.resize((1840,1144)).save(path)
print(path.name)
