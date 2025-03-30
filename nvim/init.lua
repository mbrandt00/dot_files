vim.g.mapleader = " "
require "michael.lazy"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.wrap = true
vim.opt.textwidth = 90
vim.opt.ignorecase = true
-- vim.opt.softtabstop = 4
-- vim.opt.tabstop = 4
-- vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.clipboard = "unnamed"
vim.api.nvim_set_keymap("n", "<leader>bd", ":bdelete<CR>", { noremap = true })
vim.cmd "hi LineNr guifg=#61afef ctermfg=blue"
vim.cmd "hi CursorLineNr guifg=#61afef ctermfg=blue"

-- functions
local builtin = require "telescope.builtin"

vim.keymap.set(
  "n",
  "<leader>fn",
  function() builtin.find_files { cwd = vim.fn.stdpath "config" } end,
  { desc = "[F]ind in [N]eovim config" }
)
vim.cmd [[
augroup highlight_yank
autocmd!
au TextYankPost * silent! lua vim.highlight.on_yank({higroup="Visual", timeout=400})
augroup END
]]
vim.keymap.set("n", "<leader>r", "<cmd>source $MYVIMRC<CR>", { silent = true, desc = "Reload config" })

-- Map Alt+j to move down the quickfix list
vim.keymap.set("n", "<A-j>", "<cmd>cnext<CR>", { noremap = true, silent = true, desc = "Next item in quickfix list" })

-- Map Alt+k to move up the quickfix list
vim.keymap.set(
  "n",
  "<A-k>",
  "<cmd>cprev<CR>",
  { noremap = true, silent = true, desc = "Previous item in quickfix list" }
)

vim.keymap.set("n", "<A-q>", "<cmd>copen<CR>", { noremap = true, silent = true, desc = "Open quickfix list" })
vim.keymap.set("n", "<A-c>", "<cmd>cclose<CR>", { noremap = true, silent = true, desc = "Close quickfix list" })

