return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  ft = { "markdown" },
  cmd = { "RenderMarkdown" },
  keys = {
    { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown rendering" },
    { "<leader>uM", "<cmd>RenderMarkdown buf_toggle<cr>", desc = "Toggle markdown rendering (buffer)" },
  },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    -- Raw text on the cursor line only, so editing stays honest.
    anti_conceal = { enabled = true },
    -- Sign column icons duplicate the inline heading icons.
    sign = { enabled = false },
    -- Completion for callouts and checkboxes through the built-in LSP source.
    completions = { lsp = { enabled = true } },
    heading = {
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      width = "block",
      min_width = 0,
      left_pad = 1,
      right_pad = 2,
      border = true,
    },
    code = {
      style = "full",
      width = "block",
      min_width = 0,
      left_pad = 1,
      right_pad = 2,
      border = "thick",
      language_icon = true,
      language_name = true,
    },
    bullet = { icons = { "●", "○", "◆", "◇" } },
    quote = { icon = "▎" },
    pipe_table = { preset = "round" },
    checkbox = {
      unchecked = { icon = "󰄱 " },
      checked = { icon = "󰱒 ", scope_highlight = "@markup.strikethrough" },
    },
  },
}
