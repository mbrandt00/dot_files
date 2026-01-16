return {
  "f-person/auto-dark-mode.nvim",
  lazy = false,
  dependencies = {
    {
      "sainnhe/gruvbox-material",
      lazy = false,
      priority = 1000,
      config = function()
        vim.g.gruvbox_material_background = "medium"
        vim.g.gruvbox_material_foreground = "material"
        vim.g.gruvbox_material_better_performance = 1
      end,
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
      set_dark_mode = function()
        vim.g.gruvbox_material_background = "medium"
        set_colorscheme("gruvbox-material", "dark")
      end,
      set_light_mode = function()
        vim.g.gruvbox_material_background = "soft"
        set_colorscheme("gruvbox-material", "light")
      end,
    }
  end,
}
