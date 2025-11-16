return {
  "stevearc/overseer.nvim",

  config = function()
    local overseer = require "overseer"
    overseer.setup()
    local keymap = vim.keymap

    keymap.set("n", "<leader>or", "<cmd>OverseerRun<CR>", { desc = "Overseer Run" })
    keymap.set("n", "<leader>ot", "<cmd>OverseerToggle<CR>", { desc = "Overseer Toggle" })
  end,
}
