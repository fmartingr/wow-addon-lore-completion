-- Reads the file list of the TOC, so specs load files in the same order as the game.
return function()
	local paths = {}
	for line in io.lines("LoreCompletion_Forever.toc") do
		if line ~= "" and not line:match("^##") then
			table.insert(paths, (line:gsub("\\", "/")))
		end
	end
	return paths
end
