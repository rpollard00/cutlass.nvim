local debug = require("cutlass.debug")
local util = require("lspconfig.util")
local async = require("lspconfig.async")
local find_root_project = require("cutlass.rootdir").find_root_project
local handlers = require("cutlass.handlers")
local buf_registry = require("cutlass.buf_registry")
local lspconfig = require("lspconfig")

local M = {}

-- does it make sense to hold a reference to the client
local rzls_path
M.patterns = { "*.razor", "*.csproj", "*.cshtml", "*.sln" }
local html_lsp_config
local csharp_lsp_config

-- things to make configurable
local default_config = {
	log_level = "trace",
	-- the wrapper redirects the custom compiled rzls with stderr jsonrpc output to a log file
	rzls_path = "/Users/reesepollard/projects/neovim/plugins/cutlass.nvim/debug/rzls_wrapper.sh",
	html_lsp_config = (function()
		if lspconfig["html"] then
			return lspconfig["html"]
		end
		return nil
	end)(),
	csharp_lsp_config = (function()
		-- we will just try to get the config for roslyn as its the only thing i am going to test with
		local csharp_clients = vim.lsp.get_clients({ name = "roslyn" })
		for _, value in ipairs(csharp_clients) do
			if value.name == "roslyn" then
				return value.config
			end
		end
		return nil
	end)(),
}

local setup = function(user_config)
	local config = vim.tbl_deep_extend("force", default_config, user_config or {})
	vim.lsp.set_log_level(config.log_level)

	-- neovim doesn't recognize razor files by default
	vim.filetype.add({
		extension = {
			razor = "razor",
		},
	})

	rzls_path = vim.fn.expand(config.rzls_path)
	-- rzls_path = vim.fn.expand("~/.local/share/nvim/rzls/rzls")
	-- the wrapper redirects the custom compiled rzls with stderr jsonrpc output to a log file
	html_lsp_config = config.html_lsp_config
	csharp_lsp_config = config.csharp_lsp_config

	vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
		pattern = M.patterns,
		callback = M.attach_client,
	})
end

---@return vim.lsp.ClientConfig
local get_config = function(bufname)
	return {
		name = "cutlass",
		cmd = {
			rzls_path,
		},
		root_dir = find_root_project({ "*.sln", "*.csproj" }, bufname, 10),
		offset_encoding = "utf-16",
		settings = {
			-- the keys are now correct but the values are not
			razor = {
				format = {
					enable = true,
					codeBlockBraceOnNextLine = true,
				},
				completion = {
					commitElementsWithSpace = true,
				},
			},
			html = {
				autoClosingTags = false,
			},
			["vs.editor.razor"] = vim.empty_dict(),
			-- "file:///Users/reesepollard/projects/dotnet/BlazorOmni",
		},
		handlers = vim.tbl_extend("force", vim.lsp.handlers, {
			["workspace/configuration"] = handlers.workspace_configuration_handler,
			["razor/updateHtmlBuffer"] = handlers.razor_update_html_buffer_handler,
			["razor/updateCSharpBuffer"] = handlers.razor_update_csharp_buffer_handler,
		}),
	}
end

--- @return integer?
local get_or_init_client = function()
	debug.log_message("Starting rzls lsp")

	local bufnr = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)

	debug.log_message("Current bufnr " .. bufnr .. " name: " .. bufname)
	local already_has_attached_client = vim.lsp.get_clients({ name = "cutlass" })
	-- debug.log_message("Already attached client" .. vim.inspect(already_has_attached_client))

	local config = get_config(bufname)
	buf_registry.register(bufnr, bufname, config.root_dir, html_lsp_config, csharp_lsp_config)

	-- return if the client is already started and attached
	if already_has_attached_client and already_has_attached_client[1] then
		return already_has_attached_client[1].id
	end

	local client_id = vim.lsp.start_client(config)
	return client_id
end

-- Notify server about changes in configuration (dependencies)
local notify_did_change_configuration = function(client_id)
	local client = vim.lsp.get_client_by_id(client_id)

	if not client then
		debug.log_message("Unable to fetch client in notify_did_change_configuration")
		return
	end

	local result = client.notify("workspace/didChangeConfiguration", {})

	if not result then
		debug.log_message("Unable to send workspace/didChangeConfiguration successfully")
	end
end

M.get_or_init_client = get_or_init_client
local attach_client = function()
	local id = get_or_init_client()
	if not id then
		debug.log_message("Unable to attach buffer as client id is nil")
		return
	end
	local bufnr = vim.api.nvim_get_current_buf()

	local did_attach = vim.lsp.buf_is_attached(bufnr, id) or vim.lsp.buf_attach_client(bufnr, id)

	if not did_attach then
		debug.log_message("Failed to attach client " .. id .. " to buffer " .. bufnr)
		return
	end
end
M.attach_client = attach_client
--

-- Optional: Add key mappings for LSP functionality

------- DEBUGGING COMMANDS TODO MOVE THIS STUFF ---------

M.debug = debug
M.log = debug.view_log
M.setup = setup

---------------------------------------------------------
return M
