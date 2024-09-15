local debug = require("cutlass.debug")
local proj_buf = require("cutlass.projected_buf")

local M = {}
local registry = {}

---@param parent_bufnr integer
---@param root_dir string?
function M.register(parent_bufnr, root_dir)
	debug.log_message("Register bufnr: " .. parent_bufnr .. " root_dir: " .. root_dir)
	local state = proj_buf.init_state(parent_bufnr, root_dir)
	proj_buf.create_proj_buffers(state)
	proj_buf.attach_lsps_alt(state)
	registry[parent_bufnr] = state
end

---@param parent_bufnr integer
function M.unregister(parent_bufnr)
	registry[parent_bufnr] = nil
end

function M.get(bufnr)
	return registry[bufnr]
end

return M
