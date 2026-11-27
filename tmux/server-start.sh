#!/usr/bin/env zsh
# Runs in the tmux "server" session. Starts mise dev in a checkout (arg 1, default the main one),
# logging in to AWS SSO first if the token has expired and installing deps if the lockfile moved.
# When it stops, offers restart / switch worktree / close instead of a dead pane.
main=$HOME/work/blake-street
dir=${1:-$main}
# A handler (not an ignore) so Ctrl-C still stops mise dev but not this loop.
trap 'true' INT

while true; do
  tmux set -g @server_path "$dir"
  tmux set -g @server_dir "${dir:t}"
  tmux set -g @server_state running
  (
    cd "$dir" || exit 1
    aws sts get-caller-identity --profile rockies-dev >/dev/null 2>&1 ||
      BROWSER=$HOME/.config/tmux/brave-work.sh mise sso || exit 1
    if [[ ! -d node_modules || pnpm-lock.yaml -nt node_modules/.modules.yaml ]]; then
      pnpm install --frozen-lockfile || exit 1
    fi
    mise dev
  )
  tmux set -g @server_state stopped
  print -P "\n%F{yellow}mise dev stopped%f in %B${dir:t}%b"
  read -k1 "key?[r] restart  [w] switch worktree  [q] close  "
  print
  case $key in
    w)
      new=$(git -C "$main" worktree list --porcelain | awk '/^worktree /{print substr($0, 10)}' |
        command grep -v '/.claude/worktrees/' | fzf --reverse --height 40% --prompt 'worktree> ')
      [[ -n $new ]] && dir=$new ;;
    q)
      tmux set -gu @server_state
      tmux switch-client -l 2>/dev/null
      tmux kill-session -t '=server' ;;
  esac
done
