return {
  -- "leath-dub/snipe.nvim",
  -- keys = {
  --   { "<leader>a", function() require("snipe").open_buffer_menu() end, desc = "Open Snipe buffer menu" },
  -- },
  -- config = function()
  --   local snipe = require "snipe"
  --
  --   -- Setup for Snipe
  --   snipe.setup {
  --     ui = {
  --       max_height = -1,
  --       position = "topright",
  --     },
  --     sort = "last",
  --   }
  --
  --   -- Configure the UI select menu
  --   snipe.ui_select_menu = require("snipe.menu"):new { position = "center" }
  --   snipe.ui_select_menu:add_new_buffer_callback(function(m)
  --     vim.keymap.set("n", "<esc>", function() m:close() end, { nowait = true, buffer = m.buf })
  --   end)
  -- end,
  --
  -- opts = {},
}
