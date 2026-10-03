# MeetingStone classic / new UI compatibility

Date: 2026-10-04. Release version: 1.4.18.

## Corrected report and scope

The user confirms classic main-window skinning works. The failure is partial:
clicking the skin's unified filter button does not display classic Mythic+
conditions after the original entry has been hidden. The previous assessment's
claim of “no visible effect” was incorrect and has been removed.

The user has now confirmed both meeting-stone_-happy_20260821 (new UI) and
meeting-stone_-happy_20260820_classic (classic UI) work in game with this patch.
The tested 1.4.18-local.1 runtime is promoted unchanged to 1.4.18, apart from
version metadata. Support is limited to these MeetingStone_Happy UI editions
under EllesmereUI and its skin component, not other MeetingStone forks.
“Classic UI” is a MeetingStone edition, not WoW Classic.

## Reproduction and root cause

Command (run before the runtime patch):

```powershell
python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_classic_filters.py -v
```

Failure: `classic dungeon filters missing from unified window`.
The test opens the actual skin host around the unchanged classic panel constructor
and native CheckBox callbacks, using mocked WoW frame APIs.

- UnifiedFilters adopted only BlzFilterPanel / ExFilterPanel / AdvFilterPanel.
- Classic creates ExSearchPanel; its dungeon rows use dungeonName, and its MD list
  also contains 13 class rows and the mutually exclusive need/avoid pair.
- The skin hid ExSearchButton regardless of whether it had adopted the content.
- Classic's native CreateExSearchButton also overwrites AdvButton.OnClick during
  late EX_INIT, after the unified host may already have been built.
- Classic uses ordinary category 2 selections rather than the new UI's synthetic
  mplus value. Its original conditions entry is accessible across categories.

## Patch

- Detect/adopt ExSearchPanel by capability, not by date/version strings. Reuse the
  original MD row order and callbacks, lay out all 23 controls in scroll content.
- Reparent the anonymous native reset button and label it 重置大秘境与职业. Keep it
  separate from 重置高级; no reimplementation of MDSearchs or database writes.
- Keep classic's shared conditions accessible across categories and its original
  footer filters intact. No new-UI role proxies, bulk actions or Blizzard
  advanced-filter writes are imposed on classic.
- Restore the unified toggle after late EX_INIT. Leave a native entry accessible
  if the upstream activity panel cannot be adopted.
- Preserve native search/cooldown behavior; no third-party source file edits.

## Validation

10 classic regressions cover the reported missing content, native dungeon/class/
need-avoid callbacks, separate resets, real late EX_INIT/button constructor,
category transitions, scrolling, footer controls, apply, repeated setup and an
unknown-panel fallback. Fixtures are pinned unchanged constructor/method excerpts
from the supplied classic package, with only environment bindings added.

```powershell
python -m unittest discover -s MeetingStoneEllesmereUI/tests -q
```

188 tests passed, including all 178 pre-existing new-UI regressions. The TOC Lua
chunks also compile under Lua 5.1. These mocks do not prove real client rendering,
protected-frame behavior or live search-result correctness.

## In-game regression checklist

The user confirmed both editions usable on 2026-10-04. The detailed checklist
below remains for future regression testing; this is not an exhaustive matrix
of resolutions, clients and other addon combinations.

1. With the classic package, EllesmereUI and skin dependencies enabled, /reload.
2. Open 查找活动 → 筛选: confirm dungeon names, class choices and 需要/避开 appear;
   scroll down to all controls, then expand advanced ranges.
3. Select dungeon/class filters and verify real results. Test 需要/避开 and the
   original footer role filters, then 应用并刷新.
4. 重置大秘境与职业 must leave advanced values unchanged; 重置高级 must not clear
   the classic dungeon/class selections. The two resets intentionally differ.
5. Switch activity category, close/reopen the window and reload. No double popup,
   missing entry, overlap or Lua error. Reload persistence stays native to classic.
6. Under new UI, recheck seasonal bulk selection, minimum rating, role shortcuts
   and roll-pool entry.

## Structural reference

The two supplied packages each have 389 files with identical path sets; 10 files
differ: API.lua, Data.lua, AceGUIWidget-CheckBox.lua, LfgService.lua,
MeetingStone.toc, MenuTableAPI.lua, BrowsePanel.lua, NDui_Plus.lua, FilterBox.lua
and MeetingStoneEX.lua. MainPanel and NetEaseGUI are shared. Reference packages,
WTF/SavedVariables and public release archives were not modified.

## Test-build deployment history

Backed up source/installed skin and the external description to
`_backups/MeetingStoneEllesmereUI-classic-filter-20261004-045410`.
Deployed only UnifiedFilters.lua, Panels.lua, the TOC and CHANGELOG.md to
`E:\World of Warcraft\_retail_\Interface\AddOns\MeetingStoneEllesmereUI`;
SHA-256 comparisons matched the source. Existing other runtime files already
matched. GitHub, public release ZIPs and installed MeetingStone/EX were untouched.

## Release preparation

1.4.18 promotes the user-verified runtime without additional behavioral changes.
The support scope and English/Chinese upload description now explicitly name
both MeetingStone_Happy UI editions. Reference packages and unrelated addons
remain untouched. The earlier “not published / pending confirmation” limitation
applied to the local test build, not this release.
