local M = {}
local rzls_log_name = "rzls_log.log"
local log_file_path = vim.fn.stdpath("cache") .. "/" .. rzls_log_name

local log_message = function(message)
	local log_file = io.open(log_file_path, "a")
	if log_file then
		log_file:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. message .. "\n")
		log_file:close()
	end
end

---@param base_handler function(err, result, ctx, config)
---@return function(err, result, ctx, config)
local debug_handler = function(base_handler)
	return function(err, result, ctx, config)
		log_message("Method called: " .. ctx.method)
		log_message("Params: " .. vim.inspect(ctx.params))
		log_message("Result: " .. vim.inspect(result))
		-- Call the original handler
		if base_handler then
			return base_handler(err, result, ctx, config)
		end
	end
end

---@param request function(method: string, params: table?, handler: (fun(err?: lsp.ResponseError, result: any, context: lsp.HandlerContext, config?: table):...unknown)?, bufnr: integer?)
---@return function(method: string, params: table?, handler: (fun(err?: lsp.ResponseError, result: any, context: lsp.HandlerContext, config?: table):...unknown)?, bufnr: integer?)
local debug_request = function(request)
	return function(method, params, handler, result, config)
		log_message("Request called")
		log_message("Method called: " .. method)
		log_message("Params: " .. vim.inspect(params))
		log_message("Result: " .. vim.inspect(result))

		if request then
			return request(method, params, handler, result, config)
		end
	end
end

local view_log = function()
	vim.cmd("edit" .. log_file_path)
end

M.log_message = log_message
M.debug_handler = debug_handler
M.debug_request = debug_request
M.view_log = view_log

return M
