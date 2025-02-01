return {
  "folke/tokyonight.nvim",
  priority = 1000,
  config = function() vim.cmd [[colorscheme tokyonight]] end,
}

-- return {
--   {
--     "dgox16/oldworld.nvim",
--     lazy = false,
--     priority = 1000,
--     config = function()
--       require("oldworld").setup {
--         styles = {
--           booleans = { italic = true, bold = true },
--         },
--         highlight_overrides = {
--           Comment = { bg = "#ff0000" },
--         },
--       }
--
--       vim.cmd.colorscheme "oldworld"
--     end,
--   },
-- }
