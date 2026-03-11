require("conform").setup({
    format_on_save = {
        -- These options will be passed to conform.format()
        lsp_format = "fallback",
    },
    formatters_by_ft = {
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        css = { "prettier" },
        yaml = { "prettier" },
        html = { "prettier" },
        markdown = { "prettier" },
        lua = { "lsp" },
    },
})
