return {
  "stevearc/conform.nvim",
  lazy = true,
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require "conform"

    conform.setup {
      formatters_by_ft = {
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        svelte = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        graphql = { "prettier" },
        lua = { "stylua" },
        ruby = { "rubocop" },
        python = { "black" },
      },

      formatters = {
        rubocop = {
          command = "/Users/michaelbrandt/.asdf/shims/rubocop",
          args = {
            "--auto-correct-all",
            "--stderr",
            "--force-exclusion",
            "$FILENAME",
          },
          stdin = false,
          cwd = require("conform.util").root_file { "Gemfile", ".rubocop.yml" },
        },
      },

      format_on_save = function(bufnr)
        return {
          lsp_fallback = true,
          timeout_ms = 3000,
        }
      end,
    }

    -- Manual formatting keymap
    vim.keymap.set(
      { "n", "v" },
      "<leader>mp",
      function()
        conform.format {
          lsp_fallback = true,
          async = true,
          timeout_ms = 5000,
        }
      end,
      { desc = "Format file or range (in visual mode)" }
    )
  end,
}
