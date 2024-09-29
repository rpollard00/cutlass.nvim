local api = vim.api
local registry = require("cutlass.buf_registry")
local debug = require("cutlass.debug")
local util = require("cutlass.util")
local lsp_util = require("vim.lsp.util")

local M = {}

-- Think we can get away with just assuming \n is the line ending, the \r continue to exist in the buffer and
-- but should not affect any functionality and that way they get preserved, and we also support both common
-- line endings.
--
-- The CS buffer seemed to have mixed line endings (yikes)
local function get_line_ending(content)
	return "\n"
end

local function bump_proj_vers(bufname, proj_buf_type)
	local buftype = "proj_html_vers"
	if proj_buf_type == "cs" then
		buftype = "proj_cs_vers"
	end

	local current_version = registry.get_by_name(bufname)[buftype] or 0
	current_version = current_version + 1
	registry.get_by_name(bufname)[buftype] = current_version

	debug.log_message("Projected " .. buftype .. " version is " .. current_version)
end

local function transform_and_replace_buf(bufnr, changes, bufname, proj_buf_type)
	local buffer_content = api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local content = table.concat(buffer_content, "\n")

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
	local transformed_lines = vim.split(content, "\n")
	bump_proj_vers(bufname, proj_buf_type)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, transformed_lines)
end

local force_rzls_projected_refresh = function(bufnr, buftype)
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
	if buftype == "cs" then
		registry.reset_projected_csharp_buf(bufnr)
	else
		registry.reset_projected_html_buf(bufnr)
	end

	client.notify("textDocument/didOpen", open_params)
end

---@param bufnr integer
---@return boolean
function M.is_razor_buffer(bufnr)
	local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
	return filetype == "razor" or filetype == "cshtml"
end

-- take original position, projected bufnr - output projected bufnr position
function M.razor_to_cs_pos(position, bufnr)
	assert(position.line ~= nil, "Nil line position was provided to razor_to_cs_pos")
	assert(position.character ~= nil, "Nil character position was provided to razor_to_cs_pos")
	local buffer_content = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	debug.log_message("Razor mapping to cs: Starting position: " .. vim.inspect(position))

	local target_line = position.line + 1 -- the line sent to the lsp is 0 indexed but the cs buffer is one indexed
	local cs_position = {}
	cs_position.character = position.character

	for actual_line_num = #buffer_content, 0, -1 do
		local line = buffer_content[actual_line_num]
		local line_num, _ = string.match(line, '^#line (%d+) "(.-)"')

		if not line_num then
		else
			if tonumber(line_num) <= target_line then
				-- we're always at least one line below the #line statement
				-- 1 + 40 - 36 = 5 -- offset = 5
				-- actual_line_num is 150 (where the line statement is)
				--
				local offset = target_line - line_num
				cs_position.line = actual_line_num + offset
				debug.log_message("Razor mapping to cs: FOUND cs position: " .. vim.inspect(cs_position))
				return cs_position
			end
		end
	end

	vim.notify("Position could not be mapped to projected buffer", 5)
	cs_position = position
	return cs_position
end

function M.cs_to_razor_pos(position, proj_bufnr)
	assert(position.line ~= nil, "Nil line position was provided to cs_to_razor_pos")
	assert(position.character ~= nil, "Nil character position was provided to cs_to_razor_pos")
	local buffer_content = api.nvim_buf_get_lines(proj_bufnr, 0, -1, false)
	debug.log_message("CS mapping to razor: Starting position: " .. vim.inspect(position))

	local target_line = position.line - 1 -- the line sent to the lsp is 0 indexed but the cs buffer is one indexed
	local razor_position = {}
	razor_position.character = position.character

	for actual_line_num = #buffer_content, 0, -1 do
		local line = buffer_content[actual_line_num]
		local line_num, _ = string.match(line, '^#line (%d+) "(.-)"')

		if not line_num then
		else
			if tonumber(line_num) <= target_line then
				local offset = target_line - actual_line_num
				razor_position.line = tonumber(line_num) + offset
				debug.log_message("CS mapping to razor: FOUND razor position: " .. vim.inspect(razor_position))
				return razor_position
			end
		end
	end

	vim.notify("Projected position could not be mapped to real buffer", 5)
	razor_position = position
	return razor_position
end

function M.make_proj_position_params()
	local params = lsp_util.make_position_params()
	local projected_bufnr = registry.get_by_id(api.nvim_get_current_buf()).proj_html_bufnr

	if params and params.textDocument then
		params.textDocument = lsp_util.make_text_document_params(projected_bufnr)
	end

	return params
end

function M.make_cs_position_params()
	local params = lsp_util.make_position_params()
	local projected_bufnr = registry.get_by_id(api.nvim_get_current_buf()).proj_cs_bufnr
	params.position = M.razor_to_cs_pos(params.position, projected_bufnr)

	if params and params.textDocument then
		params.textDocument = lsp_util.make_text_document_params(projected_bufnr)
	end

	return {
		position = params.position,
		textDocument = params.textDocument,
	}
end

function M.make_range_params_cs(window, offset_encoding)
	local params = M.make_cs_position_params()
	return {
		textDocument = params.textDocument,
		range = { start = params.position, ["end"] = params.position },
	}
end

function M.hijack_cs_action(input_action, proj_bufnr)
	local input_range_end = input_action.data.Range["end"]
	local input_range_start = input_action.data.Range["start"]

	local parent_bufnr = registry.get_parent_bufnr(proj_bufnr)

	-- debug.log_message("INPUT ACTION Edit docChange" .. vim.inspect(input_action.edit.documentChanges))
	input_action.data.Range["end"] = M.cs_to_razor_pos(input_range_end, proj_bufnr)
	input_action.data.Range["start"] = M.cs_to_razor_pos(input_range_start, proj_bufnr)
	input_action.data.TextDocument.uri = vim.uri_from_bufnr(parent_bufnr or 0)
	local documentChanges = input_action.edit.documentChanges

	for _, change in ipairs(documentChanges) do
		local textDocument = change.textDocument
		textDocument.uri = vim.uri_from_bufnr(parent_bufnr or 0)

		for _, edit in ipairs(change.edits) do
			local range = edit.range
			local current_start = range["start"]
			local current_end = range["end"]

			range["start"] = M.cs_to_razor_pos(current_start, proj_bufnr)
			range["end"] = M.cs_to_razor_pos(current_end, proj_bufnr)
		end
	end

	return input_action
	--
end

function M.hijack_cs_ctx(input_ctx)
	local proj_bufnr = input_ctx.bufnr
	if not proj_bufnr then
		error("Hijack_cs proj_bufnr is nil")
	end
	local parent_bufnr = registry.get_parent_bufnr(proj_bufnr)
	input_ctx.bufnr = parent_bufnr

	local cs_pos_start = input_ctx.params.range["start"]
	local cs_pos_end = input_ctx.params.range["end"]

	input_ctx.params.range["start"] = M.cs_to_razor_pos(cs_pos_start, proj_bufnr)
	input_ctx.params.range["end"] = M.cs_to_razor_pos(cs_pos_end, proj_bufnr)

	input_ctx.params.textDocument = vim.uri_from_bufnr(parent_bufnr or 0)

	return input_ctx
end

M.force_rzls_projected_refresh = force_rzls_projected_refresh
M.get_line_ending = get_line_ending
M.bump_proj_vers = bump_proj_vers
M.transform_and_replace_buf = transform_and_replace_buf

return M
