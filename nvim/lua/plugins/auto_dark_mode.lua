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
        vim.g.gruvbox_material_enable_italic = 1
        vim.g.gruvbox_material_disable_italic_comment = 1
        vim.g.gruvbox_material_float_style = "bright"
      end,
    },
  },
  config = function()
    require("auto-dark-mode").setup {
      update_interval = 1000,
      fallback = "dark",
      set_dark_mode = function()
        -- background must be set before :colorscheme; gruvbox-material reads it
        -- (and gruvbox_material_background) at the moment the colorscheme is applied.
        vim.g.gruvbox_material_background = "medium"
        vim.o.background = "dark"
        vim.cmd.colorscheme "gruvbox-material"
      end,
      set_light_mode = function()
        vim.g.gruvbox_material_background = "soft"
        vim.o.background = "light"
        vim.cmd.colorscheme "gruvbox-material"
      end,
    }
  end,
}
