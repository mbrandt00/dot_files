return {
  {
    "rmanocha/linear-nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "stevearc/dressing.nvim",
    },
    config = function()
      require("linear-nvim").setup {
        issue_fields = { "title", "description" },
        log_level = "warn",
        -- default_label_ids = { "abc" }, -- add your real label IDs if needed
      }

      -- Keymaps for linear-nvim
      vim.keymap.set(
        "n",
        "<leader>mm",
        function() require("linear-nvim").show_assigned_issues() end,
        { desc = "Linear: Show assigned issues" }
      )

      vim.keymap.set(
        { "n", "v" },
        "<leader>mc",
        function() require("linear-nvim").create_issue() end,
        { desc = "Linear: Create issue" }
      )

      vim.keymap.set(
        "n",
        "<leader>ms",
        function() require("linear-nvim").show_issue_details() end,
        { desc = "Linear: Show issue details" }
      )
    end,
  },
}
