# MeetingStoneEllesmereUI

让**集合石**（MeetingStone / MeetingStone_Happy 开心快乐版）使用 [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui) 风格的皮肤插件。

- **Interface**：120000 / 120001 / 120005 / 120007 / 120100
- **作者**：白描
- **版本**：1.2.2

## 特性

- **纯皮肤，不改行为**：只做贴图去色（alpha-only）与重绘，不 `Hide()`、不 `SetParent()`、不动 `EnableMouse`，不改集合石的任何逻辑。集合石更新后照常可用。
- **零加载顺序依赖**：除 `RegisterSkin` 注册本身外，其余全部在 EllesmereUI 于 `PLAYER_LOGIN` 触发的皮肤回调里惰性解析。集合石缺失或被禁用时代价仅一次表查询。
- **状态外置**：每个对象的皮肤状态存在弱引用外部表里，不往集合石的 frame 上写字段，避免与集合石自身更新冲突。
- **幂等**：所有皮肤函数可重复调用，刷新钩子可自由重入。
- **错误隔离**：同一条报错只上报一次，单个字段名写错不会每帧刷屏，也不会中断其余皮肤流程。
- **内置设置页**：以「界面美化」标签页形式注册进集合石自己的窗口（与 MeetingStoneEX 的「屏蔽玩家列表」同一入口），用 NetEaseGUI 控件绘制，因此设置页本身也被同一套皮肤渲染。
- **改完即生效**：设置项按 key 映射到对应的重绘函数，绝大多数改动无需 `/reload`（关闭 `skinRows` 需要重载，因为原版行贴图已被去色）。

## 依赖

必需：

- [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui)（提供 `EllesmereUI.RegisterSkin`）
- 集合石（MeetingStone / MeetingStone_Happy）

可选（`OptionalDeps`）：`EllesmereUI`、`EllesmereUIBlizzardSkin`、`MeetingStone`、`MeetingStoneEX`

## 安装

将 `MeetingStoneEllesmereUI` 目录放入：

```
World of Warcraft/_retail_/Interface/AddOns/
```

登录后在集合石窗口的「界面美化」标签页里调整。

## 可调项

| 分类 | 设置项 | 默认 |
|---|---|---|
| 背景 | `bgColor` 底色 | `0.06, 0.06, 0.06` |
| 背景 | `bgAlpha` 全局不透明度（表头跟随） | `0.92` |
| 背景 | `topBar` 标题行后 25px 暗带 / `topBarShade` 对比度 | 开 / `0.10` |
| 字体 | `listFontSize` / `tabFontSize` / `labelFontSize` | `12` |
| 字体 | `fontDelta` 相对增减（保留集合石自身字号层级） | `0` |
| 列表行 | `zebra` 斑马纹 + `zebraAlpha` | 开 / `0.12` |
| 列表行 | `hoverAlpha` 悬停 / `selectAlpha` 选中 | `0.04` / `0.08` |
| 列表行 | `selectBar` 选中竖条 + `barWidth` | 开 / `2` |
| 列表行 | `skinRows` 行贴图皮肤（关闭需重载） | 开 |
| 表头 | `headerShade` 表头明暗 | `0.14` |
| 标签页 | `tabColor` / `tabAlpha` | `0.06,0.06,0.06` / `1` |
| 其他 | `roleFilterBar` 角色筛选条 | 开 |
| 其他 | `memberIconScale` 成员图标缩放 | 关 |
| 其他 | `noAutoFilterPopup` 禁用筛选弹窗自动展开 | 关 |

百分比类数值内部按 0–1 存储，设置页按 0–100 编辑。

## 文件结构

| 文件 | 职责 |
|---|---|
| `Core.lua` | 启动、`RegisterSkin` 注册、错误隔离、共用工具 |
| `Config.lua` | 默认值、SavedVariables、「哪个 key 变化时重绘什么」映射 |
| `Widgets.lua` | 各类控件的 `Apply*` 绘制实现 |
| `Panels.lua` | 集合石各面板/窗口的皮肤分发 |
| `Options.lua` | 「界面美化」设置页 |

SavedVariables：`MeetingStoneEllesmereUIDB`

## License

MIT
