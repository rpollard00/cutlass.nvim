local debug = require("cutlass.debug")
local registry = require("cutlass.buf_registry")
local api = vim.api
local lsp_util = require("vim.lsp.util")
local ms = require("vim.lsp.protocol").Methods
local validate = vim.validate
local M = {}

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

local function make_proj_position_params()
	local params = lsp_util.make_position_params()
	local projected_bufnr = registry.get_by_id(api.nvim_get_current_buf()).proj_html_bufnr

	if params and params.textDocument then
		params.textDocument = lsp_util.make_text_document_params(projected_bufnr)
	end

	return params
end

function M.hover()
	debug.log_message("invoke custom hover request")
	local params = make_proj_position_params()
	debug.log_message("Position params for hover action: " .. vim.inspect(params))
	local projected_bufnr = registry.get_by_id(api.nvim_get_current_buf()).proj_html_bufnr

	if not projected_bufnr then
		debug.log_message("Projected html bufnr not instantiated")
		return
	end
	request_proj_buf(ms.textDocument_hover, params, projected_bufnr)
end

return M
