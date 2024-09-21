local debug = require("cutlass.debug")
local registry = require("cutlass.buf_registry")
local api = vim.api
local util = vim.lsp.util
local M = {}

local function hover(_, result, ctx, config)
	debug.log_message("custom hover")
	config = config or {}
	config.focus_id = ctx.method
	-- TODO - this check should be restored but it should use a utility method
	-- that checks that the current buffer is the parent or child
	-- if api.nvim_get_current_buf() ~= ctx.bufnr then
	-- 	-- Ignore result since buffer changed. This happens for slow language servers.
	-- 	return
	-- end
	--
	if not (result and result.contents) then
		if config.silent ~= true then
			vim.notify("No information available")
		end
		return
	end
	debug.log_message("custom hover: Passed the first empty result check")
	local format = "markdown"
	local contents ---@type string[]
	if type(result.contents) == "table" and result.contents.kind == "plaintext" then
		format = "plaintext"
		contents = vim.split(result.contents.value or "", "\n", { trimempty = true })
	else
		contents = util.convert_input_to_markdown_lines(result.contents)
	end
	if vim.tbl_isempty(contents) then
		if config.silent ~= true then
			vim.notify("No information available")
		end
		return
	end
	return vim.lsp.util.open_floating_preview(contents, format, config)
end

M.handlers = {
	hover = hover,
	["textDocument/hover"] = hover,
}

return M
