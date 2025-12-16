return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-tree/nvim-web-devicons",
    {
      "nvim-telescope/telescope-live-grep-args.nvim",
      -- This will not install any breaking changes.
      -- For major updates, this must be adjusted manually.
      version = "^1.0.0",
    },
  },
  config = function()
    local telescope = require "telescope"
    local actions = require "telescope.actions"
    local builtin = require "telescope.builtin"
    local lga_actions = require "telescope-live-grep-args.actions"

    telescope.setup {
      extensions = {

        live_grep_args = {
          auto_quoting = true, -- enable/disable auto-quoting
          -- define mappings, e.g.
          mappings = { -- extend mappings
            i = {
              ["<C-i>"] = lga_actions.quote_prompt { postfix = " --iglob " },
              -- freeze the current list and start a fuzzy search in the frozen list
              ["<C-space>"] = lga_actions.to_fuzzy_refine,
            },
          },
        },
      },
      defaults = {
        path_display = { "truncate" },
        file_ignore_patterns = {
          "^.git/logs/",
          "^private/var/",
        },
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-j>"] = actions.move_selection_next,
            ["<C-q>"] = actions.smart_send_to_qflist,
          },
        },
      },
    }

    telescope.load_extension "live_grep_args"
    telescope.load_extension "fzf"

    local keymap = vim.keymap

    -- Basic telescope mappings
    keymap.set("n", "<leader>ff", "<cmd>Telescope find_files hidden=true<cr>", { desc = "Fuzzy find files in cwd" })
    keymap.set(
      "n",
      "<leader>fg",
      "<cmd>Telescope git_status<CR>",
      { desc = "List current changes per file with diff preview", noremap = true, silent = true }
    )
    keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
    keymap.set("n", "<leader>fs", ":Telescope live_grep_args<cr>", { desc = "Find string in cwd" })
    keymap.set("n", "<leader>fR", function() builtin.lsp_references() end, { desc = "Find references" })
    keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
    keymap.set("n", "<leader>bb", ":Telescope buffers<CR>", { noremap = true, silent = true, desc = "Fuzzy buffers" })

    -- Additional telescope mappings
    keymap.set(
      "n",
      "<leader>fn",
      function() builtin.find_files { cwd = vim.fn.stdpath "config" } end,
      { desc = "[F]ind [N]eovim files" }
    )

    keymap.set("n", "<leader>fS", function() builtin.lsp_document_symbols() end, { desc = "Find symbols" })
  end,
}
