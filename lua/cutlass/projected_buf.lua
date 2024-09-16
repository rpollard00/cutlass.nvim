local debug = require("cutlass.debug")
local api = vim.api
local lsp = vim.lsp
M = {}

-- need to be able to clear the buffer
-- need to be able to fully replace the buffer content
-- edit a given position
-- take a list of positions(spans) and content and replace that span with the new content
-- need to figure out how the versioning works and bump it when necessary idk

---@class ProjectedBufState
---@field parent_bufnr integer
---@field root_dir string?
---@field proj_html_bufnr integer?
---@field proj_cs_bufnr integer?

---@param parent_bufnr integer
---@param root_dir string?
---@return ProjectedBufState
function M.init_state(parent_bufnr, root_dir)
	return {
		parent_bufnr = parent_bufnr,
		root_dir = root_dir,
		proj_html_bufnr = nil,
		proj_cs_bufnr = nil,
	}
end

---Determine filetype and attach any LSPs
---@param state ProjectedBufState
function M.attach_lsps(state)
	debug.log_message("outer attach lsps")
	---@param buf integer
	---@param root_dir string?
	local function attach_lsp_clients(buf, root_dir)
		debug.log_message("invoke attach lsp clients on " .. buf .. " root_dir: " .. root_dir)
		local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })

		for _, client in ipairs(lsp.get_clients()) do
			debug.log_message("Iterate lsp clients")
			if client.config then
				debug.log_message("Client config exists")
				if client.get_language_id(buf, filetype) then
					debug.log_message("Inner attach_lsp_clients buf_attach_client")
					vim.lsp.buf_attach_client(buf, client.id)
				end
			end
		end
	end

	attach_lsp_clients(state.proj_html_bufnr, state.root_dir)
end

---@param state ProjectedBufState
---@param html_lsp_config vim.lsp.ClientConfig
---@param csharp_lsp_config vim.lsp.ClientConfig
function M.attach_lsps_alt(state, html_lsp_config, csharp_lsp_config)
	--- Attach LSP client to the buffer manually if not attached
	---@param buf integer
	---@param lsp_config vim.lsp.ClientConfig
	local function attach_lsp_clients(buf, lsp_config)
		debug.log_message("attach lsp clients bufnr: " .. buf)

		-- Iterate over all available LSPs for the current buffer
		local clients = vim.lsp.get_clients({ bufnr = buf })

		if #clients == 0 then
			debug.log_message("Manually starting LSP for buffer: " .. buf)
			-- reference to the real buffer
			local real_buf = api.nvim_get_current_buf()
			-- we need to set the active buffer to the projected buffer and then start the lsp
			api.nvim_set_current_buf(buf)
			vim.lsp.start(lsp_config)
			api.nvim_set_current_buf(real_buf)
		else
			-- Clients already attached, log them
			for _, client in ipairs(clients) do
				debug.log_message("LSP client already attached: " .. client.name)
			end
		end
	end

	-- Use the root_dir from the parent buffer or fallback to the working directory
	state.root_dir = vim.fn.getcwd(vim.fn.bufwinid(state.parent_bufnr)) or state.root_dir

	-- Attach LSPs to the HTML projected buffer
	attach_lsp_clients(state.proj_html_bufnr, html_lsp_config)
end

---@param state ProjectedBufState
function M.create_proj_buffers(state)
	-- Create a buffer if its not created
	if not state.proj_html_bufnr then
		state.proj_html_bufnr = api.nvim_create_buf(true, true)
		debug.log_message("html proj buffer id: " .. state.proj_html_bufnr)
	end

	-- Set the filetypes
	api.nvim_set_option_value("filetype", "html", { buf = state.proj_html_bufnr })
end

-- export interface IProjectedDocument {
--     readonly path: string;
--     readonly uri: vscode.Uri;
--     readonly hostDocumentSyncVersion: number | null;
--     readonly length: number;
--     getContent(): string;
-- }

return M
