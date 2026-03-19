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

-- Fold based on syntax by default
vim.opt.foldmethod = "syntax"
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    callback = function()
        vim.opt_local.foldmethod = "indent"
    end,
})

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

local function open_url(url)
    if vim.ui and vim.ui.open then
        vim.ui.open(url)
        return
    end

    local opener
    if vim.fn.has("macunix") == 1 then
        opener = "open"
    elseif vim.fn.has("win32") == 1 then
        vim.fn.jobstart({ "cmd.exe", "/c", "start", url }, { detach = true })
        return
    else
        opener = "xdg-open"
    end

    vim.fn.jobstart({ opener, url }, { detach = true })
end

vim.keymap.set('n', '<leader>gh', function()
    local relative_path = vim.fn.expand('%:.')
    local url = string.format('https://github.com/tryretool/retool_development/blob/dev/%s', relative_path)
    open_url(url)
end, {})

local function open_github_commit_from_buffer()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    for _, line in ipairs(lines) do
        local commit = line:match("Commit:%s*([0-9a-fA-F]+)")
        if commit and #commit >= 7 then
            local url = "https://github.com/tryretool/retool_development/commit/" .. commit
            open_url(url)
            vim.notify("Opened " .. url)
            return
        end
    end

    vim.notify("No commit hash found (expected 'Commit: <sha>')", vim.log.levels.WARN)
end

local function get_git_root(path)
    if vim.fs and vim.fs.root then
        return vim.fs.root(path, { ".git" })
    end

    local out = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return out[1]
end

local function open_github_commit_for_cursor_line()
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
        vim.notify("No file path for current buffer", vim.log.levels.WARN)
        return
    end

    local abs = vim.fn.fnamemodify(file, ":p")
    local root = get_git_root(abs)
    if not root or root == "" then
        vim.notify("Not in a git repo (can't blame)", vim.log.levels.WARN)
        return
    end

    root = root:gsub("/$", "")
    local rel = abs
    if abs:sub(1, #root + 1) == root .. "/" then
        rel = abs:sub(#root + 2)
    end

    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local out = vim.fn.systemlist({ "git", "-C", root, "blame", "-L", string.format("%d,%d", lnum, lnum), "--porcelain",
        "--", rel })
    if vim.v.shell_error ~= 0 or not out or not out[1] then
        vim.notify("git blame failed for current line", vim.log.levels.WARN)
        return
    end

    local commit = out[1]:match("^([0-9a-fA-F]+)%s")
    if not commit or #commit < 7 then
        vim.notify("Couldn't parse commit from git blame output", vim.log.levels.WARN)
        return
    end

    if commit == string.rep("0", #commit) then
        vim.notify("Line not committed yet", vim.log.levels.WARN)
        return
    end

    local url = "https://github.com/tryretool/retool_development/commit/" .. commit
    open_url(url)
    vim.notify("Opened " .. url)
end

vim.keymap.set("n", "<leader>cm", open_github_commit_from_buffer, { desc = "Open commit on GitHub" })
vim.keymap.set("n", "<leader>gc", open_github_commit_for_cursor_line, { desc = "Open GitHub commit for line" })

-- Rename variable across files
vim.keymap.set("n", "<leader>r", vim.lsp.buf.rename, { noremap = true, silent = true })

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
vim.keymap.set("n", "<leader>gq", function()
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
