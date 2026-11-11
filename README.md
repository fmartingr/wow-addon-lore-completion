# LoreCompletion

WoW addon for the **WoW Forever** client (patch 1.60.x). It shows how many quests you completed on each map.

## Requirements

- **QuestieDB** addon (contract version 4). It supplies all quest data at runtime. This repository contains no QuestieDB data.

## Development

- `make lint` runs luacheck.
- `make fmt` and `make fmt-check` run StyLua.
- `make test` runs busted on Lua 5.1.
- `make coverage` writes `luacov.report.out`.
- `make check` runs lint, fmt-check and test.

## License

MIT.
