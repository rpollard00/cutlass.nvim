--- Licensed under Apache 2.0
--- Taken from neovim github.com/neovim/neovim
--- Modified by Reese Pollard rpollard@gmail.com
local debug = require("cutlass.debug")
local registry = require("cutlass.buf_registry")
local err_message = debug.err_message
local api = vim.api
local M = {}
---
---@param table   table e.g., { foo = { bar = "z" } }
---@param section string indicating the field of the table, e.g., "foo.bar"
---@return any|nil setting value read from the table, or `nil` not found
local function lookup_section(table, section)
	if table[section] ~= nil then
		return table[section]
	end

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

--- format
---
-- {
-- changes = { {
--     newText = "/*~~*/ /*~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~*/\r\n\r\n<Router AppAssembly=\"/*~~~~~~~~~~~~~~~~~*/\">\r\n<Found></Found>\r\n    <Found Context=\"routeData\">\r\n        <RouteView RouteData=\"/*~~~~~~*/\" DefaultLayout=\"/*~~~~~~~~~~~~~~~*/\" />\r\n        <FocusOnNavigate RouteData=\"/*~~~~~~*/\" Selector=\"h1\" />\r\n    </Found>\r\n    <NotFound>\r\n        <PageTitle>Not found</PageTitle>\r\n        <LayoutView Layout=\"/*~~~~~~~~~~~~~~~*/\">\r\n            <p role=\"alert\">Sorry, there's nothing at this address.</p>\r\n        </LayoutView>\r\n    </NotFound>\r\n</Router>\r\n<Taco>\r\n</Taco>\r\n<p>Cool html tags</p>\r\n\r\n/*~*/ ~\r\n    /*~~~~~~~~~~~~~~~~~~~*/ ~~ /**/ /*~~~~~~~*/\r\n~\r\n",
--     span = {
--       length = 0,
--       start = 0
--     }
--   } },
-- hostDocumentFilePath = "/Users/reesepollard/projects/dotnet/BlazorOmni/App.razor",
-- hostDocumentVersion = 3,
-- previousWasEmpty = true,
-- projectKeyId = "/var/folders/h3/h02bv04d1759kh51qznnql3h0000gn/T/d7291030b0ed48f4975ac46ecb65b0eb/__MISC_RAZOR_PROJECT__/"
-- }
-- sig for handlers is function(err, result, ctx, config)
--
---@return string
local function get_line_ending(content)
	local line_ending = "\n"
	if content:find("\r\n") then
		line_ending = "\r\n"
	end

	return line_ending
end

local function trim_newline(lines)
	if #lines > 1 and lines[#lines] == "" then
		table.remove(lines, #lines)
	end
	return lines
end

local function replace_buffer_content(bufnr, lines)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end
-- Function to insert new lines into a table and shift the remaining lines
--
local function shift_expand_table(tbl, start_index)
	for i = #tbl + 1, start_index, -1 do
		tbl[i + 1] = tbl[i]
	end
end

local function insert_lines(tbl, start_index, new_lines)
	local shift_count = 0
	debug.log_message("Insert lines start_index: " .. start_index)

	for i, line in ipairs(new_lines) do
		local insert_position = start_index + i - 1 + shift_count
		debug.log_message("Insert lines position: " .. insert_position)

		if line == "" then
			shift_expand_table(tbl, start_index)
			tbl[insert_position] = ""
		else
			tbl[insert_position] = line
		end
	end
end

local function get_start_line_to_modify_from_offset(bufnr, offset)
	local buffer_content = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local total_buffer_lines = #buffer_content

	debug.log_message("Total buffer lines: " .. total_buffer_lines .. " | Target offset: " .. offset)

	local current_newlines_in_offset = 0
	debug.log_message("Current newlines in offset" .. current_newlines_in_offset)
	for index, _ in ipairs(buffer_content) do
		if index == #buffer_content then
			return index
		end

		local current_offset = api.nvim_buf_get_offset(bufnr, index - 1)
		local next_offset = api.nvim_buf_get_offset(bufnr, index)
		current_newlines_in_offset = current_newlines_in_offset + 1
		debug.log_message(
			"Line " .. index .. ": lower bound offset: " .. current_offset .. ". high bound offset: " .. next_offset
		)

		if offset >= current_offset and offset < next_offset then
			debug.log_message(
				"Current offset of " .. offset .. " within bounds. " .. current_offset .. " to " .. next_offset
			)
			return index
		end
		-- we need to shift the offset by one byte for a newline on each subsequent line
		offset = offset - 1
	end

	return 0
end

local function insert_lines_into_buffer(bufnr, start_line, new_lines)
	-- Get current buffer content as a table
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- Insert new lines at the specified position
	insert_lines(lines, start_line, new_lines)

	-- Update the buffer with the new content
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

local function set_buffer_content_from_offset(bufnr, lines, start_row, length)
	debug.log_message("Lines: " .. vim.inspect(lines))

	debug.log_message("Incremental replacement")
	debug.log_message("Start row: " .. start_row)
	insert_lines_into_buffer(bufnr, start_row, lines)
end

---@return integer
local function get_change_length(change_lines)
	local total_length = 0
	for _, value in ipairs(change_lines) do
		total_length = total_length + #value
	end

	return total_length
end

local razor_update_html_buffer_handler = function(err, result, ctx, config)
	debug.log_message("razor/updateHtmlBuffer fired")
	-- boils down to find the parent buffer by hostDocumentFilePath in the registry
	-- get a reference to the projected html buffer
	-- then iterate over changes
	-- use the span data to find where to write to the buffer and how much of the buffer it should overwrite
	if not result then
		debug.log_message("razor/updateHtmlBuffer result was nil")
		return
	end

	debug.log_message(vim.inspect(lookup_section(result, "changes")))

	local bufname = lookup_section(result, "hostDocumentFilePath")
	local buf_version = lookup_section(result, "hostDocumentVersion")

	local changes = lookup_section(result, "changes")
	debug.log_message("host_document_path: " .. bufname)
	debug.log_message("host_document_version: " .. buf_version)

	-- each change is a newText and span
	for _, change in ipairs(changes) do
		local length = lookup_section(change, "span.length")
		local start = lookup_section(change, "span.start")
		local change_body = lookup_section(change, "newText")
		debug.log_message("Change Length: " .. length .. " Change Start: " .. start)
		local untrimmed_lines = vim.split(change_body, get_line_ending(change_body))
		local lines = trim_newline(untrimmed_lines)
		local bufnr = registry.get_by_path(bufname).proj_html_bufnr
		local start_row = get_start_line_to_modify_from_offset(bufnr, start)

		local total_change_length = get_change_length(lines)

		if start == 0 and length == 0 and total_change_length > 0 then
			replace_buffer_content(bufnr, lines)
		else
			debug.log_message("set buffer content from offset at start position" .. start)
			set_buffer_content_from_offset(bufnr, lines, start_row, length)
		end
	end

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
