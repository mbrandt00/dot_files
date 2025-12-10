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

    -- Set up keymaps on LspAttach (more reliable than on_attach in config)
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspConfig", {}),
      callback = function(ev)
        local opts = { buffer = ev.buf, noremap = true, silent = true }

        opts.desc = "Show LSP references"
        vim.keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", opts)

        opts.desc = "Go to declaration"
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

        opts.desc = "Show LSP definitions"
        vim.keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts)

        opts.desc = "Show LSP type definitions"
        vim.keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts)

        opts.desc = "See available code actions"
        vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

        opts.desc = "Smart rename"
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

        opts.desc = "Show buffer diagnostics"
        vim.keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts)

        opts.desc = "Show line diagnostics"
        vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

        opts.desc = "Go to previous diagnostic"
        vim.keymap.set("n", "[d", vim.diagnostic.get_prev, opts)

        opts.desc = "Go to next diagnostic"
        vim.keymap.set("n", "]d", vim.diagnostic.get_next, opts)

        opts.desc = "Show documentation for what is under cursor"
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

        opts.desc = "Restart LSP"
        vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)
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

      -- Biome: selective formatting per filetype
      vim.lsp.config("biome", {
        capabilities = shared.capabilities,
        on_attach = function(client, bufnr)
          local filetype = vim.bo[bufnr].filetype
          if
            filetype:match "javascript"
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
      })

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

      -- Enable all LSP servers
      vim.lsp.enable {
        "html",
        "rubocop",
        "ruby_lsp",
        "denols",
        "biome",
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
    end)

    if not status then print("Error in LSP configuration:", result) end
  end,
}
