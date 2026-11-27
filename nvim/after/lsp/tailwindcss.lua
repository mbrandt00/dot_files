-- Skip Claude Code worktrees during project discovery: they lack .svelte-kit/, so their
-- tsconfig "extends" fails on every server start. files.exclude replaces the defaults,
-- so those are repeated here.
return {
  settings = {
    tailwindCSS = {
      files = {
        exclude = { "**/.git/**", "**/node_modules/**", "**/.hg/**", "**/.svn/**", "**/.claude/**" },
      },
    },
  },
}
