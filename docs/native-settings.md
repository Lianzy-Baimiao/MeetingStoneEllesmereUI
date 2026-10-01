# 原生设置页适配（1.3.0）

## 边界

`NativeSettings.lua` 只负责集合石 `SettingPanel` 的展示。它读取
`AceConfigRegistry:GetOptionsTable("MeetingStone", "dialog", UI_NAME)`，不重建
SavedVariables，也不修改注册表、原模块或共享 AceGUI/AceConfig 库。

选项执行统一通过原 `get` / `set` / `func` / `confirm`，遵守 `hidden` / `disabled`。
仅 nil 表示继承根定义，false 不被继承值覆盖。打开、切换、重排时用 loading 防止控件
回填触发保存；缩放数值输入在完成后提交，Esc 恢复。真正的缩放计时器仍属原模块。

只将原 `BlizOptionsGroup` 容器停放在隐藏父框体下，保留其生命周期，不重新初始化模块。
找不到注册表或原容器时保持原界面。新控件保存在 `ns.D(panel).nativeSettings`，重复接入
只同步数据。`Panels.lua` 的原生设置 pass 负责接入，并在页面再次显示时重试。

## 控件所有权

- 五类设置行：本插件创建，标签缩写，悬停可见原名称及描述。
- 快捷键：单独创建 AceGUI Keybinding，复用原捕获和冲突确认。切页/隐藏停止全局捕获提示。
- 关键词：只在原模块已创建相应注册表和控件时，迁入整个 SpamWordWidget；列表、事件、
  添加/重置/导入/导出和原输入对话框不重建。仅重排原动作按钮，避免锚定到可视区外。
- 原版设置：不带容器调用 AceConfigDialog:Open，独立弹窗访问原定义，包括未来的新选项。
  本页只对明确识别的选项类型建立控件，不冒险转换未来未知类型。

## 验证与限制

测试使用真实安装版本的 OptionPanel 源码快照及模拟 Profile/AceGUI，另有坐标布局示意。
发布 ZIP 只包含 TOC、运行时 Lua 和 CHANGELOG，测试夹具及示意图均不打包。
未模拟客户端全部继承显隐事件、真实皮肤绘制、战斗保护和其他插件覆盖；以游戏实测为准。

## 1.3.1 接入失败修复

AceConfigRegistry 的 `uiName` 必须带版本号，如 `MeetingStoneEllesmereUI-1.0`。
这是配置 UI 适配器标识，不是发布包版本；两张配置表的读取和回调 info 使用同一常量。
1.3.0 的裸插件名导致注册表抛错，外层保护阻止后续替换，用户因此仍看见旧设置页。
此前仅测试真实 OptionPanel、未测试真实注册表校验；现在同时执行两者，覆盖关键词开启/
关闭路径，并在轻量模拟注册表中约束同一契约。未修改上游库或跳过校验。
