return {
  "lewis6991/hover.nvim",
  config = function()
    require("hover").setup {
      init = function()
        require("hover.providers.lsp")
        -- Uncomment to enable additional providers:
        -- require("hover.providers.gh")
        -- require("hover.providers.gh_user")
        -- require("hover.providers.dictionary")
        -- require("hover.providers.man")
      end,
      preview_opts = {
        border = "rounded",
      },
      preview_window = false,
      title = true,
    }

    -- Keymaps
    vim.keymap.set("n", "K", require("hover").hover, { desc = "hover.nvim" })
    vim.keymap.set("n", "gK", require("hover").hover_select, { desc = "hover.nvim (select)" })
    vim.keymap.set("n", "<C-p>", function()
      require("hover").hover_switch("previous")
    end, { desc = "hover.nvim (previous source)" })
    vim.keymap.set("n", "<C-n>", function()
      require("hover").hover_switch("next")
    end, { desc = "hover.nvim (next source)" })
  end,
}
