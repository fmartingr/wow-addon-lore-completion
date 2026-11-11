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

## Development

- `make lint` runs luacheck.
- `make fmt` and `make fmt-check` run StyLua.
- `make test` runs busted on Lua 5.1.
- `make coverage` writes `luacov.report.out`.
- `make check` runs lint, fmt-check and test.

## License

MIT.
