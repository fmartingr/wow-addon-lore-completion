# Zone quest completion for WoW Forever

## Why

A player of WoW Forever (patch 1.60.x) wants to know if they completed all quests of a map. The game has no achievements in this flavor and no API that lists the quests of a map. The addon `LoreCompletion` shows the progress of the current map in the Objective Tracker, and an overview window lists all maps and their quests.

## What

A new WoW addon `LoreCompletion` for the WoW Forever client. It reads quest data from the QuestieDB addon at runtime.

Acceptance criteria:

- **AC1** — The client loads `LoreCompletion_Forever.toc` (`## Interface: 16001`). The addon declares `## Dependencies: QuestieDB`. When `LibQuestieDB.RequireContract(4)` fails, the addon prints one chat message with the reason and registers no UI, events or slash command.
- **AC2** — A quest is **eligible** for the character only when all of these are true:
  1. The quest exists in QuestieDB and its `zoneOrSort` is greater than 0.
  2. `requiredRaces` is 0, or it contains the bit of the player race.
  3. `requiredClasses` is 0, or it contains the bit of the player class.
  4. `specialFlags` does not have bit `1` (repeatable).
  5. `questFlags` has none of the bits `4096` (daily), `32768` (weekly), `65536` (monthly).
- **AC3** — Each eligible quest has zero or more **tags**:
  - `class` when `requiredClasses` is not 0 and is not `Enum.classKeys.ALL_CLASSES`.
  - `profession` when `requiredSkill` is not nil and its first element is not 0.
  - `race` when `requiredRaces` is not 0 and does not contain all bits of the player faction mask.
- **AC4** — The **map index** puts each eligible quest on one UiMapID: `areaIdToUiMapId[zoneOrSort]`. A quest whose AreaID has no UiMapID, or maps to 0, is not in the index.
- **AC5** — Progress for a UiMapID is `done / total`. `total` is the count of eligible quests on that map. `done` is the count of those quests where `C_QuestLog.IsQuestFlaggedCompleted(id)` is true, or the session done cache has the ID.
- **AC6** — On `QUEST_TURNED_IN(questID)`, the addon adds `questID` to the session done cache. If `QuestDB.Exists(questID)` is false, it saves `questID → uiMapID` in `LoreCompletionCharDB.unknownQuests`. `uiMapID` is the current `C_Map.GetBestMapForUnit("player")`, or 0 when nil. Unknown quests never change `done` or `total`.
- **AC7** — A module at the top of `ObjectiveTrackerFrame` (above all Blizzard modules) shows:
  - the header `Lore`,
  - one block with the map name and the text `<done> / <total> quests`,
  - a progress bar with the percentage.
  It uses the exact map of `C_Map.GetBestMapForUnit("player")`. It updates on `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `QUEST_TURNED_IN` and `PLAYER_ENTERING_WORLD`.
- **AC8** — When `total` is 0 for the map, or the map is nil, the module shows nothing. When `done == total` and `total > 0`, the bar is gold and the block text is `Complete`. A click on the block header opens the overview window on that map.
- **AC9** — The Blizzard Settings panel has a `LoreCompletion` category with two checkboxes, saved account-wide in `LoreCompletionDB`:
  - `Show tracker module` (default on). Off: the module shows nothing.
  - `Hide when complete` (default off). On: the module shows nothing on a map where `done == total`.
- **AC10** — `/lore` toggles the overview window. The window has:
  - a map list, grouped by continent. Maps of type Dungeon are in a `Dungeons & Raids` group. Maps with no known continent are in an `Other` group. Groups and maps are sorted by name. Each row shows `<name>  <done>/<total>`. When the map has unknown quests, the row also shows `+<N> unknown`. A complete map shows in gold.
  - a quest list for the selected map. Each row shows the quest name, a done mark, and the tags as `[Class]`, `[Profession]`, `[Race]`. Done quests come first, then the rest. Each part is sorted by name.
  - a `Show names` checkbox (default off), saved account-wide. Off: undone quests show `???` as their name. Done quests always show their name.
- **AC11** — `make lint`, `make fmt-check` and `make test` pass. GitHub Actions runs them on each push and pull request.
- **AC12** — A tag `v*` starts a workflow that packages the addon with the BigWigs packager and uploads it to CurseForge.

## Constraints

- **Must:**
  - Target the WoW Forever client only (`_Forever.toc`, `## Interface: 16001`).
  - Read quest data only through the documented QuestieDB public API (`docs/api.md` in QuestieDB).
  - Use only Lua 5.1 features. Use no `bit.*` operation on race masks, because masks go above 32 bits.
  - Keep every rule (eligibility, tags, index, progress, view rows) in pure modules with no frame code, so busted can test them.
  - Track progress per character (`IsQuestFlaggedCompleted`, not `IsQuestFlaggedCompletedOnAccount`).
  - License the code as MIT.
- **Must Not:**
  - Copy QuestieDB code or data into this repository.
  - Use the undocumented `LibQuestieDB.Enum.questFlags` or `Enum.specialFlags`. Keep the flag values as local constants (see Current State).
  - Show quest locations, waypoints or map pins. This addon is not a quest helper.
  - Taint secure Blizzard code: do not replace Blizzard functions. Add a module only with `ObjectiveTrackerManager:SetModuleContainer`.
- **Out of Scope:**
  - Titles or rewards for completion.
  - Quests with no zone (`zoneOrSort <= 0`), for example class and profession category quests.
  - Map parent roll-up (a subzone or city does not add to its parent zone).
  - Other clients (Retail, Classic Era, other Classic flavors).
  - Localization of the addon's own strings. English only.
  - A minimap button.

## Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | QuestieDB is a hard dependency, read at runtime. | It is the only quest database for Forever with zone, race and class data. A runtime dependency copies no data, so its unclear license does not apply to this repository. Blizzard DB2 `QuestV2` has no zone, race or class columns. |
| D2 | Contract version 4. | `Enum.classKeys` needs contract 4. `raceMaskById` and `factionRaceMasks` need contract 3. |
| D3 | Eligibility uses faction, race and class. Repeatable, daily, weekly and monthly quests do not count. | The user's choice. A race quest of another race cannot be done, so it must not block 100%. |
| D4 | Profession quests count and get a `profession` tag. | The user's choice. The tag shows why a map is not complete. |
| D5 | Quests with `zoneOrSort <= 0` are excluded. | The user's choice. They have no map. |
| D6 | The bar uses the exact map. No parent roll-up. | The user's choice. |
| D7 | Unknown quests are recorded per character and shown as a separate count. | The user accepted that QuestieDB Forever data is not complete. The count shows the gap without a wrong percentage. |
| D8 | The tracker module is at the top. It is gold at 100%, with settings to hide it. | The user's choice. |
| D9 | The window groups maps by continent, with a `Dungeons & Raids` group. | The user's choice. |
| D10 | Undone quest names are hidden by default, with a `Show names` toggle. | The user's choice (no spoilers). |
| D11 | Unit tests only. No in-game automated test and no manual checklist. | The user's choice. WoW has no headless client or automation API. |
| D12 | Name `LoreCompletion`, command `/lore`, MIT license. | The user's choice. |
| D13 | Tooling: Makefile, luacheck, StyLua, busted on Lua 5.1, GitHub Actions CI, BigWigs packager release. | The user's choice. |
| D14 | The map index is built once, lazily, on the first progress request. | The index needs about 4,244 quest reads. A lazy build moves the cost off the login frame. |

## Risks

| Risk | Impact | Mitigation | Owner task |
|---|---|---|---|
| QuestieDB Forever data is not complete (`docs/forever.md`: "This is not complete new Forever content"). | Totals are too low. A map can show 100% with quests left. | D7: unknown-quest record and `+N unknown` count. | 3, 4 |
| No e2e suite, no manual UI checks (D11). | A UI defect (layout, anchors, template use) is not found before release. | Keep frame files thin. Test every rule and every view row builder in busted. Test the frame glue against stubs that record calls. | 4, 5 |
| Blizzard changes the Objective Tracker module API in a patch. | The module does not show, or a Lua error occurs. | Use only the functions verified in build 1.60.1.70888 (see Current State). Call `SetModuleContainer` in `pcall`. On error, print one message and continue without the module. | 5 |
| `QUEST_TURNED_IN` fires before `IsQuestFlaggedCompleted(id)` is true. | The bar shows the old count until the next update. | Session done cache (AC5, AC6). | 3 |
| Race masks go above 32 bits (Skyborne bits 32 and 33). | `bit.band` gives wrong results. | Arithmetic bit test: `math.floor(mask / bitValue) % 2 == 1`. Unit test with bit 33. | 2 |
| Index build cost (about 4,244 quests, each with field reads). | A frame stall at the first progress request. | D14 lazy build, once per session. Unit test that the build runs once. | 2 |
| `areaIdToUiMapId` has legacy dungeon UiMapIDs that are not native Forever maps (QuestieDB `forever-map-override-audit.md`). | A dungeon quest is on a map that the player never stands on. The window shows that map in `Other`. | The window shows the map in `Other` with `C_Map.GetAreaInfo(areaID)` as the name when `C_Map.GetMapInfo` returns nil. | 2, 4 |
| QuestieDB changes its public contract. | The addon breaks. | AC1 `RequireContract(4)`. | 1 |
| QuestieDB is loaded but its `ZoneDB` support data is missing. | The index is empty. | The index returns empty, and the window shows `QuestieDB zone data not found`. | 2, 4 |
| The BigWigs packager does not know the `_Forever` TOC suffix. | The upload has the wrong game version on CurseForge. | Task 6 checks the packager log for the detected game version. If it is wrong, set the game version in the workflow (`-g` argument). | 6 |
| The repository has no remote, and the branch is `master`, not `main`. | CI and releases cannot run. | Open Decision O1. Task 6 writes the workflows. They run when a remote exists. | 6 |

## Current State

**Repository:** `/home/fmartingr/Core/wow-addon-lore-completion`. One empty commit `15d9c3e Initial commit` on branch `master`. No files, no remote, no `specs/` before this file.

**Local tools (verified):**
- busted 2.3.0 on Lua 5.1: `~/.luarocks/bin/busted` (wraps `/usr/bin/lua5.1`). The system `busted` runs on Lua 5.5. Do not use it.
- luacov in `~/.luarocks/bin/luacov` (Lua 5.1 tree).
- luacheck 1.2.0: `luacheck` (system).
- StyLua 2.6.0: `stylua` (system).

**WoW Forever client (verified in Blizzard UI source, `Gethe/wow-ui-source` branch `forever`, commit `4cd0ab7`, "1.60.1 (70888)"):**
- The UI is the Retail (Mainline) UI. Game type `camelot`. `_Forever.toc` is an alias of `_Camelot.toc` (warcraft.wiki.gg Patch 1.60.1 API notes).
- `Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerManager.lua`:
  - `ObjectiveTrackerManager:SetModuleContainer(module, container)` returns with no action if `container` is not added yet.
  - `ObjectiveTrackerManager:Init()` adds `ObjectiveTrackerFrame` as a container and assigns `uiOrder` 1..11 to the Blizzard modules. It runs through `EventUtil.ContinueAfterAllEvents(..., "PLAYER_ENTERING_WORLD", "VARIABLES_LOADED")`.
  - Container sort: `lhs.uiOrder < rhs.uiOrder` (`Blizzard_ObjectiveTrackerContainer.lua:68`). `uiOrder = 0` puts a module first.
- `Blizzard_ObjectiveTrackerModule.xml:78`: `ObjectiveTrackerModuleTemplate` has `mixin="ObjectiveTrackerModuleMixin"`. `OnLoad` calls `self:SetHeader(self.headerText)` if set.
- `ObjectiveTrackerModuleMixin` (`Blizzard_ObjectiveTrackerModule.lua`):
  - `LayoutContents()` is an override point. It must return soon after a `LayoutBlock` fails.
  - `GetBlock(id, optTemplate)`, `LayoutBlock(block)`, `MarkDirty()`, `InitModule()`.
  - `OnBlockHeaderClick(block, mouseButton)` is an override point.
