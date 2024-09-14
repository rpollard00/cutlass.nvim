--- Licensed under Apache 2.0
--- Taken from neovim github.com/neovim/neovim
--- Modified by Reese Pollard rpollard@gmail.com
local debug = require("cutlass.debug")
local err_message = debug.err_message
local M = {}
---
---@param table   table e.g., { foo = { bar = "z" } }
---@param section string indicating the field of the table, e.g., "foo.bar"
---@return any|nil setting value read from the table, or `nil` not found
local function lookup_section(table, section)
	local keys = vim.split(section, ".", { plain = true }) --- @type string[]
	return vim.tbl_get(table, unpack(keys))
end

local workspace_configuration_handler = function(_, result, ctx)
	debug.log_message("workspace/configuration fired")
	local client_id = ctx.client_id
	local client = vim.lsp.get_client_by_id(client_id)
	if not client then
		err_message("LSP[", client_id, "] client has shut down after sending a workspace/configuration request")
		return
	end
	if not result.items then
		return {}
	end

	local response = {}
	for _, item in ipairs(result.items) do
		if item.section then
			local value = lookup_section(client.settings, item.section)
			debug.log_message("Section: " .. item.section)
			-- For empty sections with no explicit '' key, return settings as is
			if value == nil and item.section == "" then
				value = client.settings
			end
			if value == nil then
				value = vim.NIL
			end
			table.insert(response, value)
		end
	end
	return response
end

M.workspace_configuration_handler = workspace_configuration_handler

return M
