return {
  "vim-test/vim-test",
  config = function()
    -- Key mappings for Vim-test plugin
    local keymaps = {
      { "<leader>t", ":TestNearest<CR>", { noremap = true, silent = true } },
      { "<leader>T", ":TestFile<CR>", { noremap = true, silent = true } },
      { "<leader>ta", ":TestSuite<CR>", { noremap = true, silent = true } },
      { "<leader>l", ":TestLast<CR>", { noremap = true, silent = true } },
    }

    for _, keymap in ipairs(keymaps) do
      vim.keymap.set("n", keymap[1], keymap[2], keymap[3])
    end
  end,
}
