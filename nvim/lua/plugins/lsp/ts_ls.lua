-- TypeScript/JavaScript LSP Configuration
-- Configured to work with Biome for formatting/linting
-- Excludes Deno projects (use denols) and Svelte files (use svelte LSP)

local shared = require "plugins.lsp.config"

-- Configure ts_ls
vim.lsp.config("ts_ls", {
  capabilities = shared.capabilities,
  on_attach = function(client, bufnr)
    -- Enable formatting (removed disable_fmt)
    shared.on_attach(client, bufnr)

    -- Format on save for this buffer
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function()
        vim.lsp.buf.format({
          bufnr = bufnr,
          filter = function(c) return c.name == "ts_ls" end,
        })
      end,
    })
  end,
  root_dir = function(fname)
    -- Find project root by looking for common TS/JS project markers
    return vim.fs.root(fname, { "package.json", "tsconfig.json", "jsconfig.json", ".git" })
  end,
  filetypes = {
    "typescript",
    "javascript",
    "javascriptreact",
    "typescriptreact",
  },
})

-- Prevent ts_ls from attaching to Supabase functions and Svelte files
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "ts_ls" then return end

    local bufname = vim.api.nvim_buf_get_name(args.buf)
    local filetype = vim.bo[args.buf].filetype

    -- Stop ts_ls from Supabase functions (Deno territory)
    if bufname:match "supabase/functions" then
      vim.schedule(function() vim.lsp.stop_client(client.id, true) end)
    end

    -- Stop ts_ls from Svelte files (svelte LSP handles these)
    if filetype == "svelte" then
      vim.schedule(function() vim.lsp.stop_client(client.id, true) end)
    end
  end,
})

-- Return empty table to satisfy Lazy.nvim (this is not a plugin spec)
return {}
