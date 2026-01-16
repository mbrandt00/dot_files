return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons", "lewis6991/gitsigns.nvim" },
  config = function()
    local lualine = require "lualine"
    local lazy_status = require "lazy.status"

    -- Configure lualine
    lualine.setup {
      options = {
        theme = "auto",
      },
      sections = {
        lualine_b = {
          --   {
          --     "branch",
          --     fmt = function(display_string, context)
          --       if #display_string > 20 then
          --         return display_string:sub(1, 20) .. "..."
          --       else
          --         return display_string
          --       end
          --     end,
          --   },
        },
        lualine_c = {
          { "filename", path = 3 },
        },
        lualine_x = {
          {
            lazy_status.updates,
            cond = lazy_status.has_updates,
            color = { fg = "#ff9e64" },
          },
          { "encoding" },
          { "fileformat" },
          { "filetype" },
        },
      },
    }
  end,
}
