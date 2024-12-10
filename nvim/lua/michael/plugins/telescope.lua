return {
  "nvim-telescope/telescope.nvim",
  -- branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    local telescope = require "telescope"
    local actions = require "telescope.actions"
    local builtin = require "telescope.builtin"

    telescope.setup {
      pickers = {
        buffers = {
          show_all_buffers = true,
          sort_lastused = true,
          sort_mru = true,
          previewer = true,
          theme = "dropdown",
          mappings = {
            i = {
              ["<C-x>"] = actions.delete_buffer + actions.move_to_top,
            },
          },
        },
        marks = {
          mappings = {
            i = {
              ["<C-x>"] = actions.delete_mark,
            },
          },
        },
      },
      extensions = {
        smart_open = {
          match_algorithm = "fzf",
        },
      },
      defaults = {
        path_display = { "truncate " },
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous, -- move to prev result
            ["<C-j>"] = actions.move_selection_next, -- move to next result
            ["<C-q>"] = actions.smart_send_to_qflist,
          },
        },
      },
    }

    telescope.load_extension "fzf"

    -- set keymaps
    local keymap = vim.keymap

    keymap.set("n", "<leader>ff", "<cmd>Telescope smart_open hidden=true<cr>", { desc = "Fuzzy find files in cwd" })
    keymap.set(
      "n",
      "<leader>fg",
      "<cmd>Telescope git_status<CR>",
      { desc = "list current changes per file with diff preview", noremap = true, silent = true }
    )
    keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
    keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
    keymap.set("n", "<leader>fR", function() builtin.lsp_references() end, { desc = "Find references" })
    keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
    -- keymap.set("n", "<leader>m", ":Telescope marks<CR>", { noremap = true, silent = true, desc = "Fuzzy marks" })
    keymap.set("n", "<leader>bb", ":Telescope buffers<CR>", { noremap = true, silent = true, desc = "Fuzzy buffers" })
    keymap.set("n", "<C-s>", require("auto-session.session-lens").search_session, {
      noremap = true,
    })
  end,
  vim.keymap.set(
    "n",
    "<leader>fn",
    function() require("telescope").builtin.find_files { cwd = vim.fn.stdpath "config" } end,
    { desc = "[F]ind [N]eovim files" }
  ),
  vim.keymap.set(
    "n",
    "<leader>fS",
    function() require("telescope.builtin").lsp_document_symbols() end,
    { desc = "Find symbols" }
  ),
}
