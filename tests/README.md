# Regression tests

```powershell
python -m unittest discover -s MeetingStoneEllesmereUI/tests -v
python MeetingStoneEllesmereUI/tests/build_release.py
```

Requires Python and `lupa.lua51`. The suite executes the real Config.lua, Controls.lua, BrowseInputs.lua,
UnifiedFilters.lua, SettingsLayout.lua, NativeSettings.lua, Panels.lua and Options.lua against `wow_mock.lua`, a small
WoW / NetEaseGUI contract double. No network, installed addons or real
SavedVariables are modified. This is not a game client rendering/search test.

The 1.2.5 single-host, save-before-search and consolidated visibility assertions
were run red before implementation. Old two-button/exclusive-popup assertions
were intentionally replaced: activity and advanced controls may now coexist
inside the SAME window. Role/cooldown/settings regressions remain covered.
The mock preserves parent/child visibility, original callback ordering, native
checkbox clicks, SetItem/SetValue selections and refresh cooldown scheduling.
It does not implement all WoW inherited visibility events or protected UI rules.

Optional layout schematics (Pillow, Windows Microsoft YaHei):

```powershell
python MeetingStoneEllesmereUI/tests/render_options_preview.py
python MeetingStoneEllesmereUI/tests/render_unified_preview.py
python MeetingStoneEllesmereUI/tests/render_native_settings_preview.py
```

These read coordinates from executed Lua and draw **schematics, not game
screenshots**. Example dungeon labels are placeholders.

## Bulk dungeon selection (1.2.6)

Six additional tests cover native saves and idempotence, unchanged role/rating/
advanced conditions, category visibility and button spacing, late EX init and
repeated setup, absent dungeon IDs, and hidden/disabled source controls.

In game, open 赛季地下城 → 筛选. Check 全选 and 全不选 above the dungeon names,
then manually pick a subset and click 应用并刷新. Confirm labels/checkboxes and
results agree; roles, minimum rating and advanced ranges must remain unchanged.
Repeating 全选/全不选 must be harmless. Switch to 自定义PVE: both buttons disappear.
“全不选” clears dungeon-name selections; it is not a command to hide every team.

## In-game acceptance checklist (1.2.5, still applicable)

1. `/reload` with MeetingStone, MeetingStoneEX and skin dependencies enabled.
   Open 查找活动; confirm only 刷新 / 筛选 remain, with a gap and no Lua errors.
2. Open 筛选 in 赛季地下城: dungeon/role/minimum-rating controls are accessible by
   scrolling. 查看R币池 still works. Top 展开高级条件 stays available at all scroll
   positions; clicking it shows the five original ranges without a second popup.
3. Verify 关闭 / 筛选 toggle the SAME window. Closing keeps saved conditions and
   all applicable bottom shortcuts. Clicking shortcuts still saves and searches.
4. With advanced expanded, switch to 自定义PVE / raids / PvP and back. Activity
   contents follow the type; no old popup appears; the unified window retains its
   open/closed state. Mythic+ bottom shortcuts hide only for unsupported types.
5. Use distinct advanced values in two categories, switch between them, and check
   saved values return. Reopening should not clear edits. Disabling bottom
   shortcuts must not affect unified-window behavior.
6. Set a dungeon minimum rating, then 应用并刷新; confirm real search filtering.
   Toggle several shortcuts during cooldown; the latest change should search
   once when the cooldown ends. Apply must not bypass the cooldown.
7. 重置高级 clears only the five range conditions, not dungeon/role selections.
8. Close the main window during a pending shortcut search; no hidden-window
   search. Returning to browse applies the pending latest state.
9. Test noAutoFilterPopup both ways after reload: unified window remains manual,
   and availability/category updates must not hide an already-open section.
10. 界面美化 now uses three navigation categories, seven scrollable rows each,
    retaining all 21 settings. Check numbers/percentages/colors/switches and the
    confirmation before 恢复默认.
11. At the user's UI scale and resolution, inspect text widths, scrolling,
    backdrop/borders, bottom actions and clamping near the screen edge.

Archives whitelist only the TOC runtime list plus CHANGELOG.md. Tests, docs,
previews, backups and addon_version.txt are excluded. The latter is an existing
local updater marker, not the TOC version.

## Native settings (1.3.0)

