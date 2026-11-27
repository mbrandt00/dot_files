-- LSP on Neovim's native client. nvim-lspconfig only supplies the server definitions
-- (its lsp/*.lua files); our overrides live in after/lsp/<server>.lua.
--
-- Default maps from Neovim cover the rest: K hover, grn rename, gra code action,
-- grr references, gri implementation, grt type definition, gO symbols, [d / ]d
-- diagnostics, <C-w>d diagnostic float, <C-s> signature help in insert mode.
--
-- Formatting: conform formats on save and falls back to the LSP when it has no
-- formatter for the filetype (ruff for Python, denols for Deno). Servers listed in
-- no_format never format, so that fallback can't pick them.
local servers = {
  "html",
  "rubocop",
  "ruby_lsp",
  "denols",
  "ts_ls",
  "cssls",
  "tailwindcss",
  "svelte",
  "graphql",
  "emmet_ls",
  "ruff",
  "pyright",
  "sourcekit",
  "lua_ls",
}

local no_format = { html = true, cssls = true, svelte = true, emmet_ls = true, ts_ls = true }

-- Repo .lazy.lua files may still use names nvim-lspconfig has since renamed.
local renamed = { tsgo = "tsc" }

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    -- Pinned: 1303184 (2026-10-25) added a 30s timer that asserts the log file
    -- exists, which errors repeatedly when nothing has written to it yet.
    { "antosha417/nvim-lsp-file-operations", commit = "cab4c48", config = true },
  },
  opts = {
    -- Per-repo overrides from .lazy.lua: servers = { name = { enabled = false } | config }.
    servers = {},
  },
  config = function(_, opts)
    -- Every server advertises nvim-cmp's completion capabilities.
    vim.lsp.config("*", {
      capabilities = require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities()),
    })

    vim.diagnostic.config {
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "",
          [vim.diagnostic.severity.WARN] = "",
          [vim.diagnostic.severity.HINT] = "󰌵",
          [vim.diagnostic.severity.INFO] = "",
        },
      },
      virtual_text = false,
      -- Full messages under the cursor's line only.
      virtual_lines = { current_line = true },
      underline = true,
      update_in_insert = false,
      severity_sort = true,
    }

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspConfig", {}),
      callback = function(ev)
        local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
        if no_format[client.name] then
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end
        if client:supports_method "textDocument/inlayHint" then
          vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
        end

        local function map(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, silent = true, desc = desc }) end
        map("gd", "<cmd>Telescope lsp_definitions<CR>", "Show LSP definitions")
        map("gD", vim.lsp.buf.declaration, "Go to declaration")
        map("gt", "<cmd>Telescope lsp_type_definitions<CR>", "Show LSP type definitions")
        map("gR", "<cmd>Telescope lsp_references<CR>", "Show LSP references")
        map("<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", "Show buffer diagnostics")
        map("<leader>rs", "<cmd>lsp restart<CR>", "Restart LSP")
        map("<leader>ih", function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = ev.buf }, { bufnr = ev.buf })
        end, "Toggle inlay hints")
      end,
    })

    local enabled = vim.deepcopy(servers)
    for name, server_opts in pairs(opts.servers or {}) do
      name = renamed[name] or name
      if server_opts.enabled == false then
        enabled = vim.tbl_filter(function(s) return s ~= name end, enabled)
      else
        local config = vim.deepcopy(server_opts)
        config.enabled = nil
        vim.lsp.config(name, config)
        if not vim.tbl_contains(enabled, name) then table.insert(enabled, name) end
      end
    end
    vim.lsp.enable(enabled)
  end,
}
