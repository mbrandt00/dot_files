vim.g.mapleader = " "
require "michael.lazy"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.wrap = true
vim.opt.textwidth = 90
vim.opt.ignorecase = true
-- vim.opt.softtabstop = 4
-- vim.opt.tabstop = 4
-- vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.clipboard = "unnamed"
vim.api.nvim_set_keymap("n", "<leader>bd", ":bdelete<CR>", { noremap = true })
vim.cmd "hi LineNr guifg=#61afef ctermfg=blue"
vim.cmd "hi CursorLineNr guifg=#61afef ctermfg=blue"

-- functions
local builtin = require "telescope.builtin"

vim.keymap.set(
  "n",
  "<leader>fn",
  function() builtin.find_files { cwd = vim.fn.stdpath "config" } end,
  { desc = "[F]ind in [N]eovim config" }
)
vim.cmd [[
augroup highlight_yank
autocmd!
au TextYankPost * silent! lua vim.highlight.on_yank({higroup="Visual", timeout=400})
augroup END
]]
