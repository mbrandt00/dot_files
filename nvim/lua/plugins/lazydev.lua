return {
  "folke/lazydev.nvim",
  ft = "lua",
  opts = {
    library = {
      -- Adds type definitions for vim.uv
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    },
  },
}
