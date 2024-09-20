--- Licensed under Apache 2.0
--- Taken from neovim github.com/neovim/neovim
--- Modified by Reese Pollard rpollard@gmail.com
local debug = require("cutlass.debug")
local registry = require("cutlass.buf_registry")
local err_message = debug.err_message
local util = require("cutlass.util")
local html = require("cutlass.html_buf_util")
local api = vim.api
local lsp_util = require("vim.lsp.util")
local ms = require("vim.lsp.protocol").Methods
local validate = vim.validate
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

	local bufnr = registry.get_by_name(bufname).parent_bufnr

	if registry.get_by_name(bufname).proj_html_vers >= buf_version then
		was_empty = true -- force line ending and sync html version
		html.force_rzls_projected_html_refresh(bufnr)
	end
	-- notification and then return

	-- we can set the line ending when receiving the newText the first time
	if was_empty and #changes > 0 then
		registry.get_by_name(bufname).proj_html_line_ending = html.get_line_ending(changes[1].newText)
		registry.get_by_name(bufname).proj_html_vers = buf_version
	end

	debug.log_message("host_document_path: " .. bufname)
	debug.log_message("host_document_version: " .. buf_version)

	local proj_html_bufnr = registry.get_by_name(bufname).proj_html_bufnr
	html.transform_and_replace_buf(proj_html_bufnr, changes, bufname)

	local response = {}

	return response
end

local razor_update_csharp_buffer_handler = function(err, result, ctx, config)
	debug.log_message("razor/updateHtmlBuffer fired")
	local response = {}

	return response
end

local text_document_hover = function(err, result, ctx, config)
	vim.lsp.buf.hover()
end

function hover()
	local params = util.make_position_params()
	request(ms.textDocument_hover, params)
end

---@param method (string) LSP method name
---@param params (table|nil) Parameters to send to the server
---@param target_bufnr integer
---@param handler lsp.Handler? See |lsp-handler|. Follows |lsp-handler-resolution|
---
---@return table<integer, integer> client_request_ids Map of client-id:request-id pairs
---for all successful requests.
---@return function _cancel_all_requests Function which can be used to
local function request_proj_buf(method, params, target_bufnr, handler)
	validate({
		method = { method, "s" },
		handler = { handler, "f", true },
	})
	debug.log_message("request_proj_buf on bufnr: " .. target_bufnr)
	return vim.lsp.buf_request(target_bufnr, method, params, handler)
end

local function hover()
	debug.log_message("invoke custom hover request")
	local params = lsp_util.make_position_params()
	local projected_bufnr = registry.get_by_id(api.nvim_get_current_buf()).proj_html_bufnr

	if not projected_bufnr then
		debug.log_message("Projected html bufnr not instantiated")
		return
	end
	request_proj_buf(ms.textDocument_hover, params, projected_bufnr)
end

M.workspace_configuration_handler = workspace_configuration_handler
M.razor_update_html_buffer_handler = razor_update_html_buffer_handler
M.razor_update_csharp_buffer_handler = razor_update_csharp_buffer_handler
M.html_hover_handler = html_hover_handler
M.hover = hover

return M
