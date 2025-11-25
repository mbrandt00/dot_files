-- Lua Language Server Configuration
-- Optimized for Neovim plugin development

local shared = require "plugins.lsp.config"

-- Configure lua_ls
vim.lsp.config("lua_ls", {
  cmd = { "lua-language-server" },
  capabilities = shared.capabilities,
  on_attach = shared.on_attach,
  settings = {
    Lua = {
      diagnostics = {
        -- Recognize 'vim' global
        globals = { "vim" },
      },
      workspace = {
        -- Make server aware of Neovim runtime files and config
        library = {
          [vim.fn.expand "$VIMRUNTIME/lua"] = true,
          [vim.fn.stdpath "config" .. "/lua"] = true,
        },
      },
    },
  },
})

-- Return empty table to satisfy Lazy.nvim (this is not a plugin spec)
return {}
