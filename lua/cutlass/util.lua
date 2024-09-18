local M = {}

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

local get_cutlass_client = function()
	local clients = vim.lsp.get_clients({ name = "cutlass" })

	if clients and clients[1] then
		return clients[1]
	end
end

M.lookup_section = lookup_section
M.get_cutlass_client = get_cutlass_client

return M
