-- Dark template; theme-apply generates ~/.config/nvim/colors/qs.lua from it.
vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.g.colors_name = "qs"
vim.o.termguicolors = true
vim.o.background = "dark"

local c = {
  bg = "#0C0C0C", surface = "#2C2C2C", border = "#4E4E4E", dim = "#747474",
  muted = "#A4A4A4", fg = "#DFDFDF", accent = "#FFFFFF",
  red = "#C78A8E", green = "#8FB996", yellow = "#C2B67E", cyan = "#7FB8BF",
}
local function hl(group, opts) vim.api.nvim_set_hl(0, group, opts) end

hl("Normal",       { fg = c.fg, bg = c.bg })
hl("NormalFloat",  { fg = c.fg, bg = c.surface })
hl("FloatBorder",  { fg = c.border, bg = c.surface })
hl("CursorLine",   { bg = c.surface })
hl("CursorLineNr", { fg = c.accent, bold = true })
hl("LineNr",       { fg = c.dim })
hl("SignColumn",   { bg = c.bg })
hl("WinSeparator", { fg = c.border })
hl("Visual",       { bg = c.border })
hl("Search",       { fg = c.bg, bg = c.yellow })
hl("IncSearch",    { fg = c.bg, bg = c.accent })
hl("MatchParen",   { fg = c.accent, bold = true })
hl("Pmenu",        { fg = c.fg, bg = c.surface })
hl("PmenuSel",     { fg = c.bg, bg = c.muted })
hl("StatusLine",   { fg = c.fg, bg = c.surface })
hl("StatusLineNC", { fg = c.dim, bg = c.surface })
hl("Directory",    { fg = c.cyan })
hl("Error",        { fg = c.red })
hl("ErrorMsg",     { fg = c.red })
hl("WarningMsg",   { fg = c.yellow })

hl("Comment",    { fg = c.dim, italic = true })
hl("Constant",   { fg = c.cyan })
hl("String",     { fg = c.green })
hl("Identifier", { fg = c.fg })
hl("Function",   { fg = c.accent })
hl("Statement",  { fg = c.yellow })
hl("PreProc",    { fg = c.muted })
hl("Type",       { fg = c.cyan })
hl("Special",    { fg = c.cyan })
hl("Todo",       { fg = c.bg, bg = c.yellow })

hl("DiagnosticError", { fg = c.red })
hl("DiagnosticWarn",  { fg = c.yellow })
hl("DiagnosticInfo",  { fg = c.cyan })
hl("DiagnosticHint",  { fg = c.muted })
hl("DiffAdd",    { bg = c.surface, fg = c.green })
hl("DiffChange", { bg = c.surface, fg = c.yellow })
hl("DiffDelete", { bg = c.surface, fg = c.red })
