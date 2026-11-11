# LoreCompletion

<p align="center">
  <img src="assets/icon-256.png" alt="LoreCompletion icon" width="128">
</p>

WoW addon for the **WoW Forever** client (patch 1.60.x). It shows how many quests you completed on each map.

## Requirements

- **QuestieDB** addon (contract version 4). It supplies all quest data at runtime. This repository contains no QuestieDB data.

## Counting rules

A quest counts for your character when all of these are true:

- QuestieDB knows the quest and the quest has a zone.
- The quest fits your race and class.
- The quest is not repeatable, daily, weekly or monthly.

Each quest sits on one map. A subzone does not add to its parent zone.
Quests have tags: `[Class]`, `[Profession]` and `[Race]`.

## Unknown quests

QuestieDB data for Forever is not complete. When you turn in a quest that QuestieDB does not know,
the addon saves the quest and the map for your character. The count shows as `+N unknown`.
Unknown quests never change the `done / total` numbers.

## Overview window

`/lore` opens the overview window. The left list shows maps grouped by continent, with `done/total` for each map.
The right list shows the quests of the selected map. Undone quests show `???` until you enable `Show names`.

Each quest shows its level. The level color uses the Blizzard difficulty colors for your character level:
red, orange, yellow, green or grey. A blue `∞` icon marks a quest that only WoW Forever has.
QuestieDB has no origin field, so the addon marks each quest with an ID of 10000 or higher as a Forever quest.

Quest chains stay together. Each step shows below its prerequisite with more indent.
Many chains have steps with the same name. The indent shows that they are different quests.
A chain shows in the area of its first step. A completed chain shows before chains that are not complete.

## Quest givers on the world map

The world map shows no quest givers until you select them. Click a quest in the overview window to pin its quest giver.
The quest row then shows a `!` icon, and the world map shows a `!` icon at the quest giver. Click the quest again to remove the pin.
Pins are saved for each character. A completed quest has no pin.

The map icon is yellow when one of its quests is available and not too low for you. Otherwise it is grey.
A quest is available when your level is high enough and its prerequisites are done.
The tooltip lists the pinned quests with their levels.

The positions come from QuestieDB. You cannot pin a quest that starts from an item or has no known quest giver position.
A quest giver with many spawn points shows at most 10 icons on one map.

## Tracker module and settings

The `Lore` module sits at the top of the Objective Tracker. It shows the progress of your current map.
The bar turns gold when the map is complete. Click the map name to open the overview window.
The `LoreCompletion` category in the Settings panel has two options: `Show tracker module` and `Hide when complete`.

## Development

- `make lint` runs luacheck.
- `make fmt` and `make fmt-check` run StyLua.
- `make test` runs busted on Lua 5.1.
- `make coverage` writes `luacov.report.out`.
- `make check` runs lint, fmt-check and test.

## CI and release

- GitHub Actions runs lint, format check and tests on each push and pull request.
- A tag `v*` starts the release workflow. It packages the addon with the BigWigs packager.
- The upload to CurseForge needs the secret `CF_API_TOKEN` and a `## X-Curse-Project-ID:` line in the TOC file.
  Without them, the packager builds the zip and skips the upload.
- The packager v2.7.0 does not search for `_Forever.toc`. The workflow copies the file to `_Camelot.toc` and passes `-g forever`.
  This was read from the packager source. It was not run, so check the first release log for the detected game version.

## CI and release

- GitHub Actions runs lint, format check and tests on each push and pull request.
- A tag `v*` starts the release workflow. It packages the addon with the BigWigs packager.
- The upload to CurseForge needs the secret `CF_API_TOKEN` and a `## X-Curse-Project-ID:` line in the TOC file.
  Without them, the packager builds the zip and skips the upload.
- The packager v2.7.0 does not search for `_Forever.toc`. The workflow copies the file to `_Camelot.toc` and passes `-g forever`.
  This was read from the packager source. It was not run, so check the first release log for the detected game version.

## License

MIT.