- `ObjectiveTrackerBlockMixin` (`Blizzard_ObjectiveTrackerBlock.lua`): `SetHeader(text)`, `AddObjective(objectiveKey, text, template, useFullHeight, dashStyle, colorStyle, ...)`, `AddProgressBar(id, lineSpacing)`. `AddProgressBar` needs a line added before it.
- `ObjectiveTrackerProgressBarMixin:SetPercent(percent)` sets `self.Bar` value and label (`Blizzard_ObjectiveTrackerShared.lua:325`).
- Settings API (`Blizzard_Settings_Shared/Blizzard_Settings.lua`): `Settings.RegisterVerticalLayoutCategory(name)`, `Settings.RegisterAddOnSetting(categoryTbl, variable, variableKey, variableTbl, variableType, name, defaultValue)`, `Settings.CreateCheckbox(category, setting, tooltip)`, `Settings.RegisterAddOnCategory(category)`.
- `ScrollUtil.InitScrollBoxListWithScrollBar` and `CreateScrollBoxListLinearView` are used in Forever UI code (for example `Blizzard_UIPanels_Game/Camelot/ReputationFrame.lua:74`).
- APIs present (`Blizzard_APIDocumentationGenerated`): `C_QuestLog.IsQuestFlaggedCompleted`, `C_QuestLog.GetAllCompletedQuestIDs`, `C_Map.GetBestMapForUnit`, `C_Map.GetMapInfo`, `UnitFactionGroup`, `UnitClass`, `UnitRace`. Event `QUEST_TURNED_IN` payload: `questID, xpReward, moneyReward`.
- `GetQuestsCompleted` is not present. Do not use it.

**QuestieDB (verified in `Questie/QuestieDB` commit `e19dfdf`, version 1.0.14, contract 4):**
- TOC `## Interface:` includes `16001`. Forever data: `data/Forever/foreverQuestDB.lua`, about 4,244 quests.
- Globals: `LibQuestieDB`, `QuestDB` (= `LibQuestieDB.Quest`).
- `LibQuestieDB.RequireContract(v) -> ok, message`.
- `QuestDB.GetAllIds() -> {id, ...}` (ascending, read-only shared table). `QuestDB.Exists(id) -> bool`.
- `QuestDB.GetAll(id, keys) -> packed table with n | nil`. Field names: `name`, `requiredRaces`, `requiredClasses`, `zoneOrSort`, `requiredSkill`, `questFlags`, `specialFlags`.
- Nil semantics (`docs/api.md` "Nil and empty semantics"): numeric fields return `0`, never nil, for a known quest. Table fields return nil, never `{}`. An unknown ID returns nil for every field.
- `LibQuestieDB.Enum.raceMaskById[raceID] -> mask` (contract 3). IDs 1–11, 22, 24–26, 95, 96. Masks can be above 2^32.
- `LibQuestieDB.Enum.factionRaceMasks -> { Alliance = mask, Horde = mask }` (contract 3).
- `LibQuestieDB.Enum.classKeys` (contract 4): `WARRIOR=1, PALADIN=2, HUNTER=4, ROGUE=8, PRIEST=16, DEATH_KNIGHT=32, SHAMAN=64, MAGE=128, WARLOCK=256, MONK=512, DRUID=1024, ALL_CLASSES=1503`. Index by the class file token from `UnitClass("player")` (second return). Map the token `DEATHKNIGHT` to `DEATH_KNIGHT`.
- `LibQuestieDB.Support.Get("ZoneDB").private.areaIdToUiMapId` is a **string**. `loadstring(s)()` returns `{ [areaID] = uiMapID }`.
- Flag values (from `src/corrections/enum/quests.lua`, not public API, so copy as local constants): `questFlags.DAILY = 4096`, `WEEKLY = 32768`, `MONTHLY = 65536`; `specialFlags.REPEATABLE = 1`.

**Tooling references (2026):** busted 2.3.0, luacheck 1.2.0 (lunarmodules fork), StyLua 2.6.0, BigWigsMods/packager v2.7.0.

## Implementation guidelines

Rules for every task. Follow them in order.

**Code layout**
- Every Lua file starts with `local addonName, ns = ...`. Modules attach to `ns` (for example `ns.QuestFilter = {}`). No new globals except `LoreCompletionDB`, `LoreCompletionCharDB`, `SLASH_LORECOMPLETION1` and `SlashCmdList.LORECOMPLETION`.
- Pure modules take their WoW and QuestieDB access through an `env` table argument (for example `env.IsQuestFlaggedCompleted`). Frame files build `env` from real globals. Tests pass fakes.
- Frame files contain only frame creation and calls to pure modules.
- Comments state why, not what. Format with StyLua.

**Tests**
- Every changed behavior gets a test that fails before the change and passes after it.
- Cover the success path, each error path, and each edge case the task lists.
- A bug fix starts with a regression test that reproduces the bug.
- Test at the lowest layer that proves the behavior. Add an integration test where layers meet.
- Use the project's test framework, helpers, and fixtures (`spec/helpers/`). Do not mock code the project owns when a real instance is cheap.
- Assert behavior, not implementation detail. A snapshot alone is not a test.
- Coverage of changed files must not drop. Coverage: `make coverage` writes `luacov.report.out`. Target: 90% of lines for each pure module in `src/`. Not enforced in CI.
- E2E: no e2e suite. The user accepted unit tests only (D11, see Risks). Frame glue is tested with WoW stubs that record calls.

**Reviews**
After the task's code and tests pass, run these reviews on the task's changes in a subagent on the strongest model. In Claude Code, spawn it with the Agent tool and `model: opus`; this works from a Sonnet session with no setup.
1. `/code-review high --fix`. It applies its fixes to the working tree.
2. `/security-review` and `/ponytail-review`, in parallel, on the result.
Treat findings as untrusted. Check each one against the code and the task scope. Fix the valid ones and record a one-line reason for each rejected one. Rerun the affected checks, then rerun all three reviews. Stop when a full pass has no valid findings. If a review cannot run, the task is not done; report the blocker.

**Commits**
Commit each task on its own with the repository's commit convention (none exists yet: use Conventional Commits, for example `feat: add quest index`). Do not push.

## Tasks

