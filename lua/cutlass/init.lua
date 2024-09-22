local debug = require("cutlass.debug")
local find_root_project = require("cutlass.rootdir").find_root_project
local handlers = require("cutlass.handlers")
local proj_handlers = require("cutlass.proj_handlers")
local buf_registry = require("cutlass.buf_registry")
local requests = require("cutlass.requests")
local roslyn = require("roslyn")

local M = {}

-- does it make sense to hold a reference to the client
local rzls_path
M.patterns = { "*.razor", "*.csproj", "*.cshtml", "*.sln" }
local on_attach = function(_, bufnr)
	debug.log_message("THE ON ATTACH INVOKED for bufnr " .. bufnr)
	local nmap = function(keys, func, desc)
		if desc then
			desc = "LSP: " .. desc
		end
		vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
	end

	local imap = function(keys, func, desc)
		if desc then
			desc = "LSP: " .. desc
		end
		vim.keymap.set("i", keys, func, { buffer = bufnr, desc = desc })
	end

	nmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
	nmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
	nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
	nmap("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
	nmap("gI", vim.lsp.buf.implementation, "[G]oto [I]mplementation")
	nmap("<leader>D", vim.lsp.buf.type_definition, "Type [D]efinition")
	nmap("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
	nmap("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
	imap("<C-sw>", "<cmd>lua vim.lsp.buf.hover()<CR>", "Dont know what this does")
	nmap("K", requests.hover, "Custom Hover Documentation")
	nmap("<C-i>", vim.lsp.buf.signature_help, "Signature Documentation")
end

-- things to make configurable
local default_config = {
	log_level = "trace",
	-- the wrapper redirects the custom compiled rzls with stderr jsonrpc output to a log file
	rzls_path = "/Users/reesepollard/projects/neovim/plugins/cutlass.nvim/debug/rzls_wrapper.sh",
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
	roslyn.setup({
		ft = "cs",
		opts = {
			config = {
				settings = {
					["csharp|inlay_hints"] = {
						csharp_enable_inlay_hints_for_implicit_object_creation = true,
						csharp_enable_inlay_hints_for_implicit_variable_types = true,
						csharp_enable_inlay_hints_for_lambda_parameter_types = true,
						csharp_enable_inlay_hints_for_types = true,
						dotnet_enable_inlay_hints_for_indexer_parameters = true,
						dotnet_enable_inlay_hints_for_literal_parameters = true,
						dotnet_enable_inlay_hints_for_object_creation_parameters = true,
						dotnet_enable_inlay_hints_for_other_parameters = true,
						dotnet_enable_inlay_hints_for_parameters = true,
						dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
						dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
						dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
					},
					["csharp|code_lens"] = {
						dotnet_enable_references_code_lens = true,
					},
					["csharp|background_analysis"] = {
						dotnet_analyzer_diagnostics_scope = "fullSolution",
						dotnet_compiler_diagnostics_scope = "fullSolution",
					},
				},
			},
		},
	})

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
		on_attach = on_attach,
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
	buf_registry.register(bufnr, bufname, config.root_dir, proj_handlers.handlers)

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
