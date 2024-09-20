local debug = require("cutlass.debug")
local lspconfig = require("lspconfig")
local util = require("cutlass.util")
local api = vim.api

local M = {}
local registry = {}
local registry_bufname = {}

-- need to be able to clear the buffer
-- need to be able to fully replace the buffer content
-- edit a given position
-- take a list of positions(spans) and content and replace that span with the new content
-- need to figure out how the versioning works and bump it when necessary idk

---@class ProjectedBufState
---@field bufname string -- bufname is the full path
---@field parent_bufnr integer
---@field root_dir string?
---@field proj_html_bufnr integer?
---@field proj_html_vers integer
---@field proj_html_line_ending string
---@field proj_cs_bufnr integer?
---@field proj_cs_vers integer?
---@field proj_cs_line_ending string

---@param parent_bufnr integer
---@param bufname string
---@param root_dir string?
---@return ProjectedBufState
local function init_state(parent_bufnr, bufname, root_dir)
	return {
		bufname = bufname,
		parent_bufnr = parent_bufnr,
		root_dir = root_dir,
		proj_html_bufnr = nil,
		proj_html_vers = 0,
		proj_html_line_ending = "\r\n",
		proj_cs_bufnr = nil,
		proj_cs_vers = nil,
		proj_cs_line_ending = "\r\n",
	}
end

---@param state ProjectedBufState
local function create_proj_buffers(state)
	-- Create a buffer if its not created
	if not state.proj_html_bufnr then
		state.proj_html_bufnr = api.nvim_create_buf(true, true)

		debug.log_message("html proj buffer id: " .. state.proj_html_bufnr)
	end

	-- Set the filetypes
	api.nvim_set_option_value("filetype", "html", { buf = state.proj_html_bufnr })
	-- Set the buffer name
	api.nvim_buf_set_name(state.proj_html_bufnr, state.proj_html_bufname)
	-- Set the fileencoding to the same as the parent
	api.nvim_set_option_value(
		"fileencoding",
		api.nvim_get_option_value("fileencoding", { buf = state.parent_bufnr }),
		{ buf = state.proj_html_bufnr }
	)
end

---@param parent_bufnr integer
---@param bufname string
---@param root_dir string?
---@param handlers table
function M.register(parent_bufnr, bufname, root_dir, handlers)
	if registry[parent_bufnr] then
		return
	end
	debug.log_message("Register bufnr: " .. parent_bufnr .. " root_dir: " .. root_dir)

	local state = init_state(parent_bufnr, bufname, root_dir)
	create_proj_buffers(state)
	util.attach_lsps(state, handlers)
	registry[parent_bufnr] = state
	registry_bufname[bufname] = state
end

---@param bufnr integer
function M.unregister(bufnr)
	local state = registry[bufnr]
	if not state then
		return
	end

	registry_bufname[state.bufname] = nil
	registry[bufnr] = nil
end

---@return ProjectedBufState
function M.get_by_id(bufnr)
	return registry[bufnr]
end

---@return ProjectedBufState
function M.get_by_name(bufname)
	return registry_bufname[bufname]
end

---@param child_bufnr integer
---@return integer?
function M.get_parent_bufnr(child_bufnr)
	debug.log_message("Get parent bufnr for child: " .. child_bufnr)
	for parent_bufnr, registry_entry in pairs(registry) do
		if registry_entry.proj_html_bufnr == child_bufnr or registry_entry.proj_cs_bufnr == child_bufnr then
			return parent_bufnr
		end
	end
	return nil
end

---@param bufnr integer
function M.reset_projected_state(bufnr)
	if not registry[bufnr] then
		debug.err_message("Unable to reset state for bufnr: " .. bufnr)
		return
	end
	api.nvim_buf_set_lines(registry[bufnr].proj_html_bufnr, 0, -1, false, {})
	registry[bufnr].proj_html_vers = 0
	registry[bufnr].proj_cs_vers = 0
end

--

-- TODO: handle buf rename in the registry - this should be attached to an autocommand

return M