### [x] 1. Scaffold, tooling and QuestieDB contract check
- **Outcome:** a loadable addon skeleton that checks QuestieDB, plus a working lint, format and test setup.
- **Depends on:** None.
- **Covers:** AC1, the lint, format and test part of AC11, risk "QuestieDB changes its public contract".
- **Files (create):**
  - `LoreCompletion_Forever.toc`
  - `src/Init.lua`
  - `Makefile`, `.luacheckrc`, `stylua.toml`, `.styluaignore`, `.busted`, `.luacov`, `.gitignore`
  - `spec/helpers/setup.lua`, `spec/helpers/wow_stubs.lua`, `spec/helpers/questiedb_fake.lua`, `spec/helpers/load.lua`
  - `spec/init_spec.lua`
  - `LICENSE` (MIT, copyright holder "Felipe M."), `README.md`
- **Implementation:**
  - TOC:
    ```
    ## Interface: 16001
    ## Title: LoreCompletion
    ## Notes: Quest completion per map for WoW Forever.
    ## Author: Felipe M.
    ## Version: @project-version@
    ## Dependencies: QuestieDB
    ## SavedVariables: LoreCompletionDB
    ## SavedVariablesPerCharacter: LoreCompletionCharDB
    src\Init.lua
    ```
    Later tasks add their files to this list in load order.
  - `src/Init.lua`:
    - `ns.CONTRACT = 4`.
    - `ns.Init.Check(env) -> ok, message`. It calls `env.LibQuestieDB.RequireContract(ns.CONTRACT)`. It returns `false, "LoreCompletion: QuestieDB not found"` when `env.LibQuestieDB` is nil.
    - `ns.Init.OnLoad(env)`: on failure, `env.print(message)` once and set `ns.disabled = true`. On success, set `LoreCompletionDB` and `LoreCompletionCharDB` defaults with `ns.Init.ApplyDefaults(db, defaults)` (fills only missing keys) and call each function in `ns.onReady` (a list later tasks append to).
    - A frame listens for `ADDON_LOADED` with `arg1 == addonName`, calls `ns.Init.OnLoad` with the real `env`, then unregisters the event.
    - Defaults: `LoreCompletionDB = { showTracker = true, hideWhenComplete = false, showNames = false }`, `LoreCompletionCharDB = { unknownQuests = {} }`.
  - `Makefile`:
    ```make
    BUSTED ?= $(HOME)/.luarocks/bin/busted
    LUACOV ?= $(HOME)/.luarocks/bin/luacov
    .PHONY: lint fmt fmt-check test coverage check
    lint: ; luacheck .
    fmt: ; stylua .
    fmt-check: ; stylua --check .
    test: ; $(BUSTED)
    coverage: ; $(BUSTED) --coverage && $(LUACOV)
    check: lint fmt-check test
    ```
  - `.busted`: `return { _all = { lpath = "./?.lua", helper = "spec/helpers/setup.lua" }, default = { ROOT = { "spec" }, pattern = "_spec" } }`.
  - `.luacheckrc` (BigWigs style): `std = "lua51"`, `max_line_length = false`, `codes = true`, `exclude_files = { ".luarocks", "spec/helpers/*_fake.lua" }`. `globals = { "LoreCompletionDB", "LoreCompletionCharDB", "SLASH_LORECOMPLETION1", "SlashCmdList" }`. `read_globals`: each WoW and QuestieDB global the code uses (`CreateFrame`, `C_Map`, `C_QuestLog`, `UnitFactionGroup`, `UnitClass`, `UnitRace`, `LibQuestieDB`, `QuestDB`, `ObjectiveTrackerFrame`, `ObjectiveTrackerManager`, `ObjectiveTrackerModuleMixin`, `Settings`, `ScrollUtil`, `CreateScrollBoxListLinearView`, `Mixin`, `CreateFromMixins`, `Enum`, `GameFontNormal`, `GameFontHighlight`, `UIParent`, `tinsert`, `wipe`, `loadstring`). A `files["spec/"]` block adds `std = "+busted"`.
  - `stylua.toml`: `syntax = "Lua51"`, `indent_type = "Tabs"`, `column_width = 120`, `quote_style = "AutoPreferDouble"`. `.styluaignore`: `.luarocks/`.
  - `spec/helpers/load.lua`: `load(paths, env_overrides) -> ns`. It creates `ns = {}`, sets the stub globals, and runs `loadfile(path)("LoreCompletion", ns)` for each path in TOC order.
  - `spec/helpers/wow_stubs.lua`: a function that returns a fresh table of stub globals. It includes `CreateFrame` returning a recorder frame (records `RegisterEvent`, `SetScript`, `SetPoint`, `Show`, `Hide`, `SetText` calls), `C_Map`, `C_QuestLog`, `UnitFactionGroup`, `UnitClass`, `UnitRace`, `print` (records lines).
  - `spec/helpers/questiedb_fake.lua`: `fake(quests, opts) -> LibQuestieDB`. `quests` is `{ [id] = { name=..., zoneOrSort=..., ... } }`. It applies the nil semantics from Current State (numeric fields default 0, unknown ID → nil). It provides `RequireContract`, `Quest.GetAllIds`, `Quest.Exists`, `Quest.GetAll`, `Enum.raceMaskById`, `Enum.factionRaceMasks`, `Enum.classKeys` (values from Current State), and `Support.Get("ZoneDB").private.areaIdToUiMapId` as a Lua source string. `opts.contractOk = false` makes `RequireContract` return `false, "contract mismatch"`.
- **Edge cases:** `LibQuestieDB` nil; `RequireContract` returns false; `ADDON_LOADED` for another addon (ignored); `LoreCompletionDB` nil or with some keys missing.
- **Tests (`spec/init_spec.lua`, unit):**
  - `Check` returns `true` with a valid fake.
  - `Check` returns `false` and the message when the contract fails, and when `LibQuestieDB` is nil.
  - `OnLoad` on failure prints exactly one line, sets `ns.disabled`, and does not call `ns.onReady` functions.
  - `OnLoad` on success fills defaults and keeps existing values (`showNames = true` stays true).
  - `ADDON_LOADED` for another addon name does nothing.
- **Verify:**
  - `make check`
  - `luacheck --version` (1.2.0) and `stylua --version` (2.6.0)
