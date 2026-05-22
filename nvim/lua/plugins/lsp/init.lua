return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  priority = 800,
  dependencies = {
    "hrsh7th/nvim-cmp",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
    { "antosha417/nvim-lsp-file-operations", config = true },
  },
  opts = {
    -- Default server configurations
    -- These can be overridden/extended by .lazy.lua
    servers = {},
  },
  config = function(_, opts)
    local shared = require "plugins.lsp.config"

    -- Configure nvim-cmp
    local cmp = require "cmp"
    local luasnip = require "luasnip"

    cmp.setup {
      snippet = {
        expand = function(args) luasnip.lsp_expand(args.body) end,
      },
      mapping = cmp.mapping.preset.insert {
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-n>"] = cmp.mapping.complete(),
        ["<CR>"] = cmp.mapping.confirm { select = true },
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      },
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
      }, {
        { name = "buffer" },
        { name = "path" },
      }),
    }

    -- Configure diagnostic display
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
      underline = true,
      update_in_insert = false,
      severity_sort = true,
      float = { border = "rounded" },
    }

    -- Set up keymaps on LspAttach (more reliable than on_attach in config)
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspConfig", {}),
      callback = function(ev)
        local keymap_opts = { buffer = ev.buf, noremap = true, silent = true }

        keymap_opts.desc = "Show LSP references"
        vim.keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", keymap_opts)

        keymap_opts.desc = "Go to declaration"
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, keymap_opts)

        keymap_opts.desc = "Show LSP definitions"
        vim.keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", keymap_opts)

        keymap_opts.desc = "Show LSP type definitions"
        vim.keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", keymap_opts)

        keymap_opts.desc = "See available code actions"
        vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, keymap_opts)

        keymap_opts.desc = "Smart rename"
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, keymap_opts)

        keymap_opts.desc = "Show buffer diagnostics"
        vim.keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", keymap_opts)

        keymap_opts.desc = "Show line diagnostics"
        vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, keymap_opts)

        keymap_opts.desc = "Go to previous diagnostic"
        vim.keymap.set("n", "[d", function() vim.diagnostic.jump { count = -1 } end, keymap_opts)

        keymap_opts.desc = "Go to next diagnostic"
        vim.keymap.set("n", "]d", function() vim.diagnostic.jump { count = 1 } end, keymap_opts)

        keymap_opts.desc = "Show documentation for what is under cursor"
        vim.keymap.set("n", "K", vim.lsp.buf.hover, keymap_opts)

        keymap_opts.desc = "Restart LSP"
        vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", keymap_opts)
      end,
    })

    local status, result = pcall(function()
      -- Load custom LSP server configurations
      require "plugins.lsp.ts_ls"
      require "plugins.lsp.denols"
      require "plugins.lsp.lua_ls"

      -- Simple servers: just need capabilities + on_attach
      local simple_servers = { "tailwindcss", "rubocop", "ruby_lsp", "sourcekit", "graphql" }
      for _, server in ipairs(simple_servers) do
        vim.lsp.config(server, {
          capabilities = shared.capabilities,
          on_attach = shared.on_attach,
        })
      end

      -- Servers with disable_fmt
      local disable_fmt_servers = { "html", "cssls", "svelte", "emmet_ls" }
      for _, server in ipairs(disable_fmt_servers) do
        vim.lsp.config(server, {
          capabilities = shared.capabilities,
          on_attach = function(client, bufnr)
            shared.disable_fmt(client)
            shared.on_attach(client, bufnr)
          end,
        })
      end

      -- Ruff: Python linter with format-on-save
      vim.lsp.config("ruff", {
        capabilities = shared.capabilities,
        on_attach = function(client, bufnr)
          shared.on_attach(client, bufnr)
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            callback = function() vim.lsp.buf.format { bufnr = bufnr } end,
          })
        end,
        settings = {
          format = { enabled = true },
          lint = { enabled = true },
          organizeImports = { enabled = true },
        },
      })

      -- Pyright: Python type checker with custom settings
      vim.lsp.config("pyright", {
        capabilities = shared.capabilities,
        on_attach = shared.on_attach,
        settings = {
          pyright = {
            disableOrganizeImports = true,
          },
          python = {
            analysis = {
              ignore = { "*" },
            },
          },
        },
      })

      -- Process opts.servers from .lazy.lua merging
      -- This allows repo-level configs to override/extend server settings
      local servers_to_enable = {
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

      for server_name, server_opts in pairs(opts.servers or {}) do
        -- Skip disabled servers
        if server_opts.enabled == false then
          -- Remove from enable list if explicitly disabled
          for i, name in ipairs(servers_to_enable) do
            if name == server_name then
              table.remove(servers_to_enable, i)
              break
            end
          end
        else
          -- Apply server configuration
          local config = vim.tbl_deep_extend("force", {
            capabilities = shared.capabilities,
            on_attach = shared.on_attach,
          }, server_opts)

          -- Remove our custom 'enabled' key before passing to vim.lsp.config
          config.enabled = nil

          vim.lsp.config(server_name, config)

          -- Add to enable list if not already present
          local found = false
          for _, name in ipairs(servers_to_enable) do
            if name == server_name then
              found = true
              break
            end
          end
          if not found then table.insert(servers_to_enable, server_name) end
        end
      end

      -- Enable all LSP servers
      vim.lsp.enable(servers_to_enable)
    end)

    if not status then print("Error in LSP configuration:", result) end
  end,
}
