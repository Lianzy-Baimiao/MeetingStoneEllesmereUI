# 三个列表页面的统一美化（1.4.6）

## 范围与归属

`TablePanels.lua` 负责 ManagerPanel / CreatePanel / ApplicantPanel、RecentPanel、IgnoreListPanel 的布局。`Panels.lua` 的原入口接入它；原窗口、原按钮、原表格和原业务回调仍是唯一的数据/交互所有者。不是重做三套列表，不调用创建活动、邀请、删除等业务函数。

- 页面左右边距 14，常规控件高 26、相邻间距 10，列表与页脚分离。
- 管理活动：左栏 208，活动选择框内缩 8；右侧列表从 x=220 起，表头高 26；创建/解散按钮在右下方，中间 10。仅在原有创建视图中处理卡片，不移除已有活动详情中的角色/拾取信息图标。
- 最近玩友：移动原来的四个 FontString 标签（不是叠一份新标签）；下拉与搜索等高，批量删除右对齐。活动、职业、职责和搜索回调保持不变。
- 屏蔽列表：原表格保留，两个原匿名批量按钮按完整标签定位，只移动和绘制。EX 当前的「全选/取消全选」实际是逐项反选，本版保留这个原行为，没有擅自改动批量选择规则。

## 列表多选与启停开关

`Controls.lua` 对已标记列表中的小型标准复选框使用 16×16 直角方框和勾号；原按钮、命中区域、SetChecked、OnClick/OnChanged 不变。首列自定义 Frame 包裹 CheckButton 的 EX 样式也受支持。已经绘成 Switch 的控件会原位转换，复用图层/钩子。

不把整行 CheckButton、radio 或菜单标记改成复选框；列表不因为美化获得新的多选模式。设置/筛选中的功能开关继续使用直角 Switch。

## 表头和池化行

DataGridView 创建格子时读取 `header.width`，还会按 `width-1` 累加位置。只改表头外观会导致行错位。因此同步表头字段、现有格子和 UpdateItems 后的新增格子；保留列的排序、格式、图标、点击等回调。

申请操作列宽 136，原 OperationGrid 的邀请/拒绝/等待动画需横向 134；窄窗口优先缩文字列，不压缩这组操作。已在默认 922、加宽 1000、收窄 840 的离线几何中验证。极端小窗口和游戏字体截断仍需客户端判断。

## 输入框与生命周期

通过 `BrowseInputs.lua` 的 `SetControlChrome` 复用首页显式绘制/恢复原语，不复制另一套皮肤。持有者判断包含祖先关系；离开原卡片或页面隐藏就释放纹理 alpha、借用字体和临时高度。保留原输入文本、焦点、输入回调、父节点与原借入锚点。语音框借用时为 24 高，归还时恢复当次原值。

OnShow 立即处理并安排一次去重的下一帧校正，以覆盖后执行的原生外观恢复。页面 resize、字号、主题和主窗口缩放会刷新。每个对象只注册一次，未加入 OnUpdate、持续轮询或定时 GC。

## 离线验证与限制

```
python -m unittest discover -s MeetingStoneEllesmereUI/tests -q
python MeetingStoneEllesmereUI/tests/profile_table_retention.py
python MeetingStoneEllesmereUI/tests/profile_retention.py
python MeetingStoneEllesmereUI/tests/build_release.py
```

13 项专项、合计 110 项测试。`fixtures/IgnoreListPanel-20261002.lua` 是已安装 EX 的原 OnInitialize 摘录；测试在独立 Lua 环境执行该段，以验证真实的勾选、批量反选、移除以及名单索引维护回调没有被美化替换。管理活动/最近玩友使用实际字段和尺寸的最小控件夹具，邀请操作尺寸来自原 OperationGrid 构造器。

三页专项 600 轮操作：模拟对象 337、脚本 hooks 69、待执行计时器 0，预热后保持不变；回收后 Lua 内存约 1001 KiB。旧首页/设置探针也运行 600 轮，保持稳定。探针仅手动触发测试环境的 GC，不写入运行时插件。

**限制：不是游戏内测试。** 最终字体、贴图层级、活动实际状态、窗口缩放和插件共存必须在客户端验收；这组稳定性结果不能证明完整集合石或 EX 没有长期泄漏。未移除 EllesmereUI 前置，没有修改集合石/EX 本体或真实 SavedVariables。

安装新增运行时文件后，建议完整退出客户端再进，逐页检查多选框、表头和页脚；创建/邀请/移除等实际操作由用户选择是否执行。


## 1.4.7：蒙版遮挡与字体异常反馈闭环

用户日志来自 `游戏测试/插件异常.txt`（2026-10-02）。本次会话有两个不同入口的错误：

