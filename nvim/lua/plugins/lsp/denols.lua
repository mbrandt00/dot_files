-- Deno LSP Configuration
-- For Supabase Edge Functions and other Deno projects
-- Only attaches when deno.json or deno.jsonc is found

local shared = require "plugins.lsp.config"

-- Configure denols
vim.lsp.config("denols", {
  cmd = { "deno", "lsp" },
  capabilities = shared.capabilities,
  on_attach = function(client, bufnr)
    shared.on_attach(client, bufnr)

    -- Format on save for this buffer
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function()
        vim.lsp.buf.format {
          bufnr = bufnr,
          filter = function(c) return c.name == "denols" end,
        }
      end,
    })
  end,
  root_markers = { "deno.json", "deno.jsonc" },
  workspace_required = true,
  settings = {
    deno = {
      enable = true,
      lint = true,
      unstable = true,
      suggest = {
        imports = {
          hosts = {
            ["https://deno.land"] = true,
            ["https://cdn.nest.land"] = true,
            ["https://crux.land"] = true,
          },
        },
      },
    },
  },
})

return {}
