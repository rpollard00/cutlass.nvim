local debug = require("cutlass.debug")
local registry = require("cutlass.buf_registry")
local api = vim.api
local buf_util = require("cutlass.buf_util")
local ms = require("vim.lsp.protocol").Methods
local validate = vim.validate
local M = {}

---@param method (string) LSP method name
---@param params (table|nil) Parameters to send to the server
---@param target_bufnr integer
---@param handler lsp.Handler? See |lsp-handler|. Follows |lsp-handler-resolution|
---
---@return table<integer, integer> client_request_ids Map of client-id:request-id pairs
---for all successful requests.
---@return function _cancel_all_requests Function which can be used to
local function request_proj_buf(method, params, target_bufnr, handler)
	validate({
		method = { method, "s" },
		handler = { handler, "f", true },
	})
	debug.log_message("request_proj_buf on bufnr: " .. target_bufnr)
	return vim.lsp.buf_request(target_bufnr, method, params, handler)
end

function M.hover()
	debug.log_message("invoke custom hover request")
	local params = buf_util.make_proj_position_params()
	local cs_params = buf_util.make_cs_position_params()
	debug.log_message("HTML Position params for hover action: " .. vim.inspect(params))
	debug.log_message("CS Position params for hover action: " .. vim.inspect(cs_params))
	local projected_bufnr = registry.get_by_id(api.nvim_get_current_buf()).proj_html_bufnr
	local projected_cs_bufnr = registry.get_by_id(api.nvim_get_current_buf()).proj_cs_bufnr

	if not projected_bufnr then
		debug.log_message("Projected html bufnr not instantiated")
		return
	end

	if not projected_cs_bufnr then
		debug.log_message("Projected cs bufnr not instantiated")
		return
	end
	request_proj_buf(ms.textDocument_hover, params, projected_bufnr)
	request_proj_buf(ms.textDocument_hover, cs_params, projected_cs_bufnr)
end

----------- NVIM CUSTOMIZED FUNCS BELOW ----------------
---
---@param bufnr integer
---@param mode "v"|"V"
---@return table {start={row,col}, end={row,col}} using (1, 0) indexing
local function range_from_selection(bufnr, mode)
	-- TODO: Use `vim.region()` instead https://github.com/neovim/neovim/pull/13896

	-- [bufnum, lnum, col, off]; both row and column 1-indexed
	local start = vim.fn.getpos("v")
	local end_ = vim.fn.getpos(".")
	local start_row = start[2]
	local start_col = start[3]
	local end_row = end_[2]
	local end_col = end_[3]

	-- A user can start visual selection at the end and move backwards
	-- Normalize the range to start < end
	if start_row == end_row and end_col < start_col then
		end_col, start_col = start_col, end_col
	elseif end_row < start_row then
		start_row, end_row = end_row, start_row
		start_col, end_col = end_col, start_col
	end
	if mode == "V" then
		start_col = 1
		local lines = api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, true)
		end_col = #lines[1]
	end
	return {
		["start"] = { start_row, start_col - 1 },
		["end"] = { end_row, end_col - 1 },
	}
