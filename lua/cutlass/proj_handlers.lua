local debug = require("cutlass.debug")
local registry = require("cutlass.buf_registry")
local api = vim.api
local util = vim.lsp.util
local M = {}

local html_hover_handler = function(err, result, ctx, config)
	local current_proj_buf = api.nvim_get_current_buf()
	debug.log_message("Current proj buf: " .. current_proj_buf)

	-- local parent_bufnr = registry.get_parent_bufnr(current_proj_buf)
	--
	-- if not parent_bufnr then
	-- 	debug.log_message("Invalid parent bufnr")
	-- 	return
	-- end

	-- override_hover(err, result, ctx, config)
	debug.log_message("hit custom html_hover handler proj buf: " .. current_proj_buf .. " parent: " .. parent_bufnr)
	debug.log_message(vim.inspect(result))
end

local function override_hover(_, result, ctx, config)
	debug.log_message("custom hover")
	config = config or {}
	config.focus_id = ctx.method
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
	hover = override_hover,
	["textDocument/hover"] = override_hover,
}

return M
