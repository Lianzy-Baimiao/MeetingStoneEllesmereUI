"""Offline schematic from executed SummaryGrid geometry, NOT a game screenshot."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from test_summary_cancel import SummaryCancelTests

test = SummaryCancelTests()
test.setUp()
test.run_lua('ns.SkinObject(summary)')
lua = test.lua
cell = lua.globals().summary
button = lua.globals().cancel
art = lua.globals().ns.D(cell).cancelAction
scale = 3
image = Image.new('RGB', (940, 550), (17, 20, 24))
draw = ImageDraw.Draw(image)
font_path = 'C:/Windows/Fonts/msyh.ttc'
font = ImageFont.truetype(font_path, 36)
small = ImageFont.truetype(font_path, 23)
draw.text((25, 20), '取消申请按钮 · 1.4.17', font=font, fill=(235, 237, 240))
draw.text((25, 75), '离线布局示意，非游戏截图；X 图标为示意描绘', font=small, fill=(157, 163, 173))

def rect(frame, y):
    x = 270 + round((frame.GetLeft(frame) - cell.GetLeft(cell)) * scale)
    top = y + round((cell.GetTop(cell) - frame.GetTop(frame)) * scale)
    return x, top, x + round(frame.GetWidth(frame)*scale)-1, top + round(frame.GetHeight(frame)*scale)-1

for index, (label, script) in enumerate([
    ('正常', "cancel:RunScript('OnLeave')"),
    ('悬停', "cancel:RunScript('OnEnter')"),
    ('无取消权限', "empowered=false; summary:SetActivity(activity)"),
]):
    test.run_lua(script)
    y = 130 + index*125
    draw.text((25, y+28), label, font=small, fill=(203, 208, 216))
    draw.rectangle(rect(cell, y), fill=(28, 31, 36))
    draw.text((278, y+20), '队伍说明', font=font, fill=(204, 209, 217))
    pending = rect(cell.PendingLabel, y)
    timer = rect(cell.ExpirationTime, y)
    draw.text((pending[2]-108, y+20), '已申请', font=font, fill=(70, 208, 110))
    draw.text((timer[0], y+20), '2:05', font=font, fill=(70, 208, 110))
    bounds = rect(button, y)
    fill = (40, 40, 40) if index==1 else (15, 15, 15)
    draw.rectangle(bounds, fill=fill, outline=(55, 55, 55), width=scale)
    x0, y0, x1, y1 = bounds
    cx, cy = (x0+x1)/2, (y0+y1)/2
    radius = 4*scale
    alpha = art.host.GetAlpha(art.host)
    color = tuple(round(art.icon.vertexColor[i]*255*alpha + fill[i-1]*(1-alpha)) for i in (1,2,3))
    draw.line((cx-radius,cy-radius,cx+radius,cy+radius), fill=color, width=scale)
    draw.line((cx-radius,cy+radius,cx+radius,cy-radius), fill=color, width=scale)

path = Path(__file__).with_name('summary-cancel-preview.png')
image.save(path)
print(path)