15 tests execute the unchanged installed MeetingStone `Module/OptionPanel.lua`
(snapshot: `fixtures/OptionPanel-20261001.lua`) against a Profile/AceGUI double.
They cover all 19 original option definitions, custom vs inherited setters,
reload and destructive-action confirmations, addon/option dependencies, scale
percentage conversion/clamping/step/partial typing/Esc, keybinding conflict
accept/cancel and capture cleanup, original keyword widgets/actions, absent
keyword support, missing-registry retry through the real panel skin pass,
idempotence, registry non-mutation, resizing, spacing and the original dialog.

Manual acceptance:

1. `/reload`, open the original **设置** tab (not 界面美化). Confirm the five
   categories, aligned controls, scroll area and fixed original-settings button.
2. Toggle 小地图按钮 and 显示悬浮窗; verify real effects and dependent controls.
   Turn on 职业图标 and check its child options and original reload prompt.
3. Enter 150% scale, press Enter/click away; test arrows/wheel and returning to
   100%. While typing 180%, Esc should restore the prior value without saving.
4. Under 快捷键与维护, capture an occupied key: cancel must retain the old bind,
   confirm must replace it. Switch category/close the window while capturing;
   the global prompt/keyboard capture must stop. Restore your preferred key.
5. Test 清理历史 cancellation first. Accept only if willing to erase history.
6. 当前安装版本禁用了关键词模块，应显示说明。有模块的版本必须保留词库列表及添加、
   重置、导入、导出；检查列表能滚动，所有按钮可达，重置仍需确认。
7. Open 原版设置, make a change, close and reopen the redesigned tab; values must
   resynchronize. Confirm no old embedded AceConfig group overlaps the new page.
8. Recheck unified filters and dungeon 全选/全不选 using the earlier checklist.

The screenshot-like preview is only a Pillow schematic; the mock does not
reproduce actual font metrics, skin rendering, secure UI restrictions, or all
inherited WoW frame events. Final rendering and in-game effects need manual QA.

## Native settings takeover regression (1.3.1)

The original double accepted any `GetOptionsTable` caller identity and missed
AceConfigRegistry's mandatory version suffix. Two tests now execute the unchanged
installed registry snapshot (`fixtures/AceConfigRegistry-3.0-20261001.lua`) and
the real SettingPanel skin pass, with keyword support both off and on. The pass
must create a visible replacement and hide the old UI without initial writes.
The double also enforces the caller contract; option callback info uses the same
versioned identity. No runtime debug logging was added.

Red/green command:

```powershell
python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_native_settings.py -k real_registry -v
```

Before the fix: `settings still old: ... 'uiName' - badly formatted or missing
version number`. After the fix: both takeover paths pass. In-game acceptance:
`/reload`, open 集合石 → 设置, verify five categories replace the old embedded
settings, and check no AceConfigRegistry error appears.

## Controls and beauty tab (1.4.0)

13 new tests cover the real switch renderer, original click/save/rejected-save
logic, programmatic resets, disabled states, repeated skinning, live accent,
compact/wide geometry, safe raw-checkbox classification, real Widgets dispatch,
quick-filter synchronization, borrowed search scripts/parents/focus/hidden icons,
and both ordering paths using verbatim installed EUI EditBox/Dropdown primitives.
The skin settings tests cover no writes on open/navigation, all 21 settings,
number drafts/cancel/commit, scroll/resize, reset confirmation and color cancel.
Existing dungeon bulk tests now check switch thumb positions after all/none.
The two missing-control behaviors were reproduced before their implementation.

Manual acceptance after `/reload`:

1. 查找活动左上活动类型下拉与右侧搜索框都应有统一底色/细边框。测试分类多级菜单、
   输入中文关键词、Enter、自动完成及清除，再切换暴雪组队查找器和集合石。
2. 设置、界面美化、筛选（含展开的高级条件）、创建活动以及首页职责快捷项，
   检查识别到的普通复选框为开关。点击开关及原有文字区域，确认状态/实际效果一致。
3. 开关勾选亮色在右、未勾选暗色在左、禁用变暗。测试全选/全不选、重置高级、
   分类切换与重开页面；不应出现旧方框叠在开关上或文字被遮挡。
4. 界面美化三个分类可滚动；恢复默认先取消再确认；数字输入 Enter/失焦保存，
   Esc 撤回草稿，颜色选择器取消能恢复原值。
5. 改变 EUI 强调色时开关跟随。不同界面缩放下检查轨道、拇指、字体及点击范围。
6. 本次没有去掉 EUI 依赖；无 EUI 支持的分析见 docs/standalone-support.md。

