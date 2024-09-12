local Path = require("plenary.path")
local debug = require("cutlass.debug")
local MAX_SEARCH_DEPTH = 10

---@param patterns table
---@param target string
---@return string?
local has_pattern = function(patterns, target)
	for _, pattern in ipairs(patterns) do
		debug.log_message("has_pattern checking pattern " .. pattern .. " at target " .. target)

		local search_pattern = target .. "/" .. pattern
		local found_pattern = vim.fn.glob(search_pattern)

		if found_pattern ~= "" then
			debug.log_message("!!has_pattern found pattern " .. pattern .. " at target " .. target)
			return target
		end
	end
end

---@param patterns table
---@param startpath string
---@param max_parent_search integer
---@return string?
local find_root_project = function(patterns, startpath, max_parent_search)
	debug.log_message("Find root project> startpath: " .. startpath)
	local path = Path:new(startpath)

	local oldest_ancestor = nil

	-- TODO - I need to support windows and posix file systems
	-- for now set a max search depth to a constant, 10 levels is probably deep enough in mo st
	-- cases but you may want to enumerate further back for some insane reason?
	-- At some point we may want to parse the sln/csproj files and see if they reference the project
	-- closest to the source file. I think this works for now.
	--
	-- Could also support custom options ie choose nearest or only take proj or only take solution idk
	for i, parent in ipairs(path:parents()) do
		debug.log_message("Searching parent idx " .. i .. " parent: " .. parent)
		if i >= math.max(MAX_SEARCH_DEPTH or 0, max_parent_search or 0) then
			debug.log_message("Oldest ancestor found: " .. (oldest_ancestor or "[NOT FOUND]"))
			return oldest_ancestor
		end

		local found_pattern = has_pattern(patterns, parent)

		if found_pattern then
			debug.log_message("Found rootdir " .. i .. " dir: " .. parent)
			oldest_ancestor = found_pattern
		end
	end

	debug.log_message("Oldest ancestor found: " .. (oldest_ancestor or "[NOT FOUND]"))
	return oldest_ancestor
end

return {
	find_root_project = find_root_project,
}
