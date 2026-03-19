vim.g.mapleader = " "

vim.env.FZF_DEFAULT_COMMAND =
"fd --type f --hidden --follow --exclude .git --exclude '*bazel-*' . $(git rev-parse --show-toplevel 2>/dev/null || echo .)"

require("jay.lazy")
require("jay.remap")
require("jay.set")
require("jay.theme")

vim.opt.wildignore = {
    '*/tmp/*',
    '*.so',
    '*.swp',
    '*.zip',
    '*/node_modules/*',
    '*/dist/*',
    '*bazel*',
}

-- Set custom statusline
vim.o.statusline = "%f %h%m%r%=%-14.(%l,%c%V%) %P"

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "c", "h" },
    callback = function()
        vim.bo.tabstop = 4
        vim.bo.shiftwidth = 4
        vim.bo.softtabstop = 4
        vim.bo.expandtab = true
    end,
})
