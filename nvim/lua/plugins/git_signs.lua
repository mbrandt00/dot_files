return {
  "lewis6991/gitsigns.nvim",
  config = function()
    local gitsigns = require "gitsigns"

    -- gitsigns links its inline word-diff groups to TermCursor by default, which
    -- renders as an unreadable tan/brown block on top of the diff line background
    -- (only visible on *modified* lines, never on pure additions). gruvbox-material
    -- ships a theme-aware emphasis group, DiffText, that recolors itself for light
    -- and dark, so relink the inline groups to it. Done via a ColorScheme autocmd
    -- because :colorscheme wipes all highlights on every theme toggle.
    local function fix_diff_highlights()
      for _, group in ipairs { "GitSignsAddInline", "GitSignsChangeInline", "GitSignsDeleteInline" } do
        vim.api.nvim_set_hl(0, group, { link = "DiffText" })
      end
    end
    vim.api.nvim_create_autocmd("ColorScheme", { callback = fix_diff_highlights })
    fix_diff_highlights()

    gitsigns.setup {
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map("n", "]c", function()
          if vim.wo.diff then return "]c" end
          vim.schedule(function() gs.next_hunk() end)
          return "<Ignore>"
        end, { expr = true })

        map("n", "[c", function()
          if vim.wo.diff then return "[c" end
          vim.schedule(function() gs.prev_hunk() end)
          return "<Ignore>"
        end, { expr = true })

        -- Actions
        map("n", "<leader>hs", gs.stage_hunk)
        map("n", "<leader>hr", gs.reset_hunk)
        map("v", "<leader>hs", function() gs.stage_hunk { vim.fn.line ".", vim.fn.line "v" } end)
        map("v", "<leader>hr", function() gs.reset_hunk { vim.fn.line ".", vim.fn.line "v" } end)
        map("n", "<leader>hS", gs.stage_buffer)
        map("n", "<leader>hu", gs.undo_stage_hunk)
        map("n", "<leader>hR", gs.reset_buffer)
        map("n", "<leader>hp", gs.preview_hunk)
        map("n", "<leader>hb", function() gs.blame_line { full = true } end)
        map("n", "<leader>tb", gs.toggle_current_line_blame)
        map("n", "<leader>hd", gs.diffthis)
        map("n", "<leader>hD", function() gs.diffthis "~" end)
        -- map("n", "<leader>td", gs.toggle_deleted)

        -- Text object
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
      end,
    }
  end,
}