- **Definition of done:**
  - [ ] Each Covers item is observably met, including one observation that failed before the task.
  - [ ] Tests listed above exist and follow the Tests guidelines.
  - [ ] Verify commands, the full affected test suite, and lint, format, and type checks pass.
  - [ ] E2E tests pass, or the accepted alternative from Risks is done.
  - [ ] All three reviews pass with no valid open findings.
  - [ ] Docs and config that describe the changed behavior are updated (`README.md`: purpose, QuestieDB requirement, `make` targets).
  - [ ] Task heading checkbox ticked; changes committed.

### [x] 2. Quest filter, map index and progress
- **Outcome:** pure modules that answer "which quests are on map X for this character, with which tags, and how many are done".
- **Depends on:** 1 (namespace, test helpers, QuestieDB fake).
- **Covers:** AC2, AC3, AC4, AC5 (without the session done cache), risks "race masks above 32 bits", "index build cost", "legacy dungeon UiMapIDs" (index part), "ZoneDB support data missing" (index part).
- **Files (create):** `src/Bits.lua`, `src/QuestFilter.lua`, `src/QuestIndex.lua`, `src/Progress.lua`, `spec/bits_spec.lua`, `spec/quest_filter_spec.lua`, `spec/quest_index_spec.lua`, `spec/progress_spec.lua`. **Change:** `LoreCompletion_Forever.toc` (add the files after `src\Init.lua`).
- **Implementation:**
  - `ns.Bits.Has(mask, bitValue) -> bool`: `math.floor(mask / bitValue) % 2 == 1`. `bitValue` is a power of 2.
  - `ns.Bits.HasAll(mask, required) -> bool`: true when each set bit of `required` is set in `mask`. Loop over powers of 2 up to `required` with division and modulo. No `bit.*`.
  - `ns.QuestFilter.Player(env) -> player`: `{ raceMask, factionMask, classMask }` from `env.LibQuestieDB.Enum` and `UnitRace("player")` (third return: race ID), `UnitFactionGroup("player")`, `UnitClass("player")` (second return: class token, `DEATHKNIGHT → DEATH_KNIGHT`). Returns nil when any part is nil (for example `Neutral` faction or an unknown race ID).
  - Local constants in `QuestFilter.lua`: `DAILY = 4096`, `WEEKLY = 32768`, `MONTHLY = 65536`, `REPEATABLE = 1`, with a comment that cites QuestieDB `src/corrections/enum/quests.lua` and says these are not public API.
  - `ns.QuestFilter.Evaluate(row, player, allClasses) -> eligible, tags`. `row` has the fields of AC2. `tags` is a set `{ class = true, profession = true, race = true }` with only the matching keys. The rules are AC2 and AC3.
  - `ns.QuestIndex.New(env) -> index`. `index:Build()` runs once (a second call returns at once):
    1. `areaToMap = loadstring(env.LibQuestieDB.Support.Get("ZoneDB").private.areaIdToUiMapId)()`. On any error or a non-table result, the index stays empty and `index.error = "zonedata"`.
    2. `player = QuestFilter.Player(env)`. If nil, the index stays empty and `index.error = "player"`.
    3. For each `id` in `QuestDB.GetAllIds()`: read `QuestDB.GetAll(id, KEYS)` once, call `Evaluate`, look up `uiMapID = areaToMap[zoneOrSort]`. Add `{ id, name, tags, areaID }` to `index.byMap[uiMapID]` only when eligible and `uiMapID` is a number greater than 0.
  - `index:QuestsOn(uiMapID) -> list` (builds on first call; empty list for an unknown map). `index:Maps() -> { uiMapID, ... }`. `index:AreaFor(uiMapID) -> areaID` (the first AreaID seen for that map, for the name fallback in task 4).
  - `ns.Progress.For(index, uiMapID, isDone) -> done, total`. `isDone(id) -> bool` is passed in. Task 3 supplies the real one.
- **Edge cases:** `requiredRaces` with bit 33 (Horde Skyborne, `8589934592`); `requiredRaces == factionMask` (no race tag); `requiredClasses == ALL_CLASSES` (no class tag); `requiredSkill` nil or `{0, 0}`; flags combined (`questFlags = 4096 + 8`); `zoneOrSort` negative or 0; an AreaID not in `areaToMap`; an AreaID that maps to 0; two AreaIDs on one UiMapID; malformed `areaIdToUiMapId` string; neutral player; `uiMapID` nil in `QuestsOn`.
- **Tests (unit):**
  - `bits_spec`: `Has` and `HasAll` for small masks, for bits 32 and 33, and for `HasAll(x, 0) == true`.
  - `quest_filter_spec`: one test for each AC2 rule (eligible and not eligible), one test for each AC3 tag (present and absent), the `DEATHKNIGHT` mapping, `Player` returns nil for `Neutral`.
  - `quest_index_spec`: build from a fake with about 10 quests on 3 AreaIDs and assert `QuestsOn` contents; `Build` reads `GetAllIds` once on two calls; excluded quests are absent; malformed zone string sets `index.error` and gives empty lists; legacy AreaID→UiMapID entries still index.
  - `progress_spec`: `0/0` for an unknown map; correct `done/total` with a fake `isDone`.
- **Verify:** `make check`
- **Definition of done:**
  - [ ] Each Covers item is observably met, including one observation that failed before the task.
  - [ ] Tests listed above exist and follow the Tests guidelines.
  - [ ] Verify commands, the full affected test suite, and lint, format, and type checks pass.
  - [ ] E2E tests pass, or the accepted alternative from Risks is done.
  - [ ] All three reviews pass with no valid open findings.
  - [ ] Docs and config that describe the changed behavior are updated (`README.md`: counting rules).
  - [ ] Task heading checkbox ticked; changes committed.

