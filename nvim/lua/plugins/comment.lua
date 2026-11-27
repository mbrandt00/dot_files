-- Commenting is built in (gc/gcc). Native gc reads the comment style for the treesitter
-- language under the cursor via vim.filetype.get_option(), which only knows one style per
-- filetype ("//" for tsx). Answering 'commentstring' from the node under the cursor gives
-- {/* */} inside JSX and leaves every other option lookup alone.
return {
  "JoosepAlviste/nvim-ts-context-commentstring",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("ts_context_commentstring").setup { enable_autocmd = false }
    local get_option = vim.filetype.get_option
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.filetype.get_option = function(filetype, option)
      if option == "commentstring" then
        local cs = require("ts_context_commentstring.internal").calculate_commentstring()
        if cs then return cs end
      end
      return get_option(filetype, option)
    end
  end,
}
