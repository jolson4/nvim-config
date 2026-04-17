---
-- LSP configuration
---
local capabilities = require('cmp_nvim_lsp').default_capabilities()

local function markdownify_hover(result, bufnr)
    if not (result and result.contents) then
        return result
    end

    local ft = vim.bo[bufnr].filetype
    local hover_filetypes = {
        javascript = true,
        javascriptreact = true,
        typescript = true,
        typescriptreact = true,
    }

    if not hover_filetypes[ft] then
        return result
    end

    local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    if vim.tbl_isempty(lines) then
        return result
    end

    for _, line in ipairs(lines) do
        if line:match('^```') then
            return result
        end
    end

    local signature_lines = {}
    local docs_start

    for i, line in ipairs(lines) do
        if line == '' then
            docs_start = i + 1
            break
        end
        table.insert(signature_lines, line)
    end

    if vim.tbl_isempty(signature_lines) then
        return result
    end

    local markdown_lines = { '```' .. ft }
    vim.list_extend(markdown_lines, signature_lines)
    table.insert(markdown_lines, '```')

    if docs_start and docs_start <= #lines then
        table.insert(markdown_lines, '')
        vim.list_extend(markdown_lines, vim.list_slice(lines, docs_start))
    end

    return {
        contents = {
            kind = 'markdown',
            value = table.concat(markdown_lines, '\n'),
        },
    }
end

local function extract_single_fenced_block(result, bufnr)
    if not (result and result.contents) then
        return nil
    end

    local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    if vim.tbl_isempty(lines) or #lines < 3 then
        return nil
    end

    local first = lines[1]
    local last = lines[#lines]
    local lang = first:match('^```%s*([%w_+-]+)%s*$')
    if not lang or last ~= '```' then
        return nil
    end

    for i = 2, #lines - 1 do
        if lines[i]:match('^```') then
            return nil
        end
    end

    local syntax_map = {
        ts = 'typescript',
        tsx = 'typescriptreact',
        typescript = 'typescript',
        typescriptreact = 'typescriptreact',
        js = 'javascript',
        jsx = 'javascriptreact',
        javascript = 'javascript',
        javascriptreact = 'javascriptreact',
    }

    local syntax = syntax_map[lang] or vim.bo[bufnr].filetype
    return {
        contents = vim.list_slice(lines, 2, #lines - 1),
        syntax = syntax,
    }
end

local last_hover_debug = nil

local function show_hover(client)
    return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local params = vim.lsp.util.make_position_params(0, client and client.offset_encoding)
    local config = {
        border = 'rounded',
        max_width = 80,
        max_height = 30,
        focus_id = 'textDocument/hover',
    }

        vim.lsp.buf_request(bufnr, 'textDocument/hover', params, function(err, result, ctx)
            if err then
                vim.notify(err.message or 'Hover request failed', vim.log.levels.ERROR)
                return
            end

            if vim.api.nvim_get_current_buf() ~= bufnr then
                return
            end

            if not (result and result.contents) then
                vim.notify('No information available')
                return
            end

            local fenced_block = extract_single_fenced_block(result, bufnr)
            if fenced_block then
                local float_buf, float_win = vim.lsp.util.open_floating_preview(fenced_block.contents, fenced_block.syntax, config)
                vim.bo[float_buf].filetype = fenced_block.syntax
                last_hover_debug = {
                    mode = 'show_hover_fenced_block',
                    syntax = fenced_block.syntax,
                    filetype = vim.bo[float_buf].filetype,
                    contents = fenced_block.contents,
                    win = float_win,
                    buf = float_buf,
                }
                return
            end

            last_hover_debug = {
                mode = 'show_hover_native',
                result = result,
                transformed = markdownify_hover(result, bufnr),
            }
            vim.lsp.handlers.hover(err, markdownify_hover(result, bufnr), ctx, config)
        end)
    end
end

vim.api.nvim_create_user_command('LspHoverDebug', function()
    local params = vim.lsp.util.make_position_params()
    vim.lsp.buf_request(0, 'textDocument/hover', params, function(err, result, ctx)
        local path = vim.fn.stdpath('cache') .. '/lsp-hover-debug.lua'
        local payload = {
            err = err,
            result = result,
            bufnr = ctx and ctx.bufnr,
            filetype = vim.bo[0].filetype,
            transformed = markdownify_hover(result, vim.api.nvim_get_current_buf()),
        }

        vim.fn.writefile(vim.split(vim.inspect(payload), '\n', { plain = true }), path)
        vim.notify('Wrote hover debug to ' .. path)
    end)
end, {})

vim.api.nvim_create_user_command('LspFloatDebug', function()
    local floats = {}

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= '' then
            local buf = vim.api.nvim_win_get_buf(win)
            local entry = {
                win = win,
                buf = buf,
                relative = config.relative,
                filetype = vim.bo[buf].filetype,
                syntax = vim.bo[buf].syntax,
                lines = vim.api.nvim_buf_get_lines(buf, 0, math.min(5, vim.api.nvim_buf_line_count(buf)), false),
            }

            vim.api.nvim_win_call(win, function()
                entry.syn1 = vim.fn.synIDattr(vim.fn.synID(1, 1, 1), 'name')
                entry.syn7 = vim.fn.synIDattr(vim.fn.synID(1, 7, 1), 'name')
            end)

            table.insert(floats, entry)
        end
    end

    local path = vim.fn.stdpath('cache') .. '/lsp-float-debug.lua'
    local payload = {
        last_hover_debug = last_hover_debug,
        floats = floats,
    }

    vim.fn.writefile(vim.split(vim.inspect(payload), '\n', { plain = true }), path)
    vim.notify('Wrote float debug to ' .. path)
end, {})

-- Configure LSP popup window borders
vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
    config = vim.tbl_extend('force', {
        border = 'rounded',
        max_width = 80,
        max_height = 30,
    }, config or {})

    local fenced_block = extract_single_fenced_block(result, ctx.bufnr)
    if fenced_block then
        local float_buf, float_win = vim.lsp.util.open_floating_preview(fenced_block.contents, fenced_block.syntax, config)
        vim.bo[float_buf].filetype = fenced_block.syntax
        last_hover_debug = {
            mode = 'fenced_block',
            syntax = fenced_block.syntax,
            filetype = vim.bo[float_buf].filetype,
            contents = fenced_block.contents,
            win = float_win,
            buf = float_buf,
        }
        return float_buf, float_win
    end

    last_hover_debug = {
        mode = 'native_hover',
        result = result,
        transformed = markdownify_hover(result, ctx.bufnr),
    }
    return vim.lsp.handlers.hover(err, markdownify_hover(result, ctx.bufnr), ctx, config)
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

    vim.keymap.set('n', 'K', show_hover(client), opts)
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
