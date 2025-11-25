-- GraphQL LSP Configuration
-- Supports .graphql, .gql files and GraphQL in TS/JS/Svelte files

local shared = require "plugins.lsp.config"

-- Configure GraphQL LSP (matching old working config - no custom cmd or root_dir)
vim.lsp.config("graphql", {
  cmd = { "graphql-lsp", "server", "-m", "stream" },
  capabilities = shared.capabilities,

  on_attach = shared.on_attach,
  filetypes = { "graphql", "gql" },
})

-- Return empty table to satisfy Lazy.nvim (this is not a plugin spec)
return {}