1. `TablePanels.lua:262: FontString:SetText(): Font not set`。标题没有模板，且在 Label/SetFont 之前 SetText。管理页的 Page 尺寸已更新，但后续蒙版定位被异常中断，蒙版仍从原生 x=180 起，左栏却已加宽到 208。
2. `FontString:SetFont(): Invalid font height (-1)`。Core 的字体遍历直接调用 EUI 的 Font 原语，后者保留 GetFont 返回的字号；尚未初始化的 FontString 返回的 -1 不会触发 `size or 12` 的回退。

历史记录中的聊天命令以 `en` 而非 `end` 结尾，是单独的命令截断，不修改插件来掩盖它。

### 重现与隔离

```
python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_manager_feedback.py -v
```

修复前最小重现的实际失败：

- `FontString:SetText(): Font not set`
- `FontString:SetFont(): Invalid font height (-1): height must be > 0`
- `auto invite is shifted away from sidebar left edge`

只先交换标题的初始化顺序，第一项及蒙版边界断言即通过；另外两项仍失败。再加入 Core 字体就绪检查，字体遍历一项通过；最后调整自动邀请位置，对齐断言通过。没有通过隐藏蒙版或绕过原生可用性逻辑来解决。

管理页移除重复标题，保留原自动邀请控件并将其 x 从 120 改成 14，和输入区域对齐。其他新增标题使用 GameFontNormal 模板兜底，并先设置主题字体再写文字。左栏宽度和右栏起点集中定义，申请列表与对应蒙版读取同一份值。

### 测试加强与边界

旧几何模拟把所有 FontString 都当作已有有效字体，且允许无字体 SetText，因此漏掉了客户端真实约束。这次新增 `strict_fonts_mock.lua` 明确执行上述限制；结合真实 Core.lua 的 Walk/FontAll/Font，以及已安装 EUI `WSkin.Font` 原文夹具验证，不只检查布局坐标。

`ManagerBlockers-20261002.lua` 保留本体两个蒙版显隐方法原文，在离线环境验证「请创建活动」仅覆盖右栏，而创建中的 FullBlocker 仍按原逻辑覆盖；反复隐藏/显示、字号变更、窗口宽度变化不改显隐条件或按钮回调。

额外验证字体就绪后可重新接管、无效/secret 字号不做算术、不累计字号增量，以及 OnShow 的异常只报告一次、不会逃出原生页签切换、依赖恢复后能够再次绘制。没有将测试错误注入运行时插件。

当前共 117 项测试通过。三页保留量探针升级为加载真实字体遍历、严格字体契约和 EUI 字体片段，600 轮后模拟对象 336、脚本 hooks 69、待执行计时器 0，回收后 Lua 约 1047 KiB，未持续增长。它仍不是游戏内内存或渲染测量。

本版没有新增运行时文件；已经加载 1.4.6 的客户端可 `/reload` 后复验管理页和屏蔽列表。不要把离线通过当作客户端字体、遮挡和其他插件共存已全部验收。


## 1.4.8：多行视口、菜单选择与最近玩友

### 反馈循环与根因

命令：`python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_page_feedback.py -q`

最初 5 个场景均明确失败（测试脚本自身的字符串转义修正后）：

- `multiline border was not applied to viewport`：原版 `SummaryBox` 指向 `LFGListFrame.EntryCreation.Description.EditBox`，外层 Description 才是多行 ScrollFrame。1.4.7 把单行边框绘制直接应用于滚动子控件，且没有压掉视口自己的底图。
- `submenu acquired a selected bar`：原版 DropMenuItem 是 CheckButton。原 `notClickable` 阻止了 `DropMenu:OnItemClick` 提交，但美化新增的通用 checked fill/bar 会随系统 CheckButton 点击状态亮起；并非原活动选择真的发生改变。
- `bulk all button inverted mixed selection`：EX 原版 callback 明确执行 `entry.selected = not entry.selected`。旧测试只验证全选后的清空和 callback 身份，没有混合状态用例，因而未发现文案与行为不一致。
- `default recent page did not include existing history`：RecentPanel 默认只设下拉 defaultValue=0，却不设 `self.code`。原 `Update` 在 code=nil 时直接返回。
- `recent menu has no seasonal dungeon option`：原 GetActivitesMenuTable 只给浏览/创建添加赛季入口，没有 OTHER 最近玩友入口。

逐项修复的测试结果为 5 红 → 多行/菜单转绿 → 批量选择转绿 → 最近玩友转绿。之后补齐 6 项生命周期/回调/记录身份/空列表/缺失赛季数据测试，共 11 项，完整回归 128 项。

### 边界与实现

