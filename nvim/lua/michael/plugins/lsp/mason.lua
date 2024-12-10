return {
  "williamboman/mason.nvim",
  dependencies = {
    "williamboman/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer",
    "mfussenegger/nvim-dap",
    "jay-babu/mason-nvim-dap.nvim",
  },
  config = function()
    -- Import mason
    local mason = require "mason"

    -- Import mason-lspconfig
    local mason_lspconfig = require "mason-lspconfig"

    -- Import mason-tool-installer
    local mason_tool_installer = require "mason-tool-installer"

    -- Import mason-nvim-dap
    local mason_nvim_dap = require "mason-nvim-dap"

    -- Enable mason and configure icons
    mason.setup {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    }

    -- Setup nvim-dap
    mason_nvim_dap.setup {
      ensure_installed = { "python" },
      automatic_installation = true,
    }

    -- Set up mason-lspconfig with Ruff
    mason_lspconfig.setup {
      -- List of servers for mason to install
      ensure_installed = {
        "ts_ls",
        "html",
        "cssls",
        "tailwindcss",
        "svelte",
        "lua_ls",
        "graphql",
        "emmet_ls",
        "prismals",
        "pyright",
        "rubocop",
        "ruff",
      },
      automatic_installation = true, -- Automatically install the servers
    }

    -- Set up mason-tool-installer
    mason_tool_installer.setup {
      ensure_installed = {
        "prettier", -- prettier formatter
        "stylua", -- lua formatter
        "isort", -- python formatter
        "black", -- python formatter
        "eslint", -- js linter
        "graphql-language-service-cli",
        "ruff", -- Ensure ruff is installed via mason
      },
    }

    -- Set up lspconfig for Ruff
    local lspconfig = require "lspconfig"
  end,
}
