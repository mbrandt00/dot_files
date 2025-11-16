return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons", "lewis6991/gitsigns.nvim" },
  config = function()
    local lualine = require "lualine"
    local lazy_status = require "lazy.status"

    local colors = {
      dark = {
        blue = "#65D1FF",
        green = "#3EFFDC",
        violet = "#FF61EF",
        yellow = "#FFDA7B",
        red = "#FF4A4A",
        fg = "#c3ccdc",
        bg = "#112638",
        inactive_bg = "#2c3043",
      },
      light = {
        blue = "#2374BE",
        green = "#40A02B",
        violet = "#8839EF",
        yellow = "#df8e1d",
        red = "#D20F39",
        fg = "#4C4F69",
        bg = "#EFF1F5",
        inactive_bg = "#DCE0E8",
      },
    }

    -- Function to get current theme colors
    local function get_theme_colors() return vim.o.background == "dark" and colors.dark or colors.light end

    -- Function to generate theme based on current background
    local function generate_theme()
      local c = get_theme_colors()
      return {
        normal = {
          a = { bg = c.blue, fg = c.bg, gui = "bold" },
          b = { bg = c.bg, fg = c.fg },
          c = { bg = c.bg, fg = c.fg },
        },
        insert = {
          a = { bg = c.green, fg = c.bg, gui = "bold" },
          b = { bg = c.bg, fg = c.fg },
          c = { bg = c.bg, fg = c.fg },
        },
        visual = {
          a = { bg = c.violet, fg = c.bg, gui = "bold" },
          b = { bg = c.bg, fg = c.fg },
          c = { bg = c.bg, fg = c.fg },
        },
        command = {
          a = { bg = c.yellow, fg = c.bg, gui = "bold" },
          b = { bg = c.bg, fg = c.fg },
          c = { bg = c.bg, fg = c.fg },
        },
        replace = {
          a = { bg = c.red, fg = c.bg, gui = "bold" },
          b = { bg = c.bg, fg = c.fg },
          c = { bg = c.bg, fg = c.fg },
        },
        inactive = {
          a = { bg = c.inactive_bg, fg = c.fg, gui = "bold" },
          b = { bg = c.inactive_bg, fg = c.fg },
          c = { bg = c.inactive_bg, fg = c.fg },
        },
      }
    end

    -- Configure lualine
    lualine.setup {
      options = {
        theme = generate_theme(),
        refresh = {
          statusline = 1000,
          tabline = 1000,
          winbar = 1000,
        },
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

    -- Update lualine when background changes
    vim.api.nvim_create_autocmd("OptionSet", {
      pattern = "background",
      callback = function() lualine.setup { options = { theme = generate_theme() } } end,
    })
  end,
}
