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
    -- Load shared configuration
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
      -- Load individual LSP server configurations
      require "plugins.lsp.ts_ls"
      require "plugins.lsp.denols"
      require "plugins.lsp.graphql"
      require "plugins.lsp.lua_ls"

      -- TODO: Move these to individual files following the ts_ls pattern
      -- For now, keeping them inline until migration is complete

      -- HTML
      vim.lsp.config("html", {
        capabilities = shared.capabilities,
        on_attach = function(client, bufnr)
          shared.disable_fmt(client)
          shared.on_attach(client, bufnr)
        end,
      })

      -- Ruby
      vim.lsp.config("rubocop", {
        on_attach = shared.on_attach,
        filetypes = { "ruby" },
        capabilities = shared.capabilities,
      })

      vim.lsp.config("ruby_lsp", {
        on_attach = shared.on_attach,
        filetypes = { "ruby" },
        capabilities = shared.capabilities,
      })

      -- Biome (formatting + linting for JS/TS/Svelte)
      vim.lsp.config("biome", {
        capabilities = shared.capabilities,
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

          shared.on_attach(client, bufnr)
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

      -- CSS
      vim.lsp.config("cssls", {
        capabilities = shared.capabilities,
        on_attach = function(client, bufnr)
          shared.disable_fmt(client)
          shared.on_attach(client, bufnr)
        end,
      })

      -- Tailwind
      vim.lsp.config("tailwindcss", {
        capabilities = shared.capabilities,
        on_attach = shared.on_attach,
      })

      -- Svelte
      vim.lsp.config("svelte", {
        capabilities = shared.capabilities,
        on_attach = function(client, bufnr)
          shared.disable_fmt(client)
          shared.on_attach(client, bufnr)
        end,
        filetypes = { "svelte" },
      })

      -- Emmet
      vim.lsp.config("emmet_ls", {
        capabilities = shared.capabilities,
        on_attach = function(client, bufnr)
          shared.disable_fmt(client)
          shared.on_attach(client, bufnr)
        end,
        filetypes = { "html", "typescriptreact", "javascriptreact", "css", "sass", "scss", "less", "svelte" },
      })

      -- Ruff (Python)
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

      -- Pyright
      vim.lsp.config("pyright", {
        capabilities = shared.capabilities,
        on_attach = shared.on_attach,
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
        capabilities = shared.capabilities,
        on_attach = shared.on_attach,
        filetypes = { "swift" },
      })

      -- Enable all LSP servers
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
  end,
}
