local debug = require("cutlass.debug")
local util = require("lspconfig.util")
local find_root_project = require("cutlass.rootdir").find_root_project

local M = {}

local rzls_path

local setup = function(opts)
	vim.lsp.set_log_level("trace")

	-- neovim doesn't recognize razor files by default
	vim.filetype.add({
		extension = {
			razor = "razor",
		},
	})

	if opts and opts.path then
		rzls_path = opts.path
	else
		rzls_path = vim.fn.expand("~/.local/share/nvim/rzls/rzls")
	end
end

--- @return integer?
local start_client = function()
	debug.log_message("Starting rzls lsp")

	local bufnr = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)

	debug.log_message("Current bufnr " .. bufnr .. " name: " .. bufname)
	--- @class vim.lsp.ClientConfig
	local client_config = {
		name = "cutlass",
		cmd = {
			rzls_path,
		},
		root_dir = find_root_project({ "*.sln", "*.csproj" }, bufname, 10),
		-- root_dir = vim.fn.getcwd(),
		offset_encoding = "utf-8",
		handlers = vim.lsp.handlers,
	}

	local client_id = vim.lsp.start_client(client_config)
	-- local client_id = vim.lsp.start(client_config)

	local client

	if client_id ~= nil then
		debug.log_message("Client_id: " .. client_id)
		client = vim.lsp.get_client_by_id(client_id)
	end

	-- early return if client can't be fetched
	if not client then
		return
	end

	-- wrap handlers with the debug handler
	-- if debug.debug_handler then
	-- 	debug.log_message("Will attempt to wrap handlers")
	-- 	for method, handler in pairs(client.handlers) do
	-- 		debug.log_message("Wrapping handler for method: " .. method)
	-- 		-- i want to take the existing default handler and wrap it in my debug handler (which will execute the default handler)
	-- 		client.handlers[method] = debug.debug_handler(handler)
	-- 	end
	-- end

	-- local base_request_handler = client.request
	-- if base_request_handler and debug.debug_request then
	-- 	debug.log_message("Attempt to wrap the base request handler")
	-- 	client.request = debug.debug_request(base_request_handler)
	-- end

	return client_id
end

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = "*.razor",
	callback = function()
		local client_id = start_client()
		if client_id then
			debug.log_message("rzls client attached to buffer. Client_id " .. client_id)
		else
			debug.log_message("failed to start rzls client")
		end
	end,
})

-- Optional: Add key mappings for LSP functionality

vim.api.nvim_create_autocmd("LspAttach", {
	pattern = "*.razor",
	callback = function(args)
		debug.log_message("Attempt rzls lsp attach")
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		local opts = { buffer = args.buf }
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
		-- Add more key mappings as needed
	end,
})

------- DEBUGGING COMMANDS TODO MOVE THIS STUFF ---------

M.debug = debug
M.log = debug.view_log
M.setup = setup

-- vim.api.nvim_create_user_command("RestartLsp", function()
-- 	vim.lsp.stop_client
-- end, {})
---------------------------------------------------------
return M