- `SetControlChrome` 新增可选 `textOwner`：底图/边框属于视口，字体/禁用状态属于内部 EditBox；不重设输入框高度、内容、滚动、焦点、文本回调或原有锚点。原 `TitleWidget:SetObject` 管理视口位置，不替换暴雪多行输入逻辑。
- DropMenuItem 只增加悬停外观，不套列表整行选择；真正可勾选菜单项仍由原 CheckBox 纹理表示状态。非 checkable 项在原 `SetCheckState` 后消除没有语义的系统 checked 状态，不禁用父级鼠标/子菜单展开，不重写原 `OnClick`。
- 屏蔽列表只替换已确认的错误批量选择 callback，其他行内选择与移除 callback 保留。
- 最近玩友新增筛选仅接管 `RecentPanel.Update` 的两个视图值：0=全部，mplus=当前赛季地下城组。普通活动值仍调用原 Update；全部地下城使用原 `2-0-0-0` 分组查询。新增菜单是页面自己的浅层列表，不向集合石缓存的原菜单插入内容。
- 赛季组来自 `C_LFGList.GetAvailableActivityGroups(2, CurrentSeason | PvE)`，不维护一份过期的硬编码副本表；包含该赛季副本组下已经记录的各难度，不把历史大秘境误改成当前难度。数据暂不可用时不回退到全部/自定义活动冒充赛季结果。
- 聚合保留每个原 RecentPlayer 对象及其 Manager 引用，不拷贝记录或合并不同活动的同名玩家；备注、原表格过滤/排序、原确认删除语义保留。没有加入新的组队记录器，无法凭空补齐原插件从未记录的历史。
- 本次仅只读统计了近期保存文件的活动桶，确认包含地下城与其他类型；没有将真实姓名/记录复制到测试，也没有改写真实 SavedVariables。并不能据此保证每个具体副本/难度都有记录。

### 测试盲点修正

原简化模型把 Description 当普通 Frame，忽略了 ScrollChild、双锚点视口和不断增高的编辑框；现在 fixture 体现这层结构。原菜单未模拟 CheckButton 先翻转再执行原 DropMenuItem 回调的链路；新增原文方法与可复用行测试。最近玩友原测试仅验证布局和 callback 不变，本次执行原 Update/GetRecentList/Dropdown 值选择/BatchDelete 的摘录，并用合成记录验证新视图不改变记录身份或删除范围。

所有测试均离线，不替代客户端多行输入、子菜单展开、赛季 API 数据和最终视觉验收。


## 1.4.9：说明高度与原生分栏线

### 红测试与定位

命令：`python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_manager_spacing.py -q`。
首次运行 4 项失败，明确报告 `description card is still too short`、视口高度不足及 `old Blizzard divider art is still visible`；不是仅以无异常作为通过信号。随后增加借用/重复操作与无关子纹理保护用例，最终该文件 6 项通过，完整测试 134 项通过。

- 说明卡片原默认高度 65；原 `TitleWidget:SetObject(description,10,10,15,10)` 产生上边距 30、下边距 15，固定视口只剩 20。上一版本已修正绘制对象，但未扩充实际输入空间。
- 分栏线来自 `CreatePanel:OnInitialize` 内部局部变量 `GUI:GetClass('VerticalLine'):New(self)`，不是命名字段。原构造器以三段 `Interface\FriendsFrame\UI-ChannelFrame-VerticalBar` 拼接。已将原构造器原文提取为只读测试夹具，测试实际原生纹理结构。

### 调整边界

管理页起点 70→64；活动属性卡 90→84，下拉高度仍为 26；三处卡片间距统一为 4。标题卡保持 56、底部条件卡保持 106、页脚按钮位置不变，因此说明卡默认 65→83。主窗口整体大小没有被修改，也没有为了加高说明而裁切条件区。

视口上边距取 `max(24,labelFontSize+10)`、下边距为 6、左右各 8。默认字号下可视高度 53，18 号字时为 49；窗口每增高 80，说明视口也增高 80。内部 EditBox 的锚点、内容、输入回调与高度不修改。借用前保存视口锚点，页面隐藏时归还；SetParent 交还给新拥有者后不回写旧卡片锚点，避免覆盖原生界面新设置的位置。此项是对 1.4.8“不调整视口锚点”的有限扩展，仍不重写多行输入逻辑。

分隔线仅匹配 CreatePanel 直接子控件中的 12 宽、三段指定纹理，兼容 GetTexture 返回路径或文件 ID。只隐藏对应纹理，不泛化隐藏其他子控件；新线宽 1，位于左右列之间、上下与正文一致，一次创建后复用，不新增计时器或持续扫描任务。

### 验证

