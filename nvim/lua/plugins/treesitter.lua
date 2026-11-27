-- nvim-treesitter's main branch (Neovim 0.12+) only installs parsers and queries;
-- highlighting, folding and selection are Neovim built-ins and are switched on here.
-- Parsers build with tree-sitter-cli (brew install tree-sitter-cli).
local parsers = {
  "ruby",
  "lua",
  "vim",
  "javascript",
  "typescript",
  "tsx",
  "html",
  "python",
  "sql",
  "svelte",
  "graphql",
  "vimdoc",
  "markdown",
  "markdown_inline",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install(parsers)

      -- Highlight every filetype that has a parser; regex syntax stays for the rest.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserTreesitter", {}),
        callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
      })

      -- Alt+o grows the selection to the enclosing node, Alt+i shrinks it back
      -- (Neovim's an/in, which fall back to LSP selection ranges without a parser).
      vim.keymap.set({ "n", "x" }, "<A-o>", function() vim.treesitter.select("parent", vim.v.count1) end,
        { desc = "Select enclosing treesitter node" })
      vim.keymap.set("x", "<A-i>", function() vim.treesitter.select("child", vim.v.count1) end,
        { desc = "Shrink to child treesitter node" })
    end,
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    lazy = false,
    config = function()
      local rainbow_delimiters = require "rainbow-delimiters"
      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow_delimiters.strategy["global"],
          vim = rainbow_delimiters.strategy["local"],
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        priority = {
          [""] = 110,
          lua = 210,
        },
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
    end,
  },
}