-- black hole register mapping
vim.api.nvim_set_keymap("n", "<leader><leader>d", '"_d', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader><leader>c", '"_c', { noremap = true, silent = true })

vim.api.nvim_create_user_command("SvelteCheck", function()
  -- Find the project root with package.json
  local handle = io.popen 'find . -name "package.json" -type f -not -path "*/node_modules/*" | head -n 1'
  local package_json_path = handle:read("*a"):gsub("%s+$", "")
  handle:close()
  if package_json_path == "" then
    vim.notify("No package.json found in current directory or subdirectories", vim.log.levels.ERROR, { timeout = 3000 })
    return
  end
  -- Get the directory containing package.json
  local project_dir = vim.fn.fnamemodify(package_json_path, ":h")
  -- Save current directory
  local current_dir = vim.fn.getcwd()
  -- Change to project directory
  vim.cmd("cd " .. project_dir)

  -- Redirect stderr to /dev/null to ignore the bundling warning message
  -- and only capture actual errors in errors.txt
  os.execute "npm run check:qf 2>/dev/null"

  -- Check if errors.txt exists and has content
  local error_file = io.open("errors.txt", "r")
  if error_file then
    local content = error_file:read "*all"
    error_file:close()

    -- Try to determine if the content contains actual errors or just warnings
    -- Ignore the bundling conditions message
    if content and #content > 0 and not content:match "conditions should include development or production" then
      -- Load the quickfix file
      vim.cmd "cfile errors.txt"
      vim.cmd "copen" -- Open the quickfix window
      -- Show a temporary message that will disappear
      vim.notify("Loaded TypeScript errors into quickfix list", vim.log.levels.INFO, { timeout = 3000 })
    else
      -- No errors found or only the bundling warning
      -- Show a temporary message that will disappear
      vim.notify("No TypeScript errors found!", vim.log.levels.INFO, { timeout = 3000 })
    end
  else
    -- Show a temporary error message
    vim.notify(
      "Error file not created. Check if the svelte-check command ran correctly.",
      vim.log.levels.ERROR,
      { timeout = 3000 }
    )
  end
  -- Change back to original directory
  vim.cmd("cd " .. current_dir)
end, {})

vim.api.nvim_create_user_command("RspecCheck", function()
  -- Find the project root by looking for a more specific Rails project indicator
  local handle = io.popen 'find . -name "Gemfile" -type f -not -path "*/.ruby-lsp/*" | head -n 1'
  local gemfile_path = handle:read("*a"):gsub("%s+$", "")
  handle:close()

  if gemfile_path == "" then
    vim.notify("No Gemfile found in current directory or subdirectories", vim.log.levels.ERROR, { timeout = 3000 })
    return
  end

  -- Get the directory containing Gemfile
  local project_dir = vim.fn.fnamemodify(gemfile_path, ":h")

  -- Verify this is a Rails project with RSpec
  local spec_dir_check = io.popen('test -d "' .. project_dir .. '/spec" && echo "yes" || echo "no"')
  local has_spec_dir = spec_dir_check:read("*a"):gsub("%s+$", "")
  spec_dir_check:close()

  if has_spec_dir ~= "yes" then
    vim.notify(
      "No spec directory found in " .. project_dir .. ". This may not be a Rails project with RSpec.",
      vim.log.levels.ERROR,
      { timeout = 3000 }
    )
    return
  end

  -- Save current directory
  local current_dir = vim.fn.getcwd()

  -- Change to project directory
  vim.cmd("cd " .. project_dir)

  vim.notify("Running RSpec in " .. project_dir, vim.log.levels.INFO, { timeout = 2000 })

  -- Create a temporary file for output
  local temp_file = os.tmpname()

  -- Run RSpec with basic command to capture all output
  local cmd = "RAILS_ENV=test bundle exec rspec > " .. temp_file .. " 2>&1"
  local exit_code = os.execute(cmd)

  -- Read the output
  local output_file = io.open(temp_file, "r")
  if not output_file then
    vim.notify("Failed to open output file", vim.log.levels.ERROR, { timeout = 3000 })
    vim.cmd("cd " .. current_dir)
    os.remove(temp_file) -- Try to clean up
    return
  end

  local output = output_file:read "*all"
  output_file:close()
  os.remove(temp_file) -- Clean up

  -- Create a quickfix list
  local qf_entries = {}

  -- Process the output to find failures
  -- Based on the sample output, we need to look for patterns like:
  -- 1) Player class methods .upsert_domestic_amateur_player will create a new ama player from GQL endpoint
  --    Failure/Error: school = create(:school, id: 5)
  --    NoMethodError:
  --      undefined method `school_id=' for an instance of School

  local current_failure_index = 0
  local current_test_name = nil
  local current_file = nil
  local current_line = nil
  local current_error_type = nil
  local current_error_message = nil
  local in_failure_block = false
  local in_stack_trace = false
  local stack_trace_lines = {}

  for line in output:gmatch "[^\r\n]+" do
    -- Check for the failure header (numbered failure)
    if line:match "^%s*%d+%)%s+" then
      current_failure_index = current_failure_index + 1
      current_test_name = line:match "^%s*%d+%)%s+(.*)"
      in_failure_block = true
      stack_trace_lines = {}

    -- Look for the Failure/Error line
    elseif in_failure_block and line:match "^%s*Failure/Error:" then
      current_error_message = line:match "^%s*Failure/Error:%s*(.*)"

    -- Look for the error type
    elseif in_failure_block and line:match "^%s*[%w:]+Error:" and not current_error_type then
      current_error_type = line:match "^%s*([%w:]+Error):"
      current_error_message = line:match "^%s*[%w:]+Error:%s*(.*)"

    -- Look for file references in stack traces
    elseif in_failure_block and line:match "^%s*#%s+" then
      in_stack_trace = true
      table.insert(stack_trace_lines, line)

      -- Try to extract file path and line number from stack trace
      local file_path, line_num = line:match "([^:]+):(%d+):in"
      if file_path and line_num and file_path:match "spec/" then
        -- Found a spec file in the stack trace
        current_file = file_path
        current_line = line_num
      end

    -- End of error block or start of a new one
    elseif in_failure_block and line:match "^$" then
      -- Empty line, might be end of a failure block
      if current_test_name and current_file and current_line then
        -- Build error message
        local message = current_test_name
        if current_error_type then message = message .. " (" .. current_error_type .. ")" end
        if current_error_message then message = message .. ": " .. current_error_message end

        -- Add to quickfix list
        table.insert(qf_entries, {
          filename = current_file,
          lnum = tonumber(current_line),
          text = message,
        })

        -- Reset for next failure
        current_test_name = nil
        current_file = nil
        current_line = nil
        current_error_type = nil
        current_error_message = nil
      end

      in_stack_trace = false
    end

    -- Look for the 'rspec ./path/to/file.rb:123' pattern in the Failed examples section
    if line:match "^rspec%s+" then
      local file_path, line_num = line:match "rspec%s+(.+):(%d+)"
      if file_path and line_num then
        -- Check if we already have this failure in our quickfix list
        local found = false
        for _, entry in ipairs(qf_entries) do
          if entry.filename == file_path and entry.lnum == tonumber(line_num) then
            found = true
            break
          end
        end

        -- If not found, add it with default message
        if not found then
          local test_desc = line:match "rspec%s+.+:%d+%s+#%s+(.*)"
          table.insert(qf_entries, {
            filename = file_path,
            lnum = tonumber(line_num),
            text = test_desc or "Test failure",
          })
        end
      end
    end
  end

  -- Set the quickfix list
  if #qf_entries > 0 then
    vim.fn.setqflist(qf_entries, "r")
    vim.cmd "copen"
    vim.notify(
      "Loaded " .. #qf_entries .. " RSpec failures into quickfix list",
      vim.log.levels.INFO,
      { timeout = 3000 }
    )
  else
    if exit_code == 0 then
      vim.notify("All RSpec tests passed!", vim.log.levels.INFO, { timeout = 3000 })
    else
      -- If we couldn't parse any failures but tests failed, show full output
      vim.cmd "botright new"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(output, "\n"))
      vim.api.nvim_buf_set_option(0, "buftype", "nofile")
      vim.api.nvim_buf_set_option(0, "swapfile", false)
      vim.api.nvim_buf_set_name(0, "RSpec Output")
      vim.api.nvim_buf_set_keymap(0, "n", "q", ":q<CR>", { noremap = true, silent = true })

      vim.notify(
        "RSpec failed but couldn't parse failures. Showing full output in buffer.",
        vim.log.levels.WARN,
        { timeout = 3000 }
      )
    end
  end

  -- Change back to original directory
  vim.cmd("cd " .. current_dir)
end, {})
