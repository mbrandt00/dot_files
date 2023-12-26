vim.g.mapleader = " "
require "michael.lazy"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.wrap = true
vim.opt.textwidth = 90
vim.opt.ignorecase = true
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = false
vim.opt.tabstop = 1
-- vim.opt.clipboard =unnamed
vim.api.nvim_set_keymap("n", "<leader>bd", ":bdelete<CR>", { noremap = true })
vim.cmd "hi LineNr guifg=#61afef ctermfg=blue"
vim.cmd "hi CursorLineNr guifg=#61afef ctermfg=blue"
