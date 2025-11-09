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
  config = function()
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

    local keymap = vim.keymap

    local function disable_fmt(client)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end

    local opts = { noremap = true, silent = true }
    local on_attach = function(_client, bufnr)
      opts.buffer = bufnr

      opts.desc = "Show LSP references"
      keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", opts)

      opts.desc = "Go to declaration"
      keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

      opts.desc = "Show LSP definitions"
      keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts)

      opts.desc = "Show LSP type definitions"
      keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts)

      opts.desc = "See available code actions"
      keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

      opts.desc = "Smart rename"
      keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

      opts.desc = "Show buffer diagnostics"
      keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts)

      opts.desc = "Show line diagnostics"
      keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

      opts.desc = "Go to previous diagnostic"
      keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)

      opts.desc = "Go to next diagnostic"
      keymap.set("n", "]d", vim.diagnostic.goto_next, opts)

      opts.desc = "Show documentation for what is under cursor"
      keymap.set("n", "K", vim.lsp.buf.hover, opts)

      opts.desc = "Restart LSP"
      keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)
    end

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
    capabilities.textDocument.foldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true,
    }

    vim.diagnostic.config {
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = " ",
          [vim.diagnostic.severity.WARN] = " ",
          [vim.diagnostic.severity.HINT] = "󰠠 ",
          [vim.diagnostic.severity.INFO] = " ",
        },
      },
      virtual_text = true,
      underline = true,
      update_in_insert = false,
      severity_sort = true,
    }

    local status, result = pcall(function()
      -- HTML
      vim.lsp.config("html", {
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          disable_fmt(client)
          on_attach(client, bufnr)
        end,
      })

      -- Ruby
      vim.lsp.config("rubocop", {
        on_attach = on_attach,
        filetypes = { "ruby" },
        capabilities = capabilities,
      })

      vim.lsp.config("ruby_lsp", {
        on_attach = on_attach,
        filetypes = { "ruby" },
        capabilities = capabilities,
      })

      -- Deno (for Supabase Edge Functions)
      vim.lsp.config("denols", {
        capabilities = capabilities,
        on_attach = on_attach,
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

      -- Biome (formatting + linting for JS/TS/Svelte)
      vim.lsp.config("biome", {
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          local filetype = vim.bo[bufnr].filetype

          -- Enable formatting for supported filetypes
          if filetype:match "javascript"
            or filetype:match "typescript"
            or filetype == "javascriptreact"
            or filetype == "typescriptreact"
            or filetype == "svelte"
            or filetype == "html"
            or filetype == "css"
            or filetype == "json"
          then
            client.server_capabilities.documentFormattingProvider = true
          end

          on_attach(client, bufnr)
        end,
        filetypes = {
          "javascript",
          "typescript",
          "javascriptreact",
          "typescriptreact",
          "svelte",
          "json",
          "jsonc",
          "css",
          "html",
        },
      })

      -- TypeScript (excluding Deno projects and Svelte files)
      vim.lsp.config("ts_ls", {
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          disable_fmt(client)
          on_attach(client, bufnr)
        end,
        root_markers = { "package.json" },
        filetypes = {
          "typescript",
          "javascript",
          "javascriptreact",
          "typescriptreact",
        },
      })

      -- CSS
      vim.lsp.config("cssls", {
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          disable_fmt(client)
          on_attach(client, bufnr)
        end,
      })

      -- Tailwind
      vim.lsp.config("tailwindcss", {
        capabilities = capabilities,
        on_attach = on_attach,
      })

      -- Svelte
      vim.lsp.config("svelte", {
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          disable_fmt(client)
          on_attach(client, bufnr)
        end,
        filetypes = { "svelte" },
      })

      -- GraphQL
      vim.lsp.config("graphql", {
        capabilities = capabilities,
        on_attach = on_attach,
        filetypes = { "graphql", "gql", "svelte", "typescriptreact", "javascriptreact" },
      })

      -- Emmet
      vim.lsp.config("emmet_ls", {
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          disable_fmt(client)
          on_attach(client, bufnr)
        end,
        filetypes = { "html", "typescriptreact", "javascriptreact", "css", "sass", "scss", "less", "svelte" },
      })

      -- Ruff (Python)
      vim.lsp.config("ruff", {
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          on_attach(client, bufnr)
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

      -- Pyright
      vim.lsp.config("pyright", {
        capabilities = capabilities,
        on_attach = on_attach,
        filetypes = { "python" },
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

      -- Swift
      vim.lsp.config("sourcekit", {
        capabilities = capabilities,
        on_attach = on_attach,
        filetypes = { "swift" },
      })

      -- Lua
      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = {
                [vim.fn.expand "$VIMRUNTIME/lua"] = true,
                [vim.fn.stdpath "config" .. "/lua"] = true,
              },
            },
          },
        },
      })

      -- Enable all configs
      vim.lsp.enable "html"
      vim.lsp.enable "rubocop"
      vim.lsp.enable "ruby_lsp"
      vim.lsp.enable "denols"
      vim.lsp.enable "biome"
      vim.lsp.enable "ts_ls"
      vim.lsp.enable "cssls"
      vim.lsp.enable "tailwindcss"
      vim.lsp.enable "svelte"
      vim.lsp.enable "graphql"
      vim.lsp.enable "emmet_ls"
      vim.lsp.enable "ruff"
      vim.lsp.enable "pyright"
      vim.lsp.enable "sourcekit"
      vim.lsp.enable "lua_ls"
    end)

    if not status then print("Error in LSP configuration:", result) end

    -- Biome: Auto-format and fix on save (defined OUTSIDE on_attach to avoid duplication)
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("BiomeFormat", { clear = true }),
      pattern = { "*.js", "*.jsx", "*.ts", "*.tsx", "*.svelte", "*.json", "*.jsonc", "*.css", "*.html" },
      callback = function(args)
        local clients = vim.lsp.get_clients({ bufnr = args.buf, name = "biome" })
        if #clients == 0 then return end

        -- Run fixAll + organizeImports first (synchronously)
        vim.lsp.buf.code_action({
          context = {
            only = { "source.fixAll", "source.organizeImports" },
            diagnostics = {},
          },
          apply = true,
        })

        -- Then format (synchronously)
        vim.lsp.buf.format({
          bufnr = args.buf,
          filter = function(client) return client.name == "biome" end,
          timeout_ms = 2000,
        })
      end,
    })

    -- Prevent ts_ls from attaching to Supabase functions and Svelte files
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then return end

        local bufname = vim.api.nvim_buf_get_name(args.buf)
        local filetype = vim.bo[args.buf].filetype

        -- Stop ts_ls from Supabase functions
        if client.name == "ts_ls" and bufname:match "supabase/functions" then
          vim.schedule(function() vim.lsp.stop_client(client.id, true) end)
        end

        -- Stop ts_ls from Svelte files
        if client.name == "ts_ls" and filetype == "svelte" then
          vim.schedule(function() vim.lsp.stop_client(client.id, true) end)
        end
      end,
    })
  end,
}
