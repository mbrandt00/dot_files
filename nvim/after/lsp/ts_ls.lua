-- Overrides nvim-lspconfig's ts_ls: stay out of Deno projects, handle the server's
-- rename/references commands, and add :LspTypescriptSourceAction. Formatting is left to
-- conform (see the formatting note in lua/plugins/lsp.lua).
return {
  root_dir = function(bufnr, on_dir)
    local root_markers = { { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }, { ".git" } }
    -- Deno projects belong to denols.
    local deno_path = vim.fs.root(bufnr, { "deno.json", "deno.lock" })
    local project_root = vim.fs.root(bufnr, root_markers)
    if deno_path and (not project_root or #deno_path >= #project_root) then return end
    on_dir(project_root or vim.fn.getcwd())
  end,
  handlers = {
    ["_typescript.rename"] = function(_, result, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      vim.lsp.util.show_document({
        uri = result.textDocument.uri,
        range = { start = result.position, ["end"] = result.position },
      }, client.offset_encoding)
      vim.lsp.buf.rename()
      return vim.NIL
    end,
  },
  commands = {
    ["editor.action.showReferences"] = function(command, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      local file_uri, position, references = unpack(command.arguments)
      vim.fn.setqflist({}, " ", {
        title = command.title,
        items = vim.lsp.util.locations_to_items(references, client.offset_encoding),
        context = { command = command, bufnr = ctx.bufnr },
      })
      vim.lsp.util.show_document({
        uri = file_uri,
        range = { start = position, ["end"] = position },
      }, client.offset_encoding)
      vim.cmd "botright copen"
    end,
  },
  on_attach = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, "LspTypescriptSourceAction", function()
      local source_actions = vim.tbl_filter(
        function(action) return vim.startswith(action, "source.") end,
        client.server_capabilities.codeActionProvider.codeActionKinds
      )
      vim.lsp.buf.code_action { context = { only = source_actions, diagnostics = {} } }
    end, {})
  end,
}