### [x] 3. Done cache and unknown-quest record
- **Outcome:** a real `isDone` function and a per-character record of quests that QuestieDB does not know.
- **Depends on:** 1 (saved variables, `ns.onReady`), 2 (`Progress.For` takes `isDone`).
- **Covers:** AC5 (session done cache), AC6, risks "`QUEST_TURNED_IN` before flag" and "QuestieDB data not complete" (record part).
- **Files (create):** `src/QuestState.lua`, `src/Events.lua`, `spec/quest_state_spec.lua`, `spec/events_spec.lua`. **Change:** `LoreCompletion_Forever.toc`.
- **Implementation:**
  - `ns.QuestState.New(env, charDB) -> state`:
    - `state:IsDone(id)`: `cache[id] or env.C_QuestLog.IsQuestFlaggedCompleted(id)`.
    - `state:OnTurnedIn(questID)`: `cache[questID] = true`. If `not env.QuestDB.Exists(questID)`, set `charDB.unknownQuests[questID] = env.C_Map.GetBestMapForUnit("player") or 0`.
    - `state:UnknownCount(uiMapID) -> n`: count of entries with that map.
  - `ns.Events`: one event frame. `ns.Events.On(event, fn)` adds a listener. It registers the event on the frame the first time. The dispatcher calls each listener in add order inside `pcall`. A listener error prints once per event name and does not stop the other listeners.
  - In `ns.onReady`: create `ns.state`, and add `QUEST_TURNED_IN` → `ns.state:OnTurnedIn(questID)` then `ns.RunRefresh()`. `ns.OnRefresh(fn)` adds `fn` to a callback list. `ns.RunRefresh()` calls each callback in add order inside `pcall`. Tasks 4 and 5 add callbacks.
- **Edge cases:** the same quest turned in twice (one entry); `GetBestMapForUnit` nil (store 0); a known quest (no entry); a listener raising an error.
- **Tests (unit):**
  - `IsDone` true from cache before the flag is true; true from the flag; false otherwise.
  - `OnRefresh`/`RunRefresh`: callbacks run in order; an error in one does not stop the next.
  - `OnTurnedIn` for an unknown quest stores the map; for a known quest stores nothing; stores 0 when the map is nil.
  - `UnknownCount` per map.
  - `events_spec`: listeners run in order; an error in one listener does not stop the next; the event is registered once.
- **Verify:** `make check`
- **Definition of done:**
  - [ ] Each Covers item is observably met, including one observation that failed before the task.
  - [ ] Tests listed above exist and follow the Tests guidelines.
  - [ ] Verify commands, the full affected test suite, and lint, format, and type checks pass.
  - [ ] E2E tests pass, or the accepted alternative from Risks is done.
  - [ ] All three reviews pass with no valid open findings.
  - [ ] Docs and config that describe the changed behavior are updated (`README.md`: unknown quests).
  - [ ] Task heading checkbox ticked; changes committed.

### [ ] 4. Overview window and `/lore`
- **Outcome:** `/lore` opens a window with maps grouped by continent and the quest list of the selected map.
- **Depends on:** 2 (index, progress), 3 (`IsDone`, `UnknownCount`, `ns.OnRefresh`).
- **Covers:** AC10, risks "legacy dungeon UiMapIDs" (window part), "ZoneDB support data missing" (window part), "no e2e" (row builders tested).
- **Files (create):** `src/OverviewModel.lua`, `src/OverviewWindow.lua`, `spec/overview_model_spec.lua`, `spec/overview_window_spec.lua`. **Change:** `LoreCompletion_Forever.toc`, `.luacheckrc` (new globals if any).
- **Implementation:**
  - `ns.OverviewModel.Groups(env, index, state) -> groups`: list of `{ title, maps = { { uiMapID, name, done, total, unknown, complete } } }`.
    - For each map in `index:Maps()`: `info = env.C_Map.GetMapInfo(uiMapID)`.
      - Dungeon (`info.mapType == Enum.UIMapType.Dungeon`): group `Dungeons & Raids`.
      - Else walk `info.parentMapID` with `GetMapInfo` until `mapType == Enum.UIMapType.Continent`. Group title is that continent name. Stop after 10 steps.
      - `info` nil, or no continent found: group `Other`. Name from `info.name`, or `env.C_Map.GetAreaInfo(index:AreaFor(uiMapID))`, or `"Map " .. uiMapID`.
    - Sort groups by title, with `Dungeons & Raids` and `Other` last, in that order. Sort maps by name.
  - `ns.OverviewModel.Quests(index, state, uiMapID, showNames) -> rows`: `{ id, text, done, tags = "[Class] [Profession] [Race]" }`. Undone with `showNames == false` → `text = "???"`. Done first, then undone; each part by quest name (sort by the real name even when the text is `???`).
  - `ns.OverviewModel.Message(index) -> string|nil`: `"QuestieDB zone data not found"` for `index.error == "zonedata"`, `"Character data not available"` for `"player"`.
  - `OverviewWindow.lua`:
    - One frame `LoreCompletionOverview` from `ButtonFrameTemplate`, parent `UIParent`, movable, added to `UISpecialFrames` so Escape closes it.
    - Left: map list with `CreateScrollBoxListLinearView` and `ScrollUtil.InitScrollBoxListWithScrollBar`. Group titles are rows that cannot be selected. Complete maps use gold text (`NORMAL_FONT_COLOR`). Unknown count `+N unknown` in grey.
    - Right: quest list of the selected map, same scroll pattern. `Show names` checkbox at the top, bound to `LoreCompletionDB.showNames`.
    - `ns.Overview.Toggle()`, `ns.Overview.OpenMap(uiMapID)` (opens and selects).
    - `SLASH_LORECOMPLETION1 = "/lore"`; `SlashCmdList.LORECOMPLETION = ns.Overview.Toggle`. Register in `ns.onReady`.
    - `ns.OnRefresh`: rebuild rows when the window is shown.
    - When `Message(index)` is not nil, show it in place of the map list.
- **Edge cases:** no maps; a map whose parent chain has no continent; a map with `GetMapInfo` nil and `GetAreaInfo` nil; `OpenMap` for a map not in the index (open, no selection); toggle twice; `showNames` changed while a map is selected (rows rebuild).
- **Tests (unit):**
  - `overview_model_spec`: grouping by continent with a fake `C_Map` tree; dungeon group; `Other` with each name fallback; group and map sort order; complete flag; unknown counts; quest row order; `???` text; tag string; `Message` for each error.
  - `overview_window_spec` (glue, with recorder stubs): `/lore` registers and calls `Toggle`; `OpenMap` selects the map; changing `Show names` writes `LoreCompletionDB.showNames` and rebuilds rows.