## User feedback fixes (1.4.1)

10 tests in `test_user_feedback.py` cover square switch rectangles, physical-pixel
edges across compact/wide sizes and UI scales, anchor-only layout changes,
the real native TabPanel registration (including the keyword variant's inset
heights), shared page/row/control/footer coordinates, and role conflict rollback.
The role tests execute the unchanged upstream `saveAdvFilter` and `roleFunc`
functions from `fixtures/EXRoleSave-20261001.lua`; they verify both roles, both
selection orders, native and shortcut clicks, no invalid saves/search, disabled
shortcuts, late EX initialization, idempotence and valid unrelated roles.
`fixtures/TabPanel-20261001.lua` is the installed upstream registration code.
Fixtures and test-only rendering helpers are excluded from the release ZIP.

Initial reproduction: five assertions failed against 1.4.0: new conflicting
native choice remained checked, shortcut remained checked, switch art still used
stepped caps, absolute tab coordinates differed (native padding 3 vs default10),
and keyword-enabled tabs used different inset heights. These now pass:

```powershell
python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_user_feedback.py -v
```

The old dungeon preservation test selected needsTank+hasTank together; it now
uses the valid independent needsTank+hasHealer pair. Its preservation purpose
is unchanged, without requiring the just-fixed invalid role combination.
Previews now draw the actual Lua switch rectangles rather than an idealized
rounded shape. They remain schematics, not client screenshots.

Manual acceptance after `/reload`:

1. Check Settings, beauty, filters and shortcuts: straight track/thumb corners,
   thin clean edges, correct on/off/disabled states and unchanged text hit area.
   Check normal and non-default game UI / 集合石窗口 scales.
2. Alternate 设置 and 界面美化: navigation/title/first row/footer should retain
   their positions. Check after resizing and in keyword-enabled builds too.
3. Select 已有坦克 then 缺坦克. The latter must immediately return to off; after
   acknowledging the warning, only 已有坦克 remains. Test reverse order, the
   healer pair and both native/shortcut controls. Rejected clicks do not search.
4. Uncheck the original choice, then select its opposite: valid changes must
   still save/search normally. Verify other roles, all/none and advanced ranges.
5. EUI remains required by this release; do not interpret OptionalDeps as
   standalone support. See docs/standalone-support.md for the audited scope.

## Homepage takeover and retention probe (1.4.2)

6 new tests in `test_browse_chrome.py` cover stock art reapplication, no-op facade
or prior done flags, reversible ownership, bounded controls/hooks/timers, actual
upstream BrowsePanel OnShow/OnHide, and late OnShow writes / stale deferred work.
The old tests requiring a permanent shared EUI backdrop now assert the reversible
local layer's coexistence with the actual EUI primitives in both loading orders.
This is an intentional ownership contract change, not removing the compatibility
assertions. Input scripts, text, focus, icons and native anchors remain tested.

Red: `test_repaint_after_stock_textures_are_reapplied` failed with
`search stock art survived reopening`; the explicit-paint and restoration tests
also failed before implementing BrowseInputs.lua. Green: all 81 tests pass.
The user's exact live trigger is not captured; these are reproducible coverage
gaps, not proof of which third-party callback ran in their client.

```powershell
python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_browse_chrome.py -v
python MeetingStoneEllesmereUI/tests/profile_retention.py
```

The second command runs 600 operation cycles and compares object/hook/timer counts
plus post-GC Lua heap after warmup. It does not run a real search or full EUI;
see docs/memory-investigation.md for scope and in-game measurements.

Manual: fully restart the client once after this TOC/file-list update. Check the
home dropdown's flat background/border/arrow and the search box's dark rectangle,
then text search, menus, clear button, autocomplete and repeated opens. Open the
Blizzard group finder afterwards to confirm our layer is gone there. If it still
looks stock, capture a screenshot, installed version and enabled skin addons.


## Applicant actions and manager refresh (1.4.15)

`test_applicant_actions.py` uses native OperationGrid / RefreshButton and EUI
button function fixtures to cover late-created actions, original invite/decline
callbacks, pending/disabled/status rendering, fixed red reject glyph, pooling and
engine reapplication, and refresh-label padding/centering at 8–20 font sizes.
The six tests ran red before the fix. Full suite: 160 tests. No live invitations,
rejections, applicant refresh API calls or SavedVariables writes are performed.
