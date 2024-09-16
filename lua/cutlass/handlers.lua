--- Licensed under Apache 2.0
--- Taken from neovim github.com/neovim/neovim
--- Modified by Reese Pollard rpollard@gmail.com
local debug = require("cutlass.debug")
local err_message = debug.err_message
local M = {}
---
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

local workspace_configuration_handler = function(_, result, ctx)
	debug.log_message("workspace/configuration fired")
	local client_id = ctx.client_id
	local client = vim.lsp.get_client_by_id(client_id)
	if not client then
		err_message("LSP[", client_id, "] client has shut down after sending a workspace/configuration request")
		return
	end
	if not result.items then
		return {}
	end

	local response = {}
	for _, item in ipairs(result.items) do
		if item.section then
			local value = lookup_section(client.settings, item.section)
			-- For empty sections with no explicit '' key, return settings as is
			if value == nil and item.section == "" then
				value = client.settings
			end
			if value == nil then
				value = vim.NIL
			end
			table.insert(response, value)
		end
	end
	return response
end

--- format
---
-- {
-- changes = { {
--     newText = "/*~~*/ /*~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~~~*/\r\n/*~~*/ /*~~~~~~*/\r\n/*~~*/ /*~~~~~~~~~~~~~*/\r\n\r\n<Router AppAssembly=\"/*~~~~~~~~~~~~~~~~~*/\">\r\n<Found></Found>\r\n    <Found Context=\"routeData\">\r\n        <RouteView RouteData=\"/*~~~~~~*/\" DefaultLayout=\"/*~~~~~~~~~~~~~~~*/\" />\r\n        <FocusOnNavigate RouteData=\"/*~~~~~~*/\" Selector=\"h1\" />\r\n    </Found>\r\n    <NotFound>\r\n        <PageTitle>Not found</PageTitle>\r\n        <LayoutView Layout=\"/*~~~~~~~~~~~~~~~*/\">\r\n            <p role=\"alert\">Sorry, there's nothing at this address.</p>\r\n        </LayoutView>\r\n    </NotFound>\r\n</Router>\r\n<Taco>\r\n</Taco>\r\n<p>Cool html tags</p>\r\n\r\n/*~*/ ~\r\n    /*~~~~~~~~~~~~~~~~~~~*/ ~~ /**/ /*~~~~~~~*/\r\n~\r\n",
--     span = {
--       length = 0,
--       start = 0
--     }
--   } },
-- hostDocumentFilePath = "/Users/reesepollard/projects/dotnet/BlazorOmni/App.razor",
-- hostDocumentVersion = 3,
-- previousWasEmpty = true,
-- projectKeyId = "/var/folders/h3/h02bv04d1759kh51qznnql3h0000gn/T/d7291030b0ed48f4975ac46ecb65b0eb/__MISC_RAZOR_PROJECT__/"
-- }
-- sig for handlers is function(err, result, ctx, config)
local razor_update_html_buffer_handler = function(err, result, ctx, config)
	debug.log_message("razor/updateHtmlBuffer fired")
	-- boils down to find the parent buffer by hostDocumentFilePath in the registry
	-- get a reference to the projected html buffer
	-- then iterate over changes
	-- use the span data to find where to write to the buffer and how much of the buffer it should overwrite
	--
	debug.log_message(vim.inspect(result))

	local response = {}

	return response
end

local razor_update_csharp_buffer_handler = function(err, result, ctx, config)
	debug.log_message("razor/updateHtmlBuffer fired")
	local response = {}

	return response
end

M.workspace_configuration_handler = workspace_configuration_handler
M.razor_update_html_buffer_handler = razor_update_html_buffer_handler
M.razor_update_csharp_buffer_handler = razor_update_csharp_buffer_handler

return M
