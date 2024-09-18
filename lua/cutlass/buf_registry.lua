local debug = require("cutlass.debug")
local proj_buf = require("cutlass.projected_buf")

local M = {}
local registry = {}
local registry_bufname = {}

---@param parent_bufnr integer
---@param bufname string
---@param root_dir string?
---@param html_lsp_config vim.lsp.ClientConfig
---@param csharp_lsp_config vim.lsp.ClientConfig
function M.register(parent_bufnr, bufname, root_dir, html_lsp_config, csharp_lsp_config)
	if registry[parent_bufnr] then
		return
	end
	debug.log_message("Register bufnr: " .. parent_bufnr .. " root_dir: " .. root_dir)

	local state = proj_buf.init_state(parent_bufnr, bufname, root_dir)
	proj_buf.create_proj_buffers(state)
	proj_buf.attach_lsps(state, html_lsp_config, csharp_lsp_config)
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

-- TODO: handle buf rename in the registry - this should be attached to an autocommand

return M
