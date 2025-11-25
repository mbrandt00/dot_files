return {
  "stevearc/conform.nvim",

  config = function()
    local conform = require "conform"
    conform.setup {
      formatters_by_ft = {
        lua = { "stylua" },
        json = { "prettier" },
        javascript = { "biome", "biome-organize-imports" },
        javascriptreact = { "biome", "biome-organize-imports" },
        typescript = { "biome", "biome-organize-imports" },
        typescriptreact = { "biome", "biome-organize-imports" },
        go = { "goimports", "gofmt" },
        rust = { "rustfmt" },
      },
      format_on_save = {
        -- These options will be passed to conform.format()
        timeout_ms = 500,
        lsp_format = "fallback",
      },
    }
  end,
}