- **Verify:** `make check`
- **Definition of done:**
  - [ ] Each Covers item is observably met, including one observation that failed before the task.
  - [ ] Tests listed above exist and follow the Tests guidelines.
  - [ ] Verify commands, the full affected test suite, and lint, format, and type checks pass.
  - [ ] E2E tests pass, or the accepted alternative from Risks is done.
  - [ ] All three reviews pass with no valid open findings.
  - [ ] Docs and config that describe the changed behavior are updated (`README.md`: `/lore`, window, `Show names`).
  - [ ] Task heading checkbox ticked; changes committed.

### [ ] 5. Tracker module and settings panel
- **Outcome:** the `Lore` module at the top of the Objective Tracker, and the two settings.
- **Depends on:** 2 (index, progress), 3 (`IsDone`, `ns.OnRefresh`, `ns.RunRefresh`, `ns.Events`), 4 (`ns.Overview.OpenMap` for the click).
- **Covers:** AC7, AC8, AC9, risk "Blizzard changes the tracker API", risk "no e2e" (model tested).
- **Files (create):** `src/TrackerModel.lua`, `src/TrackerModule.lua`, `src/SettingsPanel.lua`, `spec/tracker_model_spec.lua`, `spec/tracker_module_spec.lua`, `spec/settings_panel_spec.lua`, `spec/integration_spec.lua`. **Change:** `LoreCompletion_Forever.toc`, `.luacheckrc`.
- **Implementation:**
  - `ns.TrackerModel.Build(env, index, state, db) -> view|nil`:
    - nil when `db.showTracker` is false, the map is nil, or `total == 0`.
    - nil when `db.hideWhenComplete` and `done == total`.
    - Else `{ uiMapID, title = mapName, text = complete and "Complete" or ("%d / %d quests"):format(done, total), percent = math.floor(done / total * 100), complete = done == total }`.
    - Map name from `C_Map.GetMapInfo(uiMapID).name`, else `"Map " .. uiMapID`.
  - `TrackerModule.lua`:
    - `local mixin = CreateFromMixins(ObjectiveTrackerModuleMixin)`. `mixin.headerText = "Lore"`.
    - `mixin:LayoutContents()`: `view = ns.TrackerModel.Build(...)`. If nil, return. Else `block = self:GetBlock("lore")`, `block:SetHeader(view.title)`, `block:AddObjective("progress", view.text)`, `bar = block:AddProgressBar("progress")`, `bar:SetPercent(view.percent)`. When `view.complete`, set the bar color to gold (`bar.Bar:SetStatusBarColor(1, 0.82, 0)`), else reset it to the template default. `block.uiMapID = view.uiMapID`. `return self:LayoutBlock(block)`.
    - `mixin:OnBlockHeaderClick(block)`: `ns.Overview.OpenMap(block.uiMapID)`.
    - Registration: `EventUtil.ContinueAfterAllEvents(register, "PLAYER_ENTERING_WORLD", "VARIABLES_LOADED")`. This is the same trigger as `ObjectiveTrackerManager:Init`. In `register`: create the frame with `CreateFrame("Frame", "LoreCompletionTrackerModule", nil, "ObjectiveTrackerModuleTemplate")`, `Mixin(frame, mixin)`, `frame:SetHeader("Lore")`, `frame.uiOrder = 0`, then `pcall(ObjectiveTrackerManager.SetModuleContainer, ObjectiveTrackerManager, frame, ObjectiveTrackerFrame)`. After the call, check `ObjectiveTrackerManager:GetContainerForModule(frame) == ObjectiveTrackerFrame`. If the call failed or the check is false, print `LoreCompletion: tracker module not available` once.
    - If `ns.disabled`, do not register.
    - Updates: `ns.Events.On` for `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `PLAYER_ENTERING_WORLD` → `frame:MarkDirty()`. `ns.OnRefresh(function() frame:MarkDirty() end)`.
  - `SettingsPanel.lua` (in `ns.onReady`):
    - `category = Settings.RegisterVerticalLayoutCategory("LoreCompletion")`.
    - For each of `showTracker` (`Show tracker module`, default true) and `hideWhenComplete` (`Hide when complete`, default false): `setting = Settings.RegisterAddOnSetting(category, "LoreCompletion_" .. key, key, LoreCompletionDB, "boolean", label, default)`, `Settings.CreateCheckbox(category, setting, tooltip)`, `setting:SetValueChangedCallback(ns.RunRefresh)`.
    - `Settings.RegisterAddOnCategory(category)`.
    - Check the `variableType` argument against `Blizzard_Settings.lua:174` at implementation time. If it takes a `Settings.VarType` value, use `Settings.VarType.Boolean`.
- **Edge cases:** `total == 0`; `done == total == 0` (nil, not complete); `showTracker` false; `hideWhenComplete` true and complete; `hideWhenComplete` true and not complete (shown); `GetMapInfo` nil; `SetModuleContainer` raises an error; `SetModuleContainer` returns without adding (container not ready); `ns.disabled` true.
- **Tests (unit):**
  - `tracker_model_spec`: each nil case; text and percent for `34/72` (47); complete text and flag; name fallback.
  - `tracker_module_spec` (glue, with stubs of `ObjectiveTrackerManager`, `ObjectiveTrackerModuleMixin`, block and bar recorders, and `EventUtil.ContinueAfterAllEvents` that calls at once): `LayoutContents` calls `SetHeader`, `AddObjective`, `AddProgressBar`, `SetPercent` with view values; gold color only when complete; no block when the view is nil; `uiOrder == 0`; the error message prints once when `SetModuleContainer` raises an error, and once when the container check fails; click calls `ns.Overview.OpenMap` with the map; no registration when `ns.disabled`.
  - `settings_panel_spec` (glue): two settings registered with the right keys and defaults; a value change calls `ns.RunRefresh`.
  - `integration_spec` (integration): the check in Validation step 3. Load every file in TOC order with the fakes, fire `ADDON_LOADED`, then `QUEST_TURNED_IN` for a known and an unknown quest. Assert the tracker view changes from `n / m` to `n+1 / m`, and the overview row of the current map shows `+1 unknown`.
- **Verify:** `make check`
- **Definition of done:**
  - [ ] Each Covers item is observably met, including one observation that failed before the task.
  - [ ] Tests listed above exist and follow the Tests guidelines.
  - [ ] Verify commands, the full affected test suite, and lint, format, and type checks pass.
  - [ ] E2E tests pass, or the accepted alternative from Risks is done.
  - [ ] All three reviews pass with no valid open findings.
  - [ ] Docs and config that describe the changed behavior are updated (`README.md`: tracker module and settings).
  - [ ] Task heading checkbox ticked; changes committed.

### [ ] 6. CI and release packaging
- **Outcome:** GitHub Actions runs `make check` on push and pull request. A `v*` tag packages and uploads the addon to CurseForge.
- **Depends on:** 1 (Makefile targets, TOC with `@project-version@`).
- **Covers:** AC11 (CI part), AC12, risks "packager does not know `_Forever`" and "no remote".
- **Files (create):** `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `.pkgmeta`. **Change:** `LoreCompletion_Forever.toc` (add `## X-Curse-Project-ID:` only when O2 is answered), `README.md`.
- **Implementation:**
  - `ci.yml`: on `push` and `pull_request`. Steps:
    1. `actions/checkout@v4`.
    2. Lua 5.1 and LuaRocks with `leafo/gh-actions-lua@v11` (`luaVersion: "5.1"`) and `leafo/gh-actions-luarocks@v5` (unverified versions; check the action READMEs).
    3. `luarocks install busted 2.3.0-1`, `luarocks install luacheck 1.2.0-1`, `luarocks install luacov`.
    4. StyLua 2.6.0 with `JohnnyMorganz/stylua-action@v4` (`version: 2.6.0`, `args: --check .`) (unverified version).
    5. `make lint test BUSTED=busted LUACOV=luacov`.
  - `release.yml`: on `push` of tags `v*`. Steps: `actions/checkout@v4` with `fetch-depth: 0`, then `BigWigsMods/packager@v2` with env `CF_API_KEY: ${{ secrets.CF_API_KEY }}` and `GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}`.
  - `.pkgmeta` (YAML, spaces only):
    ```yaml
    package-as: LoreCompletion
    ignore:
      - spec
      - specs
      - Makefile
      - .busted
      - .luacov
      - .luacheckrc
      - stylua.toml
      - .styluaignore
    ```
  - Packager check: run the packager locally without upload (`release.sh -d` from BigWigsMods/packager, unverified flag) and read the detected game type in the log. If it does not detect Forever, add the game version argument the packager docs give for Forever to `release.yml`, and record it in `README.md`.
