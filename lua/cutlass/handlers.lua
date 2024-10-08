--- Licensed under Apache 2.0
--- Taken from neovim github.com/neovim/neovim
--- Modified by Reese Pollard rpollard@gmail.com
local debug = require("cutlass.debug")
local registry = require("cutlass.buf_registry")
local err_message = debug.err_message
local util = require("cutlass.util")
local buf_util = require("cutlass.buf_util")
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
	-- debug.log_message("razor/updateHtmlBuffer fired")
	if not result then
		debug.log_message("razor/updateHtmlBuffer result was nil")
		return
	end

	-- debug.log_message(vim.inspect(util.lookup_section(result, "changes")))

	local bufname = util.lookup_section(result, "hostDocumentFilePath")
	local buf_version = util.lookup_section(result, "hostDocumentVersion")
	local was_empty = util.lookup_section(result, "previousWasEmpty")
	local changes = util.lookup_section(result, "changes")

	local bufnr = registry.get_by_name(bufname).parent_bufnr

	if registry.get_by_name(bufname).proj_html_vers >= buf_version then
		was_empty = true -- force line ending and sync html version
		buf_util.force_rzls_projected_refresh(bufnr, "html")
	end
	-- notification and then return

	-- we can set the line ending when receiving the newText the first time
	if was_empty and #changes > 0 then
		registry.get_by_name(bufname).proj_html_line_ending = buf_util.get_line_ending(changes[1].newText, "html")
		registry.get_by_name(bufname).proj_html_vers = buf_version
	end

	-- debug.log_message("host_document_path: " .. bufname)
	-- debug.log_message("host_document_version: " .. buf_version)

	local proj_html_bufnr = registry.get_by_name(bufname).proj_html_bufnr
	buf_util.transform_and_replace_buf(proj_html_bufnr, changes, bufname, "html")

	local response = {}

	return response
end

local razor_update_csharp_buffer_handler = function(err, result, ctx, config)
	-- debug.log_message("razor/updateCSharpBuffer fired")
	if not result then
		-- debug.log_message("razor/updateCSharpBuffer result was nil")
		return
	end

	-- debug.log_message(vim.inspect(util.lookup_section(result, "changes")))

	local bufname = util.lookup_section(result, "hostDocumentFilePath")
	local buf_version = util.lookup_section(result, "hostDocumentVersion")
	local was_empty = util.lookup_section(result, "previousWasEmpty")
	local changes = util.lookup_section(result, "changes")

	local bufnr = registry.get_by_name(bufname).parent_bufnr

	if registry.get_by_name(bufname).proj_cs_vers >= buf_version then
		was_empty = true -- force line ending and sync csharp version
		buf_util.force_rzls_projected_refresh(bufnr, "cs")
	end
	-- notification and then return

	-- we can set the line ending when receiving the newText the first time
	if was_empty and #changes > 0 then
		registry.get_by_name(bufname).proj_cs_line_ending = buf_util.get_line_ending(changes[1].newText)
		registry.get_by_name(bufname).proj_cs_vers = buf_version
	end

	-- debug.log_message("host_document_path: " .. bufname)
	-- debug.log_message("host_document_version: " .. buf_version)

	local proj_cs_bufnr = registry.get_by_name(bufname).proj_cs_bufnr
	buf_util.transform_and_replace_buf(proj_cs_bufnr, changes, bufname, "cs")

	local response = {}

	return response
end

local text_document_hover = function(err, result, ctx, config)
	vim.lsp.buf.hover()
end

M.workspace_configuration_handler = workspace_configuration_handler
M.razor_update_html_buffer_handler = razor_update_html_buffer_handler
M.razor_update_csharp_buffer_handler = razor_update_csharp_buffer_handler

return M
