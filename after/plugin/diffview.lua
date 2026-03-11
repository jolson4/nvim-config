vim.keymap.set("n", "<leader>do", "<cmd>DiffviewOpen<CR>", { noremap = true, silent = true });
vim.keymap.set("n", "<leader>dc", "<cmd>DiffviewClose<CR>", { noremap = true, silent = true });

-- See branch changes
vim.keymap.set("n", "<leader>bd", "<cmd>DiffviewFileHistory<CR>", { noremap = true, silent = true });

-- See changes only for current buffer
vim.keymap.set("n", "<leader>bh", "<cmd>DiffviewFileHistory %<CR>", { noremap = true, silent = true });

-- See diff'd files between current branch and dev
vim.keymap.set("n", "<leader>dm", [[:DiffviewOpen dev..HEAD<CR>]])

-- See diff'd files between current branch and parent branch
vim.keymap.set('n', '<leader>gd', function()
    local parent = vim.fn.system('gt parent'):gsub('\n', '')
    vim.cmd('DiffviewOpen ' .. parent)
end, { noremap = true, silent = true })
