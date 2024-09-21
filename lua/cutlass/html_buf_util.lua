local api = vim.api
local registry = require("cutlass.buf_registry")
local debug = require("cutlass.debug")
local util = require("cutlass.util")

local M = {}
---@return string
local function get_line_ending(content)
	local line_ending = "\n"
	if content:find("\r\n") then
		line_ending = "\r\n"
	end

	return line_ending
end

local function bump_proj_html_vers(bufname)
	local current_version = registry.get_by_name(bufname).proj_html_vers or 0

	current_version = current_version + 1
	registry.get_by_name(bufname).proj_html_vers = current_version

	debug.log_message("Projected html version is " .. current_version)
end

local function transform_and_replace_buf(bufnr, changes, bufname)
	local buffer_content = api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local content = table.concat(buffer_content, "\r\n")

	for i = #changes, 1, -1 do
		local change = changes[i]
		local length = util.lookup_section(change, "span.length")
		local offset = util.lookup_section(change, "span.start")
		local change_body = util.lookup_section(change, "newText")

		-- pretty sure this is what a refresh of the full data looks like
		if offset == 0 and length == 0 and #content > 0 then
			content = change_body
		else
			content = content:sub(1, offset) .. change_body .. content:sub(offset + length + 1)
		end
	end
	local transformed_lines = vim.split(content, "\r\n")
	bump_proj_html_vers(bufname)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, transformed_lines)
end

local force_rzls_projected_html_refresh = function(bufnr)
	local client = util.get_cutlass_client()

	local uri = vim.uri_from_bufnr(bufnr)

	local close_params = {
		textDocument = {
			uri = uri,
		},
	}

	local open_params = {
		textDocument = {
			uri = uri,
			languageId = "razor",
			version = 0,
			text = vim.lsp._buf_get_full_text(bufnr),
		},
	}

	client.notify("textDocument/didClose", close_params)
	registry.reset_projected_html_buf(bufnr)
	client.notify("textDocument/didOpen", open_params)
end

M.force_rzls_projected_html_refresh = force_rzls_projected_html_refresh
M.get_line_ending = get_line_ending
M.bump_proj_html_vers = bump_proj_html_vers
M.transform_and_replace_buf = transform_and_replace_buf

return M
