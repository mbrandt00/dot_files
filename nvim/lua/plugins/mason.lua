return {
  "mason-org/mason.nvim",
  lazy = false,
  dependencies = {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  opts = {
    -- Mason UI options
    ui = {
      icons = {
        package_installed = "✓",
        package_pending = "➜",
        package_uninstalled = "✗",
      },
    },
    -- Tools to install (passed to mason-tool-installer)
    ensure_installed = {
      "typescript-language-server",
      "html-lsp",
      "css-lsp",
      "tailwindcss-language-server",
      "svelte-language-server",
      "lua-language-server",
      "pyright",
      "stylua",
      "black",
    },
  },
  config = function(_, opts)
    -- Extract our custom keys before passing to mason
    local ensure_installed = opts.ensure_installed or {}
    opts.ensure_installed = nil

    -- Setup mason with remaining opts
    require("mason").setup(opts)

    -- Setup mason-tool-installer with the tools list
    require("mason-tool-installer").setup {
      ensure_installed = ensure_installed,
      auto_update = false,
      run_on_start = true,
    }
  end,
}
