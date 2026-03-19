-- Go to file tree
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- Move highlighted lines up and down
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Keep cursor in the middle when using ctrl d and u
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- Keep cursor in the middle when searching
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Preserve buffer after pasting
vim.keymap.set("x", "<leader>p", "\"_dP")

-- Apparently you never want to use Q
vim.keymap.set("n", "Q", "<nop>")

-- Easily copy to real clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])

-- Use tmux to easily jump between projects
vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")

-- Replace current word
vim.keymap.set("v", "<leader>sr", function()
    vim.cmd([[normal! "zy]])
    local search = vim.fn.escape(vim.fn.getreg("z"), [[\/]])
    local cmd = string.format([[:%%s/\V%s/%s/gI]], search, search)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(cmd, true, false, true), 'c', true)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Left><Left><Left>', true, false, true), 'n', true)
end, { desc = "Substitute selected text", silent = true })

-- Make panes equal width
vim.keymap.set("n", "<leader>eq", "<C-w>=")

-- See history of recent files
vim.keymap.set("n", "<leader>h", [[:History<CR>]])

-- Ignore case with fzf
vim.env.FZF_DEFAULT_OPTS = "--ignore-case"

-- Keybindings for FZF commands
vim.keymap.set('n', '<leader>ff', '<cmd>Files<CR>', { silent = true })


-- Map <leader>fg to run exact search with the word under the cursor.
vim.keymap.set(
    "n",
    "<leader>fg",
    ":RgExactExcludingTests <C-R>=expand('<cword>')<CR><CR>",
    { silent = true }
)

-- Search for text, project-wide, with regex
vim.keymap.set("n", "<leader>fir", "<cmd>Rg<CR>", { silent = true })

-- Search for text, project-wide, without regex, with tests included
vim.keymap.set("n", "<leader>fit", "<cmd>RgIgnoreCaseFixedStrings<CR>", { silent = true })

-- Search for text, project-wide, without regex, with tests excluded
vim.keymap.set("n", "<leader>fif", "<cmd>RgIgnoreCaseFixedStringsExcludingTests<CR>", { silent = true })

-- Search for files that import the current file
vim.keymap.set("n", "<leader>imp", function()
    local filepath = vim.api.nvim_buf_get_name(0)
    local relative_path = vim.fn.fnamemodify(filepath, ":.")

    -- Remove leading "asana2/" if present
    relative_path = relative_path:gsub("^asana2/", "")

    -- Remove file extension
    relative_path = relative_path:gsub("%.[^.]+$", "")

    -- Construct search pattern and execute with fixed string search
    local search_pattern = relative_path .. '";'
    vim.fn.feedkeys(":RgIgnoreCaseFixedStringsExcludingTests " .. search_pattern .. "\n", "n")
end, { desc = "Find imports of current file", silent = true })

-- Source config init.lua file
vim.keymap.set("n", "<leader>so", "<cmd>luafile ~/.config/nvim/init.lua<CR>", { silent = true })

-- See full error message
vim.keymap.set(
    "n",
    "<leader>e",
    vim.diagnostic.open_float,
    { silent = true }
)

-- Add tab
vim.keymap.set('n', '<leader>ta', ':tabnew<CR>', { silent = true })

-- Use tab and shift-tab to move between tabs
vim.keymap.set('n', '<leader>tp', ':tabp<CR>', { silent = true })
vim.keymap.set('n', '<leader>tn', ':tabn<CR>', { silent = true })

-- Zen mode
vim.keymap.set('n', '<leader>z', ':ZenMode<CR>', { silent = true })

-- Copy entire file's contents to clipboard
vim.keymap.set("n", "<leader>Y", [[gg"+yG]])

-- Paste from clipboard, replacing entire file's contents
vim.keymap.set("n", "<leader>R", [[gg"_dG"+p]])

-- Show man page for word under cursor in floating window
vim.keymap.set("n", "<leader>m", function()
    local word = vim.fn.expand("<cword>")
    local output = vim.fn.systemlist("man " .. vim.fn.shellescape(word) .. " 2>/dev/null | col -bx")
    if vim.v.shell_error ~= 0 then
        vim.notify("No man page for: " .. word, vim.log.levels.WARN)
        return
    end
    while #output > 0 and output[1] == "" do
        table.remove(output, 1)
    end
    vim.lsp.util.open_floating_preview(output, "man", {
        border = "rounded",
        max_width = 80,
        max_height = 40,
        focus_id = "man_page",
    })
end, { desc = "Show man page for word under cursor", silent = true })