end
------ Neovim even overrides its own methods to make things more usable, this is a private
--- method from vim.lsp.buf that code_action uses to aggregate multiple code_actions from multiple
--- lsps into one UI - i think we have to make it even grosser and make another layer of aggregation from the projected buffers
--- and razor
---@param results table<integer, vim.lsp.CodeActionResultEntry>
---@param opts? vim.lsp.buf.code_action.Opts
local function on_code_action_results(results, opts)
	debug.log_message("ON CODE ACTION RESULT: " .. vim.inspect(results))
	---@param a lsp.Command|lsp.CodeAction
	local function action_filter(a)
		-- filter by specified action kind
		if opts and opts.context and opts.context.only then
			if not a.kind then
				return false
			end
			local found = false
			for _, o in ipairs(opts.context.only) do
				-- action kinds are hierarchical with . as a separator: when requesting only 'type-annotate'
				-- this filter allows both 'type-annotate' and 'type-annotate.foo', for example
				if a.kind == o or vim.startswith(a.kind, o .. ".") then
					found = true
					break
				end
			end
			if not found then
				return false
			end
		end
		-- filter by user function
		if opts and opts.filter and not opts.filter(a) then
			return false
		end
		-- no filter removed this action
		return true
	end

	---@type {action: lsp.Command|lsp.CodeAction, ctx: lsp.HandlerContext}[]
	local actions = {}
	for _, result in pairs(results) do
		for _, action in pairs(result.result or {}) do
			if action_filter(action) then
				table.insert(actions, { action = action, ctx = result.ctx })
			end
		end
	end
	if #actions == 0 then
		vim.notify("No code actions available", vim.log.levels.INFO)
		return
	end

	---@param action lsp.Command|lsp.CodeAction
	---@param client vim.lsp.Client
	---@param ctx lsp.HandlerContext
	local function apply_action(input_action, client, input_ctx)
		-- TODO we need to take the action here and edit the position, then apply it in the parent bufnr

		debug.log_message("Apply action action " .. vim.inspect(input_action))
		debug.log_message("Apply action ctx " .. vim.inspect(input_ctx))

		local bufnr = input_ctx.bufnr
		local action = buf_util.hijack_cs_action(input_action, bufnr)
		local ctx = buf_util.hijack_cs_ctx(input_ctx)
		debug.log_message("Hijacked action" .. vim.inspect(action))
		debug.log_message("Hijacked context" .. vim.inspect(ctx))
		if action.edit then
			vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
		end
		local a_cmd = action.command
		if a_cmd then
			local command = type(a_cmd) == "table" and a_cmd or action
			client:_exec_cmd(command, ctx)
		end
	end

	---@param choice {action: lsp.Command|lsp.CodeAction, ctx: lsp.HandlerContext}
	local function on_user_choice(choice)
		if not choice then
			return
		end
		-- textDocument/codeAction can return either Command[] or CodeAction[]
		--
		-- CodeAction
		--  ...
		--  edit?: WorkspaceEdit    -- <- must be applied before command
		--  command?: Command
		--
		-- Command:
		--  title: string
		--  command: string
		--  arguments?: any[]
		--
		local client = assert(vim.lsp.get_client_by_id(choice.ctx.client_id))
		local action = choice.action
		local bufnr = assert(choice.ctx.bufnr, "Must have buffer number")

		local reg = client.dynamic_capabilities:get(ms.textDocument_codeAction, { bufnr = bufnr })

		local supports_resolve = vim.tbl_get(reg or {}, "registerOptions", "resolveProvider")
			or client.supports_method(ms.codeAction_resolve)

		if not action.edit and client and supports_resolve then
			client.request(ms.codeAction_resolve, action, function(err, resolved_action)
				if err then
					if action.command then
						apply_action(action, client, choice.ctx)
					else
						vim.notify(err.code .. ": " .. err.message, vim.log.levels.ERROR)
					end
				else
					apply_action(resolved_action, client, choice.ctx)
				end
			end, bufnr)
		else
			apply_action(action, client, choice.ctx)
		end
	end
	-- If options.apply is given, and there are just one remaining code action,
	-- apply it directly without querying the user.
	if opts and opts.apply and #actions == 1 then
		on_user_choice(actions[1])
		return
	end

	---@param item {action: lsp.Command|lsp.CodeAction}
	local function format_item(item)
		local title = item.action.title:gsub("\r\n", "\\r\\n")
		return title:gsub("\n", "\\n")
	end
	local select_opts = {
		prompt = "Code actions:",
		kind = "codeaction",
		format_item = format_item,
	}
	vim.ui.select(actions, select_opts, on_user_choice)
end
--- Selects a code action available at the current
--- cursor position.
---
---@param opts? vim.lsp.buf.code_action.Opts
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeAction
---@see vim.lsp.protocol.CodeActionTriggerKind
function M.code_action(opts)
	debug.log_message("CODE ACTION: " .. vim.inspect(opts))
	validate({ options = { opts, "t", true } })

	debug.log_message("CODE ACTION Validated")
	opts = opts or {}
	-- Detect old API call code_action(context) which should now be
	-- code_action({ context = context} )
	--- @diagnostic disable-next-line:undefined-field
	if opts.diagnostics or opts.only then
		opts = { options = opts }
	end
	local context = opts.context or {}
	if not context.triggerKind then
		context.triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked
	end
	if not context.diagnostics then
		local bufnr = registry.get_by_id(api.nvim_get_current_buf()).proj_cs_bufnr
		context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr)
		debug.log_message("context diagnostics: " .. vim.inspect(context.diagnostics))
	end
	local mode = api.nvim_get_mode().mode
	local bufnr = registry.get_by_id(api.nvim_get_current_buf()).proj_cs_bufnr
	local win = api.nvim_get_current_win()
	local clients = vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_codeAction })
	local remaining = #clients
	if remaining == 0 then
		if next(vim.lsp.get_clients({ bufnr = bufnr })) then
			vim.notify(vim.lsp._unsupported_method(ms.textDocument_codeAction), vim.log.levels.WARN)
		end
		return
	end
	---@type table<integer, vim.lsp.CodeActionResultEntry>
	local results = {}

	---@param err? lsp.ResponseError
	---@param result? (lsp.Command|lsp.CodeAction)[]
	---@param ctx lsp.HandlerContext
	local function on_result(err, result, ctx)
		results[ctx.client_id] = { error = err, result = result, ctx = ctx }
		remaining = remaining - 1
		if remaining == 0 then
			on_code_action_results(results, opts)
		end
	end

	for _, client in ipairs(clients) do
		---@type lsp.CodeActionParams
		local params
		if opts.range then
			assert(type(opts.range) == "table", "code_action range must be a table")
			local start = assert(opts.range.start, "range must have a `start` property")
			local end_ = assert(opts.range["end"], "range must have a `end` property")
			params = vim.lsp.util.make_given_range_params(start, end_, bufnr, client.offset_encoding)
		elseif mode == "v" or mode == "V" then
			-- TODO v mode position xlate
			local range = range_from_selection(bufnr, mode)
			params = vim.lsp.util.make_given_range_params(range.start, range["end"], bufnr, client.offset_encoding)
		else
			params = buf_util.make_range_params_cs(win, client.offset_encoding)
		end
		params.context = context
		debug.log_message("params in the codeAction loop: " .. vim.inspect(params))
		client.request(ms.textDocument_codeAction, params, on_result, bufnr)
	end
end

---

return M
