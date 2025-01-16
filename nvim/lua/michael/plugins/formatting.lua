return {
  "stevearc/conform.nvim",
  lazy = true,
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require "conform"

    -- Define the custom RuboCop command function
    local function rubocop_cmd()
      local current_file = vim.fn.expand "%:p"
      local project_root = vim.fn.finddir("rails-api", vim.fn.getcwd() .. ";")

      if project_root ~= "" then
        project_root = vim.fn.fnamemodify(project_root, ":p:h") -- Get absolute path
        if vim.fn.filereadable(project_root .. "/Gemfile") == 1 then
          return {
            "bundle",
            "exec",
            "rubocop",
            "--parallel",
            "--debug",
            "--force-exclusion", -- Respect .rubocop.yml exclusions
            cwd = project_root,
          }
        end
      end
      return { "rubocop", "--debug" }
    end -- Configure conform
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
        ruby = {
          "rubocop",
          command = rubocop_cmd,
          timeout_ms = 1000,
        },
        python = { "isort", "black" },
      },

      format_on_save = {
        lsp_fallback = true,
        async = false,
        timeout_ms = 1000, -- Global timeout
      },
    }

    -- Keybinding to trigger formatting
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
