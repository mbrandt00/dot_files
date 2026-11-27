-- Deno (Supabase Edge Functions and other Deno projects). Attaches only when a deno.json,
-- deno.jsonc or deno.lock is closer to the file than any npm/yarn/pnpm/bun project root.
return {
  cmd = { "deno", "lsp" },
  workspace_required = true,
  root_dir = function(bufnr, on_dir)
    local deno_root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" })
    local npm_root =
      vim.fs.root(bufnr, { "package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" })
    if not deno_root then return end
    if npm_root and #npm_root > #deno_root then return end
    on_dir(deno_root)
  end,
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
}
