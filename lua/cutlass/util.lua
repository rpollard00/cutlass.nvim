local debug = require("cutlass.debug")
local lspconfig = require("lspconfig")
local api = vim.api
local M = {}

---@param table   table e.g., { foo = { bar = "z" } }
---@param section string indicating the field of the table, e.g., "foo.bar"
---@return any|nil setting value read from the table, or `nil` not found
function M.lookup_section(table, section)
	if table[section] ~= nil then
		return table[section]
	end

	local keys = vim.split(section, ".", { plain = true }) --- @type string[]
	return vim.tbl_get(table, unpack(keys))
end

function M.get_cutlass_client()
	local clients = vim.lsp.get_clients({ name = "cutlass" })

	if clients and clients[1] then
		return clients[1]
	end
end

---
---@param state ProjectedBufState
function M.attach_lsps(state, handlers)
	--- Attach LSP client to the buffer manually if not attached
	---@param buf integer
	local function attach_lsp_clients(buf)
		debug.log_message("attach lsp clients bufnr: " .. buf)

		-- Iterate over all available LSPs for the current buffer
		local clients = vim.lsp.get_clients({ bufnr = buf })

		if #clients == 0 then
			debug.log_message("Manually starting LSP for buffer: " .. buf)
			-- reference to the real buffer
			local real_buf = api.nvim_get_current_buf()
			-- we need to set the active buffer to the projected buffer and then start the lsp
			if lspconfig["html"] then
				lspconfig.html.setup({
					handlers = vim.tbl_extend("force", vim.lsp.handlers, handlers),
				})
			end
			api.nvim_set_current_buf(buf)
			vim.lsp.start(lspconfig["html"])
			api.nvim_set_current_buf(real_buf)
		else
			-- Clients already attached, log them
			for _, client in ipairs(clients) do
				debug.log_message("LSP client already attached: " .. client.name)
			end
		end
	end

	-- Use the root_dir from the parent buffer or fallback to the working directory
	state.root_dir = state.root_dir

	-- Attach LSPs to the HTML projected buffer
	attach_lsp_clients(state.proj_html_bufnr)
end

return M
