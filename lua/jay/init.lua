vim.g.mapleader = " "

vim.env.FZF_DEFAULT_COMMAND =
"fd --type f --hidden --follow --exclude .git --exclude '*bazel-*' . $(git rev-parse --show-toplevel 2>/dev/null || echo .)"

require("jay.lazy")
require("jay.remap")
require("jay.set")
require("jay.theme")
require("jay.statusline").setup()

vim.opt.wildignore = {
    '*/tmp/*',
    '*.so',
    '*.swp',
    '*.zip',
    '*/node_modules/*',
    '*/dist/*',
    '*bazel*',
}

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "c", "h" },
    callback = function()
        vim.bo.tabstop = 4
        vim.bo.shiftwidth = 4
        vim.bo.softtabstop = 4
        vim.bo.expandtab = true
    end,
})
