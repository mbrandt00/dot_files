return {
  "mason-org/mason.nvim",
  lazy = false,
  dependencies = {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  opts = {
    ui = {
      icons = {
        package_installed = "✓",
        package_pending = "➜",
        package_uninstalled = "✗",
      },
    },
    ensure_installed = {
      "typescript-language-server",
      "html-lsp",
      "css-lsp",
      "tailwindcss-language-server",
      "svelte-language-server",
      "lua-language-server",
      "emmet-ls",
      "pyright",
      "biome",
      "stylua",
      "black",
    },
  },

  -- lazy passes the merged opts in here
  config = function(_, opts)
    require("mason").setup {
      ui = opts.ui,
    }

    require("mason-tool-installer").setup {
      ensure_installed = opts.ensure_installed,
    }
  end,
}
