return {
  "folke/neoconf.nvim",
  config = function()
    local neoconf = require "neoconf"
    neoconf.setup {
      plugins = {
        lspconfig = {
          enabled = true, -- Enable lspconfig integration
        },
      },
    }
  end,
}
