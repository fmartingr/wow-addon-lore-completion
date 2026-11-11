-- Loads addon files in TOC order against stub globals.
local stubs = require("spec.helpers.wow_stubs")

-- Specs run in a sandbox env; addon chunks use the real globals, exposed here as M.G.
local M = { G = _G }
local saved = {}

function M.reset()
	for key, old in pairs(saved) do
		_G[key] = old.value
	end
	saved = {}
end

function M.load(paths, overrides)
	M.reset()
	local globals, ctx = stubs.new()
	for key, value in pairs(overrides or {}) do
		globals[key] = value
	end
	for key, value in pairs(globals) do
		saved[key] = { value = rawget(_G, key) }
		_G[key] = value
	end
	ctx.globals = globals
	local ns = {}
	for _, path in ipairs(paths) do
		assert(loadfile(path))("LoreCompletion", ns)
	end
	return ns, ctx
end

return M
