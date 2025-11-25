vim.g.mapleader = " "
require "lazy-setup"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.wrap = true
vim.opt.textwidth = 90
vim.opt.ignorecase = true
vim.opt.softtabstop = 2
vim.opt.tabstop = 2 -- Width of a tab character
vim.opt.shiftwidth = 2 -- Width of indentation
vim.opt.expandtab = true -- Convert tabs to spaces
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
vim.keymap.set("n", "<leader>r", "<cmd>source $MYVIMRC<CR>", { silent = true, desc = "Reload config" })

-- Map Alt+j to move down the quickfix list
vim.keymap.set("n", "<A-j>", "<cmd>cnext<CR>", { noremap = true, silent = true, desc = "Next item in quickfix list" })

-- Map Alt+k to move up the quickfix list
vim.keymap.set(
  "n",
  "<A-k>",
  "<cmd>cprev<CR>",
  { noremap = true, silent = true, desc = "Previous item in quickfix list" }
)

vim.keymap.set("n", "<A-q>", "<cmd>copen<CR>", { noremap = true, silent = true, desc = "Open quickfix list" })
vim.keymap.set("n", "<A-c>", "<cmd>cclose<CR>", { noremap = true, silent = true, desc = "Close quickfix list" })

-- black hole register mapping
vim.api.nvim_set_keymap("n", "<leader><leader>d", '"_d', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader><leader>c", '"_c', { noremap = true, silent = true })

-- easy exit out of insert mode
vim.api.nvim_set_keymap("i", "jj", "<Esc>", { noremap = false })
-- close all pop up windows
-- Close all floating windows
vim.api.nvim_create_user_command("CloseFloatingWindows", function(opts)
  for _, window_id in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(window_id).relative ~= "" then vim.api.nvim_win_close(window_id, opts.bang) end
  end
end, { bang = true, nargs = 0 })

-- Keymap
vim.keymap.set("n", "<leader>cf", "<cmd>CloseFloatingWindows<CR>", { desc = "Close floating windows" })
