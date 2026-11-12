vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.cmd.colorscheme "default"

vim.g.terminal_color_0  = "#45475a"
vim.g.terminal_color_1  = "#f38ba8"
-- ... continue up to 15

-- Kitty palette sync
local colors = {
  bg = "#0C0C0C",
  fg = "#DFDFDF",
  cursor = "#DFDFDF",
  selection_bg = "#747474",
  selection_fg = "#0C0C0C",

  color0 = "#0C0C0C",
  color1 = "#E06C75",
  color2 = "#98C379",
  color3 = "#E5C07B",
  color4 = "#61AFEF",
  color5 = "#C678DD",
  color6 = "#A4A4A4",
  color7 = "#DFDFDF",

  color8  = "#2C2C2C",
  color9  = "#FF7A85",
  color10 = "#B5E8A5",
  color11 = "#FFD68A",
  color12 = "#7DCFFF",
  color13 = "#D7A9FF",
  color14 = "#DFDFDF",
  color15 = "#FFFFFF",
}

-- Apply basic highlights
vim.api.nvim_set_hl(0, "Normal", { fg = colors.fg, bg = colors.bg })
vim.api.nvim_set_hl(0, "Cursor", { fg = colors.bg, bg = colors.cursor })
vim.api.nvim_set_hl(0, "Visual", { fg = colors.selection_fg, bg = colors.selection_bg })

-- Syntax groups (tuned to your palette vibe)
vim.api.nvim_set_hl(0, "Comment", { fg = "#747474", italic = true })
vim.api.nvim_set_hl(0, "Keyword", { fg = "#C678DD" })
vim.api.nvim_set_hl(0, "String", { fg = "#98C379" })
vim.api.nvim_set_hl(0, "Function", { fg = "#61AFEF" })
vim.api.nvim_set_hl(0, "Identifier", { fg = "#56B6C2" })
vim.api.nvim_set_hl(0, "Type", { fg = "#E5C07B" })
vim.api.nvim_set_hl(0, "Constant", { fg = "#E06C75" })
vim.api.nvim_set_hl(0, "Number", { fg = "#FF7A85" })

-- UI elements
vim.api.nvim_set_hl(0, "LineNr", { fg = "#2C2C2C" })
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#A4A4A4" })
vim.api.nvim_set_hl(0, "StatusLine", { fg = colors.fg, bg = colors.color0 })
vim.api.nvim_set_hl(0, "VertSplit", { fg = colors.color8 })


vim.wo.number = true          -- Show absolute line numbers
vim.wo.relativenumber = true  -- Show relative line numbers (hybrid mode)

