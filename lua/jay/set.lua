vim.opt.guicursor = ""

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.scrolloff = 8
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

-- Disable automatic line breaking
vim.opt.textwidth = 0

-- Hide whitespace in git diffs
vim.opt.diffopt:append("iwhite")

-- Don't include `l` format option since it forces a line wrap
vim.opt.formatoptions = "jcroq"

-- Fold based on syntax
vim.opt.foldmethod = "syntax"
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true

-- Blinking cursor
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor"

-- Copy file's absolute path
vim.api.nvim_create_user_command("CopyAbsolutePath", function()
    local path = vim.fn.expand("%:p")
    vim.fn.setreg("+", path)
    vim.notify('Copied "' .. path .. '" to the clipboard!')
end, {})
vim.keymap.set("n", "<leader>cpa", ":CopyAbsolutePath<CR>", { noremap = true, silent = true })

-- Copy file's path, relative to project root
vim.api.nvim_create_user_command('CopyRelativePath', function()
    local path = vim.fn.expand('%:.')
    vim.fn.setreg('+', path)
    print('Copied relative path: ' .. path)
end, {})
vim.keymap.set("n", "<leader>cpr", ":CopyRelativePath<CR>", { noremap = true, silent = true })

-- Hide the 80-character column indicator
vim.opt.colorcolumn = ""

-- Open file in GitHub; got this from Claude
function OpenGitHubFile()
    local relative_path = vim.fn.expand('%:.')

    local url = string.format('https://github.com/tryretool/retool_development/blob/dev/%s',
        relative_path
    )
    -- DEBUG
    -- vim.notify("Debug: url = " .. url)

    vim.fn.system('open ' .. url)
end

vim.keymap.set('n', '<leader>gh', OpenGitHubFile, {})

-- Rename variable across files
vim.keymap.set("n", "<leader>r", vim.lsp.buf.rename, { noremap = true, silent = true })

-- Show errors in a floating window
local function show_output(title, lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.6)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local win_opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
        title = title,
        title_pos = "center",
    }

    vim.api.nvim_open_win(buf, true, win_opts)
end

-- Generate codegen files
vim.api.nvim_create_user_command("GenerateImports", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    local generated_dirs = {}
    for _, line in ipairs(lines) do
        local import_path = line:match('%s*from%s+"([^"]+)"')
        if import_path and import_path:match("/generated/") then
            local dir = import_path:match("^(.-)/generated/")
            if dir then
                generated_dirs["asana2/" .. dir] = true
            end
        end
    end

    local args = {}
    for dir, _ in pairs(generated_dirs) do
        table.insert(args, vim.fn.shellescape(dir))
    end

    if #args == 0 then
        print("No generated imports found.")
        return
    end

    local cmd = "z editors codegen " .. table.concat(args, " ")
    print("Running in floating terminal: " .. cmd)

    -- Create a new buffer & floating window
    local term_buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)
    vim.api.nvim_open_win(term_buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "rounded",
    })

    -- Open terminal and run command
    vim.fn.termopen(cmd)
    vim.cmd.startinsert()
end, { desc = "Generate codegen files in a floating terminal" })

-- Generate imports
vim.keymap.set("n", "<leader>gen", ":GenerateImports<CR>", { noremap = true, silent = true })

-- Make pane bigger or smaller
vim.keymap.set("n", "<C-w>>", "20<C-w>>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-w><", "20<C-w><", { noremap = true, silent = true })

-- Format file
vim.keymap.set("n", "<leader>f", function()
    require("conform").format({ async = true })
end, { desc = "Format buffer" })

-- Show all marks
vim.keymap.set("n", "<leader>ma", ":MarksListAll<CR>", { noremap = true, silent = true })

-- Clear marks
vim.keymap.set("n", "<leader>delmarks", ":delmarks A-Z0-9<CR>", { noremap = true, silent = true })

vim.cmd([[
  highlight DiffChange guibg=#334143 guifg=NONE gui=NONE
  highlight DiffText   guibg=#576f73 guifg=NONE gui=NONE
]])

-- Reload all buffers
vim.keymap.set("n", "<leader>re", function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.fn.buflisted(buf) == 1 then
            vim.api.nvim_buf_call(buf, function()
                vim.cmd("edit")
            end)
        end
    end
end, { desc = "Reload all open buffers" })

-- Directly open graphql_schema.graphql
vim.keymap.set("n", "<leader>gs", function()
    local path = vim.fn.expand(
        "/Users/jonathanolson/sandbox/asana/asana2/asana/data_model/generated/graphql_schema.graphql")
    if vim.fn.filereadable(path) == 1 then
        vim.cmd("edit " .. path)
    else
        print("File not found: " .. path)
    end
end, { desc = "Open GraphQL schema file" })

-- Focus popout
vim.keymap.set("n", "<leader>fp", function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= "" then
            vim.api.nvim_set_current_win(win)
            break
        end
    end
end, { desc = "Focus popup window" })

-- Paste at end of line
vim.keymap.set("n", "<leader>P", "A<Esc>p", { desc = "Paste at end of line" })

-- Open floating terminal
vim.keymap.set("n", "<leader>tt", ":Floaterminal<CR> A", { desc = "Open floating/popout terminal" })
