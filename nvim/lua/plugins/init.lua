return {
  "nvim-lua/plenary.nvim", -- lua functions that many plugins use
  "inkarkat/vim-ReplaceWithRegister", -- replace with register contents using motion (gr + motion)
  {
    "wakatime/vim-wakatime",
    config = function()
      require("wakatime").setup({ status_bar_enabled = false })
    end,
  },
  "junegunn/vim-peekaboo",
  "edluffy/hologram.nvim",
}
