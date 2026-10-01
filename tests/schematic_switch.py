"""Draw actual Controls.lua rectangle geometry; still a schematic, not WoW."""
def draw_switch(draw, lua, control, panel, scale, offset_x=0, offset_y=0,
                background=(29, 41, 49)):
    state = lua.globals().ns.D(control).switch
    alpha = state.host.GetAlpha(state.host)
    for part in (state.edge[1], state.track[1], state.thumb[1]):
        x = part.GetLeft(part) - panel.GetLeft(panel) - offset_x
        y = panel.GetTop(panel) - part.GetTop(part) - offset_y
        w, h = part.GetWidth(part), part.GetHeight(part)
        color = tuple(round(part.color[i + 1] * 255 * alpha + background[i] * (1 - alpha))
                      for i in range(3))
        draw.rectangle((round(x * scale), round(y * scale),
                        round((x + w) * scale) - 1, round((y + h) * scale) - 1), fill=color)
