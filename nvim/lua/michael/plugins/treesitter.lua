return {
  "nvim-treesitter/nvim-treesitter",
  dependencies = { "HiPhish/rainbow-delimiters.nvim" },
  config = function()
    local configs = require "nvim-treesitter.configs"
    local rainbow_delimiters = require "rainbow-delimiters"
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
        "vimdoc",
      },
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
      autotag = {
        enable = true,
      },
      fold = {
        enable = true,
        custom_foldexpr = "nvim_treesitter#foldexpr()",
      },
    }
  end,
}
