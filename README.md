# LoreCompletion

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

## License

MIT.