- 134 项测试、发布构建内 Lua 5.1 语法检查。
- 新增 200 轮原生重新借用、切页及窗口高度切换，控件数量不增长、无挂起计时器，GC 后保留内存稳定。
- 既有三页 600 轮：336 控件、69 脚本钩子、0 挂起计时器；最近玩友 450 条合成记录：4377 控件、0 计时器；首页/设置：493 控件、209 钩子、0 计时器。以上均为离线模拟，不能代替真实游戏性能测量。
- 人工复测：管理活动说明内输入多行并滚动，切换创建/已创建视图，检查中线与蒙版、下方条件、创建按钮无覆盖。


## 1.4.10：用户反馈竖线仍在

用户在客户端报告 1.4.9 的竖线仍在。本次没有新的客户端截图或控件尺寸转储，不能把离线复现的漏判条件宣称为已在用户客户端实测确认的唯一根因。

上一版有两类问题：它仅通过纹理和精确宽度识别控件，并且识别成功后还会绘制一条替代竖线。测试用 double 只提供精确的 12 和配套纹理解析返回，没有覆盖真实控件类型、浮点尺寸、未知数字纹理与原生重新 Show 的生命周期。

新增红测试命令：`python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_manager_spacing.py -q`。初跑 10 项中 4 项失败：宽度 12.000001 的旧线漏判、数字纹理且无路径解析时漏判、仍绘制替代线、原生重新 Show 能恢复竖线。原有正常说明高度/编辑状态等测试仍通过。

修复不再补更多纹理猜测分支，而是直接沿用集合石 LibClass 的 `IsType(VerticalLine)`：已将原生 GetType/GetSuper/IsType/IsClass 及皮肤 ns.GetClass 原文提取成只读夹具。仅在 CreatePanel 的直接子控件中查找 VerticalLine，隐藏该装饰 Frame；用一次 OnShow hook 防止原生重新显示，不覆盖原脚本。完全取消替代线，仅保留既有 12 单位列间留白。未改动 1.4.9 的说明高度和归还逻辑。

后续增加其他页面同类控件不受影响、类暂未初始化时布局正常且可重试两项回归；分隔线/说明文件共 12 项，完整测试共 140 项通过。200 轮切页/高度变化验证无新增对象或重复钩子。客户端验收点：/reload 后打开管理活动，左侧与右侧之间不应再有旧式线或替代细线；切页、创建/查看活动时不应恢复。


## 1.4.15 申请操作按钮与刷新（截图 5dff0550）

反馈：申请行的“邀请”和红叉仍使用原生立体素材；右上角“刷新”的文字溢出。

根因：OperationGrid 原先分派到只处理文字的 `SkinGridItem`。此单元格在本体构造函数中创建普通 Button 子控件，后续申请到达时不能依赖面板首次 descendant walk 接管。管理活动的 RefreshButton 原本有文字和左侧图标，却被布局压成了 28×28，并保留文字向右 8 的偏移。

修复：
- `Widgets.lua` 为 OperationGrid 增加 `SkinOperationGrid`，先保留表格字体处理，再直接为两个原按钮调用现有 EUI 扁平按钮原语。按钮对象、大小、位置、Handler 和 OnClick 不更换。
- 拒绝图标改用 `uitools-icon-close`（EUI 窗口关闭图标同款 atlas），12×12 居中并着红色，不依赖选中职业色开关。图标放在原按钮的鼠标穿透子层，避免随后通用按钮/引擎刷新时被与原生纹理一起清除。只新增一次启用/禁用显示 hook；等待期间 alpha=.4，原 spinner 和状态文本仍归本体控制。
- `TablePanels.lua` 中管理活动刷新布局先美化、隐藏旧 Icon、重置标签到按钮中心。宽 `max(76, ceil(文字实际宽度)+24)`，高 `max(28, labelFontSize+8)`，右侧与面板 EDGE 对齐。隐藏图标不改本体启禁用脚本，原脚本只改变 alpha，不会让旧图标重新显示。

验证命令：`python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_applicant_actions.py -q`。修复前稳定报 `invite retains raised template art`、`refresh label spills outside button` 等，修复后 6 项通过；完整 160 项通过。测试使用安装版本的 OperationGrid / RefreshButton 原文与 EUI ApplyButton / StateButtonLabel 原文作为离线 fixture，不访问游戏服务器。检查 200 轮复用与引擎重新应用不增加控件/监听、原点击/禁用/多人文案/状态消息不变。

游戏验收：/reload → 管理活动 → 等待新的单人/多人申请；确认两按钮外观、悬停和等待态，拒绝仍有红叉。将按钮字号在 8～20 间切换并重开页签，确认右上角刷新文本始终居中且不溢出。仅在确实需要邀请/拒绝时点击，避免测试误操作。
