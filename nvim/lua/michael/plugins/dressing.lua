return {
  "stevearc/dressing.nvim", -- improve default vim.ui interfaces
  config = function()
    local dressing = require "dressing"
    dressing.setup {
      input = {
        win_options = { winblend = 0 },
      },
    }
  end,
}