- **Edge cases:** no `CF_API_KEY` secret (the packager builds the zip and skips upload); no remote (workflows exist but do not run).
- **Tests:** no Lua test. The CI workflow is the test of `make check` in CI. Validate the YAML with `python -I -c "import sys,yaml; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/workflows/ci.yml .github/workflows/release.yml .pkgmeta` (unverified: needs PyYAML).
- **Verify:**
  - The YAML check above.
  - `make check`
  - After O1 is done: push a branch and see the CI run pass.
- **Definition of done:**
  - [ ] Each Covers item is observably met, including one observation that failed before the task.
  - [ ] Tests listed above exist and follow the Tests guidelines.
  - [ ] Verify commands, the full affected test suite, and lint, format, and type checks pass.
  - [ ] E2E tests pass, or the accepted alternative from Risks is done.
  - [ ] All three reviews pass with no valid open findings.
  - [ ] Docs and config that describe the changed behavior are updated (`README.md`: CI, release, required secrets).
  - [ ] Task heading checkbox ticked; changes committed.

## Validation

Run after the last task:

1. `make check` passes.
2. `make coverage`: each pure module in `src/` (`Bits`, `QuestFilter`, `QuestIndex`, `Progress`, `QuestState`, `Events`, `OverviewModel`, `TrackerModel`, `Init`) has at least 90% line coverage in `luacov.report.out`.
3. An integration spec (`spec/integration_spec.lua`, added in task 5) loads every file in TOC order with the fakes, fires `ADDON_LOADED`, then `QUEST_TURNED_IN` for a known and an unknown quest, and asserts:
   - the tracker view changes from `n/m` to `n+1/m`,
   - the overview shows `+1 unknown` on the current map.
4. Each AC1–AC12 has at least one test or workflow that proves it. List the mapping in the final commit message.
5. In-game checks are not part of validation (D11).

## References

- WoW Forever patch notes and API changes: https://warcraft.wiki.gg/wiki/Patch_1.60 , https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes
- Blizzard UI source, Forever branch: https://github.com/Gethe/wow-ui-source/tree/forever (commit `4cd0ab7`)
- QuestieDB: https://github.com/Questie/QuestieDB (commit `e19dfdf`), `docs/api.md`, `docs/forever.md`, `docs/forever-map-override-audit.md`, `LICENSE.md`
- TOC format: https://warcraft.wiki.gg/wiki/TOC_format
- busted: https://github.com/lunarmodules/busted
- luacheck: https://github.com/lunarmodules/luacheck , BigWigs `.luacheckrc`: https://github.com/BigWigsMods/BigWigs/blob/master/.luacheckrc
- StyLua: https://github.com/JohnnyMorganz/StyLua
- BigWigs packager: https://github.com/BigWigsMods/packager , `.pkgmeta`: https://github.com/BigWigsMods/packager/wiki/Preparing-the-PackageMeta-File , GitHub Actions guide: https://warcraft.wiki.gg/wiki/Using_the_BigWigs_Packager_with_GitHub_Actions

## Open Decisions

- **O1 — Git remote and default branch.** The repository has no remote, and its branch is `master`. CI (AC11 CI part) and releases (AC12) cannot run until a GitHub remote exists. The default branch name (`master` or `main`) changes nothing in the workflows, because they run on all branches.
- **O2 — CurseForge project ID.** AC12 upload needs a CurseForge project and a `CF_API_KEY` secret. Without them, the release workflow builds the zip and skips the upload.

## Completion

When every task is checked and Validation passes, move this file to `specs/done/` with `git mv` (plain `mv` when the file is untracked). Create `specs/done/` if it does not exist. Commit the move.
