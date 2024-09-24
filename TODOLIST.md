Current goal:
[X] Fix dependency loop
[X] Finish the POC that we can project the response to document/Hover from html to the real buffer
[X] CS Projected Document Support - Basic hooks wherever the html hooks are - Attach the roslyn lsp - May be workspace challenges idk
[ ] CS Projected Document request mapping and handler reverse mapping

## Subsystems

1. Config/Init System
   - Initialize and configure rzls
   - Entry point for all custom/user configuration
   - Provide sensible defaults when possible
   - Follow idioms of neovim plugins
2. Projected Buffer Management
   - Buffer registry
     - Create the projected buffers
     - Discovery and references between buffers
     - Lifecycle management of projected buffers
   - Projection functions that keep the projected buffers in sync with the main buffer
3. LSP request distribution
   - Custom implementation(s) of LSP client requests
   - Flow:
     1. Expected normal LSP requests
     2. Take positioning from main buffer
     3. Map to the appropriate position in the projected buffer (1:1 for html, #pragma mappings in cs)
     4. Send the request to the projected buffer's lsp(s)
        - Simplest approach would be to send the action to all the LSPs and then if they have anything useful, we reverse project that back
        - Alternative is to be discern what the appropriate projected buffer is and target the requests
   - Wrap existing LSP functions as much as possible
4. Handler Aggregation and Reverse Projection
   - Aggregates LSP responses and projects back to the concrete document
5. Handlers
   - Derive from builtin handlers as much as possible
   - Push all projected buffer handlers through the aggregation system
   - We may not need to push the rzls handlers through the aggregation system and instead interact directly
   - Concrete implementations of handler features

Two-Way Mapper

Request side ->
Build location in request function
Line/Column or span (V mode) - check on the format here
Translate line to find #line <num> <bufname>
Search from end back until you find line == num or the biggest line smaller than num
The difference between <num> and the found line is the offset for the actual position in the projected buf, i'm pretty sure, may be off by one here
For the col, just take that directly
Then send the lsp request with the given calculated position

Handler side ->
Its going to return the real position in the csharp document
Move up the document until we see a #line <num> <bufname>, while keeping track of the offset
line num + offset is the line in the real doc
column should be direct

#line 3 "/Users/reesepollard/projects/dotnet/BlazorOmni/App.razor"
using Microsoft.AspNetCore.Components.Forms;
