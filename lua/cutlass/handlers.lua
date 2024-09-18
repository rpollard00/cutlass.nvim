--- Licensed under Apache 2.0
--- Taken from neovim github.com/neovim/neovim
--- Modified by Reese Pollard rpollard@gmail.com
local debug = require("cutlass.debug")
local registry = require("cutlass.buf_registry")
local err_message = debug.err_message
local util = require("cutlass.util")
local html = require("cutlass.html_buf_util")
local M = {}

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
			local value = util.lookup_section(client.settings, item.section)
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

local razor_update_html_buffer_handler = function(err, result, ctx, config)
	debug.log_message("razor/updateHtmlBuffer fired")
	if not result then
		debug.log_message("razor/updateHtmlBuffer result was nil")
		return
	end

	debug.log_message(vim.inspect(util.lookup_section(result, "changes")))

	local bufname = util.lookup_section(result, "hostDocumentFilePath")
	local buf_version = util.lookup_section(result, "hostDocumentVersion")
	local was_empty = util.lookup_section(result, "previousWasEmpty")
	local changes = util.lookup_section(result, "changes")

	-- TODO if the hostDocumentVersion is <= our document version then we should clear our projected buffer, invoke the didChange
	-- notification and then return

	-- we can set the line ending when receiving the newText the first time
	if was_empty and #changes > 0 then
		registry.get_by_name(bufname).proj_html_line_ending = html.get_line_ending(changes[1].newText)
	end

	debug.log_message("host_document_path: " .. bufname)
	debug.log_message("host_document_version: " .. buf_version)

	local bufnr = registry.get_by_name(bufname).proj_html_bufnr
	html.transform_and_replace_buf(bufnr, changes, bufname)

	local response = {}

	return response
end

local razor_update_csharp_buffer_handler = function(err, result, ctx, config)
	debug.log_message("razor/updateHtmlBuffer fired")
	local response = {}

	return response
end

M.workspace_configuration_handler = workspace_configuration_handler
M.razor_update_html_buffer_handler = razor_update_html_buffer_handler
M.razor_update_csharp_buffer_handler = razor_update_csharp_buffer_handler

return M
