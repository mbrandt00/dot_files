return {
  "nvim-treesitter/nvim-treesitter",
  dependencies = {
    "HiPhish/rainbow-delimiters.nvim",
    "windwp/nvim-ts-autotag",
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  config = function()
    local configs = require "nvim-treesitter.configs"
    local rainbow_delimiters = require "rainbow-delimiters"
    local treesitter_objects = require "nvim-treesitter-textobjects"
    vim.g.rainbow_delimiters = {
      strategy = {
        [""] = rainbow_delimiters.strategy["global"],
        vim = rainbow_delimiters.strategy["local"],
      },
      query = {
        [""] = "rainbow-delimiters",
        lua = "rainbow-blocks",
      },
      priority = {
        [""] = 110,
        lua = 210,
      },
      highlight = {
        "RainbowDelimiterRed",
        "RainbowDelimiterYellow",
        "RainbowDelimiterBlue",
        "RainbowDelimiterOrange",
        "RainbowDelimiterGreen",
        "RainbowDelimiterViolet",
        "RainbowDelimiterCyan",
      },
    }

    configs.setup {
      ensure_installed = {
        "ruby",
        "lua",
        "vim",
        "javascript",
        "html",
        "python",
        "sql",
        "svelte",
        "typescript",
        "graphql",
        "vimdoc",
      },
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = false },
      fold = {
        enable = true,
        custom_foldexpr = "nvim_treesitter#foldexpr()",
      },
    }

    -- Setup for nvim-ts-autotag
    require("nvim-ts-autotag").setup()
  end,
}
