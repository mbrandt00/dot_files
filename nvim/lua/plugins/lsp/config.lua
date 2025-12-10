-- Shared LSP configuration
-- This module exports common configuration used across all LSP servers

local M = {}

-- Helper function to disable formatting for an LSP client
function M.disable_fmt(client)
  client.server_capabilities.documentFormattingProvider = false
  client.server_capabilities.documentRangeFormattingProvider = false
end

-- Placeholder on_attach for server-specific logic (keymaps handled by LspAttach autocmd)
function M.on_attach(_client, _bufnr) end

-- LSP capabilities with nvim-cmp integration
M.capabilities = vim.lsp.protocol.make_client_capabilities()
M.capabilities = require("cmp_nvim_lsp").default_capabilities(M.capabilities)
M.capabilities.textDocument.foldingRange = {
  dynamicRegistration = false,
  lineFoldingOnly = true,
}

return M
