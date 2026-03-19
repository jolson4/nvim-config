-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out,                            "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
-- vim.g.maplocalleader = "\\"

local map = vim.keymap.set
local fn = vim.fn


-- Setup lazy.nvim
require("lazy").setup({
    -- automatically check for plugin updates
    checker = { enabled = true },
    { "nvim-lua/plenary.nvim" },
    { "nvim-telescope/telescope.nvim" },
      {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },

    config = function()
      require("nvim-treesitter.config").setup({
        ensure_installed = {
          "javascript",
          "typescript",
          "rust",
          "c",
          "lua",
          "vim",
          "vimdoc",
          "query",
          "markdown",
          "markdown_inline",
          "scala",
          "graphql",
          "html",
        },
        highlight = { enable = true },
        indent = { enable = true },
        auto_install = true,
      })
    end,
  },
    -- Icons for file explorer
    { "nvim-tree/nvim-web-devicons", opts = {} },
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" }
    },
    { "mbbill/undotree" },
    { "tpope/vim-fugitive" },
    {
        "hrsh7th/nvim-cmp",
        event = "InsertEnter",
        dependencies = {
            { "hrsh7th/cmp-nvim-lsp" },
            { "hrsh7th/cmp-vsnip" },
            { "hrsh7th/vim-vsnip" }
        },
        opts = function()
            local cmp = require("cmp")
            local conf = {
                sources = {
                    { name = "nvim_lsp" },
                    { name = "vsnip" },
                },
                snippet = {
                    expand = function(args)
                        -- Comes from vsnip
                        fn["vsnip#anonymous"](args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    -- None of this made sense to me when first looking into this since there
                    -- is no vim docs, but you can't have select = true here _unless_ you are
                    -- also using the snippet stuff. So keep in mind that if you remove
                    -- snippets you need to remove this select
                    ["<CR>"] = cmp.mapping.confirm({ select = true })
                })
            }
            return conf
        end
    },
    { "hrsh7th/cmp-nvim-lsp" },
    { "github/copilot.vim" },
    { "folke/todo-comments.nvim", opts = {} },
    {
        "folke/zen-mode.nvim",
        opts = {
            window = {
                width = 200,
            },
        }
    },

    -- Add gutter signs for git
    {
        "lewis6991/gitsigns.nvim",
        config = function()
            require('gitsigns').setup({
                signs = {
                    add          = { text = '│' },
                    change       = { text = '│' },
                    delete       = { text = '_' },
                    topdelete    = { text = '‾' },
                    changedelete = { text = '~' },
                }
            })
        end
    },

    -- Split view in git
    {
        "sindrets/diffview.nvim",
        requires = "nvim-lua/plenary.nvim",
        config = function()
            require('diffview').setup({
                enhanced_diff_hl = true,
                view = {
                    default = {
                        layout = "diff2_horizontal",
                        winbar_info = false,
                    },
                    merge_tool = {
                        layout = "diff3_mixed",
                        disable_diagnostics = true,
                        winbar_info = true,
                    },
                    file_history = {
                        layout = "diff2_horizontal",
                        winbar_info = false,
                    },
                },
                file_panel = {
                    listing_style = "list",
                    win_config = {
                        position = "left",
                        width = 60, -- Instead of width
                    },
                },
                signs = {
                    fold_closed = "",
                    fold_open = "",
                    done = "✓",
                },
                signs_placement = "left",
            })
        end
    },

    -- Git blame
    { "rhysd/git-messenger.vim" },

    -- Color Themes
    { "AlexvZyl/nordic.nvim" },
    { "catppuccin/nvim" },

    -- fzf for fast file search
    {
        {
            "junegunn/fzf",
            build = "./install --bin", -- Ensures the fzf binary is installed
        },
        {
            "junegunn/fzf.vim",
            dependencies = { "junegunn/fzf" },
            config = function()
                -- Function to determine project root
                local function get_project_root()
                    local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")
                    if vim.v.shell_error == 0 and #git_root > 0 then
                        return git_root[1]
                    else
                        return vim.fn.getcwd() -- Fallback to current working directory
                    end
                end

                -- Create a custom command 'RgExact' that takes arguments.
                vim.api.nvim_create_user_command("RgExactExcludingTests", function(opts)
                    local query = opts.args
                    if query == "" then
                        query = vim.fn.input("Rg (exact)> ")
                        if query == "" then return end
                    end

                    local root_dir = get_project_root()
                    local escaped_query = vim.fn.shellescape(query)
                    local escaped_root_dir = vim.fn.shellescape(root_dir)

                    local cmd = string.format(
                        "rg --fixed-strings --color=always --line-number --column --no-heading -P %s --glob '!**/*bazel*/**' --glob '!**/desktop/generated/**' --glob '!**/tmp/**' --glob '!node_modules' --glob '!**/*git*/**' --glob '!**/*3rdparty*/**' --glob '!**/*.tools*/**' --glob '!**/*demo_files*/**' --glob '!**/*-lock*/**' --glob '!**/*metals*/**' --glob '!**/*_test*' --glob '!**/*.json' %s",
                        escaped_query, escaped_root_dir
                    )

                    vim.fn["fzf#vim#grep"](cmd, 1, vim.fn["fzf#vim#with_preview"](), opts.bang and 1 or 0)
                end, {
                    nargs = "*",
                    bang = true,
                    desc = "Search with ripgrep in exact (literal) mode from project root",
                }
                )

                -- Search for string match with regex (FZF with Ctrl-Q to send to quickfix)
                vim.api.nvim_create_user_command("Rg", function(opts)
                    local query = opts.args
                    if query == "" then
                        query = vim.fn.input("Rg >")
                        if query == "" then return end
                    end

                    local root_dir = get_project_root()
                    local escaped_query = vim.fn.shellescape(query)
                    local escaped_root_dir = vim.fn.shellescape(root_dir)

                    local cmd = string.format(
                        "rg --color=always --line-number --column --no-heading %s --glob '!**/*bazel*/**' --glob '!**/desktop/generated/**' --glob '!**/tmp/**' --glob '!node_modules' --glob '!**/*git*/**' --glob '!**/*3rdparty*/**' --glob '!**/*.tools*/**' --glob '!**/*demo_files*/**' --glob '!**/*-lock*/**' --glob '!**/*metals*/**' %s",
                        escaped_query, escaped_root_dir
                    )

                    -- Add Ctrl-Q to send all results to quickfix using --expect
                    local spec = vim.fn["fzf#vim#with_preview"]()
                    spec.options = spec.options or {}
                    table.insert(spec.options, '--expect=ctrl-q')

                    -- Custom sink to handle quickfix population
                    spec['sink*'] = function(lines)
                        local key = table.remove(lines, 1)
                        if key == 'ctrl-q' then
                            -- Send all results to quickfix
                            local qf_cmd = string.format(
                                "rg --vimgrep %s --glob '!**/*bazel*/**' --glob '!**/desktop/generated/**' --glob '!**/tmp/**' --glob '!node_modules' --glob '!**/*git*/**' --glob '!**/*3rdparty*/**' --glob '!**/*.tools*/**' --glob '!**/*demo_files*/**' --glob '!**/*-lock*/**' --glob '!**/*metals*/**' %s",
                                escaped_query, escaped_root_dir
                            )
                            vim.fn.setqflist({}, 'r')
                            vim.cmd('cexpr system("' .. qf_cmd:gsub('"', '\\"') .. '")')
                            vim.cmd('copen')
                        elseif #lines > 0 then
                            -- Parse the first selected line and open the file
                            local line = lines[1]
                            if line then
                                -- Parse format: filename:line:column:content
                                local parts = vim.split(line, ':')
                                if #parts >= 3 then
                                    local file = parts[1]
                                    local lnum = parts[2]
                                    local col = parts[3]
                                    vim.cmd('edit ' .. vim.fn.fnameescape(file))
                                    vim.fn.cursor(tonumber(lnum), tonumber(col))
                                end
                            end
                        end
                    end

                    vim.fn["fzf#vim#grep"](cmd, 1, spec, opts.bang and 1 or 0)
                end, {
                    nargs = "*",
                    bang = true,
                    desc = "Search with ripgrep (Ctrl-Q for quickfix)",
                }
                )

                -- Search for exact string match, case-insensitive (FZF with Ctrl-Q to send to quickfix)
                vim.api.nvim_create_user_command("RgIgnoreCaseFixedStrings", function(opts)
                    local query = opts.args
                    if query == "" then
                        query = vim.fn.input("Rg (ignore case)> ")
                        if query == "" then return end
                    end

                    local root_dir = get_project_root()
                    local escaped_query = vim.fn.shellescape(query)
                    local escaped_root_dir = vim.fn.shellescape(root_dir)

                    local cmd = string.format(
                        "rg --ignore-case --fixed-strings --color=always --line-number --column --no-heading %s --glob '!**/*bazel*/**' --glob '!**/desktop/generated/**' --glob '!**/tmp/**' --glob '!node_modules' --glob '!**/*git*/**' --glob '!**/*3rdparty*/**' --glob '!**/*.tools*/**' --glob '!**/*demo_files*/**' --glob '!**/*-lock*/**' --glob '!**/*metals*/**' %s",
                        escaped_query, escaped_root_dir
                    )

                    -- Add Ctrl-Q to send all results to quickfix using --expect
                    local spec = vim.fn["fzf#vim#with_preview"]()
                    spec.options = spec.options or {}
                    table.insert(spec.options, '--expect=ctrl-q')

                    -- Custom sink to handle quickfix population
                    spec['sink*'] = function(lines)
                        local key = table.remove(lines, 1)
                        if key == 'ctrl-q' then
                            -- Send all results to quickfix
                            local qf_cmd = string.format(
                                "rg --vimgrep --ignore-case --fixed-strings %s --glob '!**/*bazel*/**' --glob '!**/desktop/generated/**' --glob '!**/tmp/**' --glob '!node_modules' --glob '!**/*git*/**' --glob '!**/*3rdparty*/**' --glob '!**/*.tools*/**' --glob '!**/*demo_files*/**' --glob '!**/*-lock*/**' --glob '!**/*metals*/**' %s",
                                escaped_query, escaped_root_dir
                            )
                            vim.fn.setqflist({}, 'r')
                            vim.cmd('cexpr system("' .. qf_cmd:gsub('"', '\\"') .. '")')
                            vim.cmd('copen')
                        elseif #lines > 0 then
                            -- Parse the first selected line and open the file
                            local line = lines[1]
                            if line then
                                -- Parse format: filename:line:column:content
                                local parts = vim.split(line, ':')
                                if #parts >= 3 then
                                    local file = parts[1]
                                    local lnum = parts[2]
                                    local col = parts[3]
                                    vim.cmd('edit ' .. vim.fn.fnameescape(file))
                                    vim.fn.cursor(tonumber(lnum), tonumber(col))
                                end
                            end
                        end
                    end

                    vim.fn["fzf#vim#grep"](cmd, 1, spec, opts.bang and 1 or 0)
                end, {
                    nargs = "*",
                    bang = true,
                    desc = "Search with ripgrep (Ctrl-Q for quickfix)",
                }
                )

                -- Search for exact string match, case-insensitive, excluding test files (FZF with Ctrl-Q to send to quickfix)
                vim.api.nvim_create_user_command("RgIgnoreCaseFixedStringsExcludingTests", function(opts)
                    local query = opts.args
                    if query == "" then
                        query = vim.fn.input("Rg (ignore case and tests)> ")
                        if query == "" then return end
                    end

                    local root_dir = get_project_root()
                    local escaped_query = vim.fn.shellescape(query)
                    local escaped_root_dir = vim.fn.shellescape(root_dir)

                    local cmd = string.format(
                        "rg --ignore-case --fixed-strings --color=always --line-number --column --no-heading %s --glob '!**/*bazel*/**' --glob '!**/desktop/generated/**' --glob '!**/tmp/**' --glob '!node_modules' --glob '!**/*git*/**' --glob '!**/*3rdparty*/**' --glob '!**/*.tools*/**' --glob '!**/*demo_files*/**' --glob '!**/*-lock*/**' --glob '!**/*metals*/**' --glob '!**/*_test*' --glob '!**/*.spec*' %s",
                        escaped_query, escaped_root_dir
                    )

                    -- Add Ctrl-Q to send all results to quickfix using --expect
                    local spec = vim.fn["fzf#vim#with_preview"]()
                    spec.options = spec.options or {}
                    table.insert(spec.options, '--expect=ctrl-q')

                    -- Custom sink to handle quickfix population
                    spec['sink*'] = function(lines)
                        local key = table.remove(lines, 1)
                        if key == 'ctrl-q' then
                            -- Send all results to quickfix
                            local qf_cmd = string.format(
                                "rg --vimgrep --ignore-case --fixed-strings %s --glob '!**/*bazel*/**' --glob '!**/desktop/generated/**' --glob '!**/tmp/**' --glob '!node_modules' --glob '!**/*git*/**' --glob '!**/*3rdparty*/**' --glob '!**/*.tools*/**' --glob '!**/*demo_files*/**' --glob '!**/*-lock*/**' --glob '!**/*metals*/**' --glob '!**/*_test*' --glob '!**/*.spec*' %s",
                                escaped_query, escaped_root_dir
                            )
                            vim.fn.setqflist({}, 'r')
                            vim.cmd('cexpr system("' .. qf_cmd:gsub('"', '\\"') .. '")')
                            vim.cmd('copen')
                        elseif #lines > 0 then
                            -- Parse the first selected line and open the file
                            local line = lines[1]
                            if line then
                                -- Parse format: filename:line:column:content
                                local parts = vim.split(line, ':')
                                if #parts >= 3 then
                                    local file = parts[1]
                                    local lnum = parts[2]
                                    local col = parts[3]
                                    vim.cmd('edit ' .. vim.fn.fnameescape(file))
                                    vim.fn.cursor(tonumber(lnum), tonumber(col))
                                end
                            end
                        end
                    end

                    vim.fn["fzf#vim#grep"](cmd, 1, spec, opts.bang and 1 or 0)
                end, {
                    nargs = "*",
                    bang = true,
                    desc = "Search with ripgrep (Ctrl-Q for quickfix)",
                }
                )
            end
        }
    },

    -- Stuff for GraphQL
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            { "williamboman/mason.nvim",           config = true },
            { "williamboman/mason-lspconfig.nvim", enabled = false },
        },
    },

    -- Formatting
    {
        {
            'stevearc/conform.nvim',
            opts = {},
        }
    },
    {
        "chentoast/marks.nvim",
        event = "VeryLazy",
        opts = {},
    },

    -- Save sessions
    {
        'stevearc/resession.nvim',
        opts = {},
    },

    {
        'numToStr/Comment.nvim',
        opts = {}
    },

    {
        'maxmx03/solarized.nvim',
    }
})
