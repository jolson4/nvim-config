---
-- LSP configuration
---
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- Configure LSP popup window borders
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
    border = "rounded",
    max_width = 80,
    max_height = 30,
})

-- Override floating preview to add padding and rounded borders
local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = opts.border or "rounded"

    -- Add vertical padding (~10px = 2 lines top/bottom)
    -- Note: horizontal padding breaks markdown code fence rendering
    local padded_contents = { "", "" } -- top padding

    for _, line in ipairs(contents) do
        table.insert(padded_contents, line)
    end

    -- bottom padding
    table.insert(padded_contents, "")
    table.insert(padded_contents, "")

    return orig_util_open_floating_preview(padded_contents, syntax, opts, ...)
end

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
    border = "rounded",
    max_width = 80,
    max_height = 30,
})

-- Configure diagnostic popups with borders
vim.diagnostic.config({
    float = {
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
    },
})

local lsp_attach = function(client, bufnr)
    local opts = { buffer = bufnr }

    local function show_references_excluding_specs()
        vim.lsp.buf.references(nil, {
            on_list = function(ref_opts)
                local items = vim.tbl_filter(function(item)
                    local filename = item.filename or ""
                    return not filename:match("[/\\]spec[/\\]") and not filename:match("%.spec%.[^/\\]+$")
                end, ref_opts.items or {})

                if vim.tbl_isempty(items) then
                    vim.notify('No non-spec references found', vim.log.levels.INFO)
                    return
                end

                vim.fn.setqflist({}, ' ', {
                    title = ref_opts.title or 'References',
                    items = items,
                })
                vim.cmd('copen')
            end,
        })
    end

    vim.keymap.set('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
    vim.keymap.set('n', 'gd', function()
        local params = vim.lsp.util.make_position_params(0, client.offset_encoding)

        vim.lsp.buf_request_all(bufnr, 'textDocument/definition', params, function(results)
            local locations = {}

            for client_id, response in pairs(results or {}) do
                local result = response.result
                local response_client = vim.lsp.get_client_by_id(client_id)
                local offset_encoding = response_client and response_client.offset_encoding or client.offset_encoding

                if result then
                    if not vim.islist(result) then
                        result = { result }
                    end

                    for _, location in ipairs(result) do
                        local uri = location.uri or location.targetUri
                        local range = location.range or location.targetSelectionRange

                        if uri and range then
                            local filename = vim.uri_to_fname(uri)
                            table.insert(locations, {
                                filename = filename,
                                location = {
                                    uri = uri,
                                    range = range,
                                },
                                offset_encoding = offset_encoding,
                            })
                        end
                    end
                end
            end

            if vim.tbl_isempty(locations) then
                vim.notify('No definition found', vim.log.levels.INFO)
                return
            end

            local seen = {}
            local deduped_locations = {}
            for _, item in ipairs(locations) do
                local start = item.location.range.start
                local key = table.concat({ item.filename, start.line, start.character }, ':')
                if not seen[key] then
                    seen[key] = true
                    table.insert(deduped_locations, item)
                end
            end

            table.sort(deduped_locations, function(a, b)
                local function score(item)
                    local score = 0
                    if item.filename:match('/node_modules/') then
                        score = score - 100
                    end
                    if item.filename:match('%.d%.ts$') then
                        score = score - 50
                    end
                    if item.filename:match('[/\\]react[/\\]') or item.filename:match('[@]types[/\\]react') then
                        score = score - 25
                    end
                    if item.filename:sub(1, #vim.loop.cwd()) == vim.loop.cwd() then
                        score = score + 10
                    end
                    return score
                end

                local score_a = score(a)
                local score_b = score(b)
                if score_a == score_b then
                    return a.filename < b.filename
                end
                return score_a > score_b
            end)

            vim.lsp.util.jump_to_location(deduped_locations[1].location, deduped_locations[1].offset_encoding, true)

            if #deduped_locations > 1 then
                vim.notify('Jumped to preferred definition', vim.log.levels.INFO)
            end
        end)
    end, opts)
    vim.keymap.set('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
    vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
    vim.keymap.set('n', 'go', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
    vim.keymap.set('n', 'gr', show_references_excluding_specs, opts)
    vim.keymap.set('n', 'gs', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
    vim.keymap.set('n', '<F2>', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
    vim.keymap.set({ 'n', 'x' }, '<leader>for', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', opts)
    vim.keymap.set('n', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)
end



-- Configure LSP signs
local signs = { Error = "󰅚 ", Warn = "󰀪 ", Hint = "󰌶 ", Info = " " }
for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

-- C/C++
vim.lsp.config('clangd', {
    capabilities = capabilities,
    on_attach = lsp_attach,
})

-- Python
vim.lsp.config('pyright', {
    capabilities = capabilities,
    on_attach = lsp_attach,
})

-- HTML
vim.lsp.config('html', {
    capabilities = capabilities,
    on_attach = lsp_attach,
})

-- Lua
vim.lsp.config('lua_ls', {
    capabilities = capabilities,
    on_attach = lsp_attach,
    settings = {
        Lua = {
            format = {
                enable = true,
            },
            diagnostics = {
                globals = { "vim" },
            },
        },
    },
})

-- GraphQL
vim.lsp.config('graphql', {
    capabilities = capabilities,
    on_attach = lsp_attach,
    filetypes = { "typescript" },
    root_dir = require("lspconfig.util").root_pattern(".graphqlrc*", "graphql.config.*", "package.json"),
})

-- TypeScript/JavaScript (using tsgo)
vim.lsp.config('tsgo', {
    capabilities = capabilities,
    on_attach = function(client, bufnr)
        client.server_capabilities.documentFormattingProvider = false
        lsp_attach(client, bufnr)
    end,
    cmd = { "tsgo", "--lsp", "--stdio" },
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    root_markers = { ".git", "tsconfig.json", "package.json" },
})

-- CSS
vim.lsp.config('cssls', {
    capabilities = capabilities,
    on_attach = lsp_attach,
    settings = {
        css = { validate = true },
        scss = { validate = true },
        less = { validate = true },
    },
})

-- Per chatgpt, enable diagnostics for debugging
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics, {
        -- Configure how you want diagnostics to be displayed, e.g., signs, virtual text, etc.
        virtual_text = true,      -- Show diagnostics as virtual text inline with code
        signs = true,             -- Display LSP signs in the sign column
        update_in_insert = false, -- Avoid showing diagnostics while typing
        underline = true,         -- Underline error/warning text
        severity_sort = true,     -- Sort diagnostics by severity
    }
)

-- Enable all configured LSP servers
vim.lsp.enable('clangd')
vim.lsp.enable('pyright')
vim.lsp.enable('html')
vim.lsp.enable('lua_ls')
vim.lsp.enable('graphql')
vim.lsp.enable('tsgo')
vim.lsp.enable('cssls')
