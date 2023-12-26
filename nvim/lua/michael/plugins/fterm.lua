return {
  "numToStr/FTerm.nvim",
  config = function()
    local fterm = require "FTerm"
    fterm.setup {
      border = "double",
    }
    vim.api.nvim_create_user_command("FTermOpen", require("FTerm").open, { bang = true })
    -- vim.api.nvim_create_user_command("FTermToggle", require("FTerm").toggle, { bang = true })
    vim.api.nvim_create_user_command("FTermToggle", function()
      local cwd = vim.fn.getcwd()
      require("FTerm").toggle(cwd)
    end, { bang = true })
    vim.api.nvim_create_user_command("FTermClose", require("FTerm").close, { bang = true })

    vim.api.nvim_set_keymap("n", "<leader>tt", "<cmd>FTermToggle<CR>", { noremap = true, silent = true })
    vim.api.nvim_set_keymap("t", "<Leader>tt", "<C-\\><C-n>:FTermToggle<CR>", { noremap = true, silent = true })
  end,
}
