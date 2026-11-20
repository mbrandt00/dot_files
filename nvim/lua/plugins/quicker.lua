return {
  "stevearc/quicker.nvim",
  ft = "qf",
  ---@module "quicker"
  ---@type quicker.SetupOptions
  opts = {
    -- Buffer-local keymaps inside the quickfix window
    keys = {
      {
        ">",
        function() require("quicker").expand { before = 2, after = 2, add_to_existing = true } end,
        desc = "Expand quickfix context",
      },
      { "<", function() require("quicker").collapse() end, desc = "Collapse quickfix context" },
    },
    -- Edit results like a normal buffer; :w writes changes back to the source files.
    -- Great for grep-driven project-wide edits.
    edit = { enabled = true, autosave = "unmodified" },
    highlight = { treesitter = true, lsp = true, load_buffers = false },
    trim_leading_whitespace = "common",
  },
}
