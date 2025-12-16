return {
  "f-person/auto-dark-mode.nvim",
  lazy = false,
  dependencies = {
    {
      "folke/tokyonight.nvim",
      "zenbones-theme/zenbones.nvim",
      "rktjmp/lush.nvim",
      lazy = false,
      priority = 1000,
      config = function()
        require("tokyonight").setup {
          style = "moon",
          transparent = false,
        }
      end,
    },
    {
      "morhetz/gruvbox",
      lazy = false,
      priority = 1000,
    },
  },
  config = function()
    local function set_colorscheme(name, background)
      -- Always wipe current theme
      vim.g.colors_name = nil

      -- Apply colorscheme
      vim.cmd.colorscheme(name)

      -- Force background override (some themes will reset it)
      vim.opt.background = background
    end

    require("auto-dark-mode").setup {
      update_interval = 1000,
      fallback = "dark",
      set_dark_mode = function() set_colorscheme("tokyonight", "dark") end,
      set_light_mode = function()
        -- Optional: set gruvbox contrast level
        -- vim.g.gruvbox_contrast_light = "medium"
        -- vim.g.gruvbox_invert_selection = 0
        set_colorscheme("zenbones", "light")

        -- Optional: enforce transparent bg
        vim.cmd [[
          highlight Normal guibg=NONE ctermbg=NONE
          highlight NormalNC guibg=NONE ctermbg=NONE
        ]]
      end,
    }
  end,
}
