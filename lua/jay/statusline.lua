local M = {}

local fn = vim.fn

local dev_branches = {
    dev = true,
}

local function set_highlights()
    local palette = require("catppuccin.palettes").get_palette("mocha")
    local highlights = {
        StatuslineBase = { fg = palette.subtext0, bg = palette.mantle },
        StatuslineMuted = { fg = palette.overlay1, bg = palette.mantle },
        StatuslinePanel = { fg = palette.text, bg = palette.surface0 },
        StatuslineAccent = { fg = palette.text, bg = palette.surface1 },
        StatuslineInfo = { fg = palette.blue, bg = palette.mantle },
        StatuslineWarn = { fg = palette.yellow, bg = palette.mantle },
        StatuslineError = { fg = palette.red, bg = palette.mantle },
        StatuslineGit = { fg = palette.green, bg = palette.mantle },
        StatuslineGitDev = { fg = palette.base, bg = palette.red, bold = true },
        StatuslineDiff = { fg = palette.teal, bg = palette.mantle },
        StatuslineInactive = { fg = palette.overlay0, bg = palette.base },
    }

    for name, spec in pairs(highlights) do
        vim.api.nvim_set_hl(0, name, spec)
    end
end

local function section(group, text)
    if text == nil or text == "" then
        return ""
    end

    return table.concat({ "%#", group, "# ", text, " " })
end

local function branch_name()
    local gitsigns = vim.b.gitsigns_status_dict
    if gitsigns and gitsigns.head and gitsigns.head ~= "" then
        return gitsigns.head
    end

    if vim.fn.exists("*FugitiveHead") == 1 then
        local head = vim.fn.FugitiveHead()
        if head ~= nil and head ~= "" then
            return head
        end
    end

    return ""
end

local function branch_highlight(branch)
    if dev_branches[branch] then
        return "StatuslineGitDev"
    end

    return "StatuslineGit"
end

local function git_diff()
    local gitsigns = vim.b.gitsigns_status_dict
    if not gitsigns then
        return ""
    end

    local parts = {}
    if (gitsigns.added or 0) > 0 then
        table.insert(parts, "+" .. gitsigns.added)
    end
    if (gitsigns.changed or 0) > 0 then
        table.insert(parts, "~" .. gitsigns.changed)
    end
    if (gitsigns.removed or 0) > 0 then
        table.insert(parts, "-" .. gitsigns.removed)
    end

    return table.concat(parts, " ")
end

local function diagnostic_counts()
    local bufnr = vim.api.nvim_get_current_buf()
    local counts = {
        error = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR }),
        warn = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN }),
        info = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.INFO }),
    }

    local parts = {}
    if counts.error > 0 then
        table.insert(parts, "%#StatuslineError#E:" .. counts.error)
    end
    if counts.warn > 0 then
        table.insert(parts, "%#StatuslineWarn#W:" .. counts.warn)
    end
    if counts.info > 0 then
        table.insert(parts, "%#StatuslineInfo#I:" .. counts.info)
    end

    if #parts == 0 then
        return ""
    end

    return table.concat(parts, "%#StatuslineMuted# ")
end

local function buffer_directory(width)
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" then
        return "[No Name]"
    end

    local dir = fn.fnamemodify(path, ":~:.:h")
    if dir == "." or dir == "" then
        dir = fn.fnamemodify(fn.getcwd(), ":t")
    elseif width < 120 then
        dir = fn.pathshorten(dir)
    end

    return dir
end

local function filename()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" then
        return "[No Name]"
    end

    return fn.fnamemodify(path, ":t")
end

local function file_flags()
    local flags = {}
    if vim.bo.modified then
        table.insert(flags, "+")
    end
    if vim.bo.readonly then
        table.insert(flags, "RO")
    end
    if not vim.bo.modifiable then
        table.insert(flags, "LOCK")
    end

    return table.concat(flags, " ")
end

local function filetype_label()
    if vim.bo.buftype == "terminal" then
        return "terminal"
    end

    return vim.bo.filetype ~= "" and vim.bo.filetype or "text"
end

local function recording_status()
    local register = fn.reg_recording()
    if register == "" then
        return ""
    end

    return "REC @" .. register
end

function M.render()
    if vim.api.nvim_get_current_win() ~= vim.g.statusline_winid then
        return table.concat({
            section("StatuslineInactive", " "),
            "%#StatuslineInactive# ",
            filename(),
            "%=%#StatuslineInactive# ",
            filetype_label(),
            " ",
        })
    end

    local width = vim.api.nvim_win_get_width(0)
    local branch = branch_name()
    local left = {
        section(branch_highlight(branch), branch ~= "" and "git:" .. branch or ""),
        section("StatuslineMuted", "dir:" .. buffer_directory(width)),
        section("StatuslinePanel", filename()),
    }

    local flags = file_flags()
    if flags ~= "" then
        table.insert(left, section("StatuslineAccent", flags))
    end

    local right = {
        section("StatuslineWarn", recording_status()),
        section("StatuslineDiff", git_diff()),
        section("StatuslineMuted", diagnostic_counts()),
    }

    if width >= 100 then
        table.insert(right, section("StatuslinePanel", filetype_label()))
    end

    table.insert(right, section("StatuslineBase", "%l:%c"))
    table.insert(right, section("StatuslineMuted", "%p%%"))

    return table.concat(left) .. "%=%#StatuslineBase#" .. table.concat(right)
end

function M.setup()
    set_highlights()

    vim.opt.laststatus = 3
    vim.opt.showmode = false
    _G.jay_statusline = M
    vim.o.statusline = "%!v:lua.jay_statusline.render()"

    vim.api.nvim_create_autocmd("ColorScheme", {
        callback = set_highlights,
    })
end

return M
