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
  root_dir = function(bufnr, on_dir)
    -- Look for deno.json, deno.jsonc, or deno.lock as root markers
    local deno_markers = { "deno.json", "deno.jsonc", "deno.lock" }

    -- Find deno project root
    local deno_root = vim.fs.root(bufnr, deno_markers)
    -- Find npm/yarn/etc project root
    local non_deno_path = vim.fs.root(
      bufnr,
      { "package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }
    )

    -- Only attach if deno root is found and is closer to (or same as) the file than npm root
    if not deno_root then return end
    if non_deno_path and #non_deno_path > #deno_root then return end

    on_dir(deno_root)
  end,
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
