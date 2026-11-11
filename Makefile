BUSTED ?= $(HOME)/.luarocks/bin/busted
LUACOV ?= $(HOME)/.luarocks/bin/luacov
.PHONY: lint fmt fmt-check test coverage check
lint: ; luacheck .
fmt: ; stylua .
fmt-check: ; stylua --check .
test: ; $(BUSTED)
coverage: ; rm -f luacov.stats.out luacov.report.out && $(BUSTED) --coverage && $(LUACOV)
check: lint fmt-check test
