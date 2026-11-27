-- Pyright for types, hover and navigation only: Ruff owns lint diagnostics and imports.
return {
  settings = {
    pyright = { disableOrganizeImports = true },
    python = { analysis = { ignore = { "*" } } },
  },
}
