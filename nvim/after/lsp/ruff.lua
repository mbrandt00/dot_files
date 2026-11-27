-- Ruff lints and formats Python. Format-on-save runs through conform (LSP fallback),
-- so there is no save hook here.
return {
  settings = {
    format = { enabled = true },
    lint = { enabled = true },
    organizeImports = { enabled = true },
  },
}
