local debug = require("cutlass.debug")
local registry = require("cutlass.buf_registry")
local api = vim.api
local util = vim.lsp.util
local buf_util = require("cutlass.buf_util")
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

local cs_base_handlers = vim.deepcopy(vim.lsp.handlers)

local function cs_outer_handler(err, result, ctx, config)
	assert(ctx.bufnr ~= nil, "csharp handler ctx bufnr was nil, this should never be nil")
	assert(ctx.method ~= nil, "csharp handler ctx method was nil, this should never be nil")

	local method = ctx.method -- this is the method string
	local bufnr = ctx.bufnr -- this is the projected buffer

	debug.log_message("Invoke cs outer handler method: " .. method .. " on bufnr: " .. bufnr)
	if not result then
		debug.log_message("Received nil result in handler for: " .. method)
		return
	end
	-- result should have Position or Range
	-- we just mutate it right if provided
	if result.Position then
		result.Position = buf_util.translate_cs_pos_to_razor(result.Position)
	end

	if result.Range then
		result.Range = buf_util.translate_cs_range_to_razor(result.Range)
	end

	ctx.bufnr = registry.get_parent_bufnr(ctx.bufnr)
	--
	cs_base_handlers[method](err, result, ctx, config)
end

local function wrap_handlers(wrapper)
	local base_handlers = vim.deepcopy(vim.lsp.handlers)

	local handlers = {}
	for method, _ in pairs(base_handlers) do
		debug.log_message("Wrapped handler method: " .. method)
		handlers[method] = wrapper
	end

	return handlers
end

M.handlers = {
	hover = hover,
	["textDocument/hover"] = hover,
}
M.cs_handlers = wrap_handlers(cs_outer_handler)

return M
