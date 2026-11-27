#!/usr/bin/env bash
# The dev server's tmux menus.
#   prefix+S:     server-menu.sh DIR CLIENT          go to the "server" session; from a blake-street
#                 checkout the server isn't running in, a menu offers go there / move it here.
#   status click: server-menu.sh --info DIR CLIENT   full branch, path and actions.
# Either starts the server if absent.
info=
[[ $1 == --info ]] && { info=1; shift; }
dir=$1 client=$2
main=$HOME/work/blake-street
switch=$HOME/.local/bin/server-switch

here=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
# Only blake-street checkouts share the main checkout's git dir; other windows just jump.
ours=1
if [[ -z $here || $(git -C "$here" rev-parse --path-format=absolute --git-common-dir) != "$main/.git" ]]; then
  here=$main ours=
fi

name() { local b; b=$(git -C "$1" branch --show-current 2>/dev/null); echo "${b:-${1##*/}}"; }
menu() { tmux display-menu -c "$client" -x "${x:-C}" -y "${y:-C}" "$@"; }
[[ -n $info ]] && x=R y=S

if ! tmux has-session -t '=server' 2>/dev/null; then
  if [[ -n $info ]]; then
    menu -T " Server not running " "Start server in $(name "$here")" s "run-shell -b \"'$switch' '$here'\""
  else
    "$switch" "$here" && tmux switch-client -c "$client" -t '=server'
  fi
  exit 0
fi

server=$(tmux show -gv @server_path 2>/dev/null)
moveable=
[[ -n $ours && $server != "$here" ]] && moveable=1

if [[ -z $info ]]; then
  if [[ -z $moveable ]]; then
    tmux switch-client -c "$client" -t '=server'
  else
    menu -T " Server is on $(name "$server") " \
      "Go to server" g "switch-client -t '=server'" \
      "Move server here ($(name "$here"))" m "run-shell -b \"'$switch' '$here'\""
  fi
  exit 0
fi

state=$(tmux show -gv @server_state 2>/dev/null)
[[ $(tmux list-panes -s -t '=server' -F '#{pane_dead}') == *1* ]] && state=stopped
branch=$(name "$server")
items=(
  "-Branch  $branch" "" ""
  "-Path    ${server/#"$HOME"/\~}" "" ""
  ""
  "Go to server" g "switch-client -t '=server'"
)
[[ -n $moveable ]] && items+=("Move server here ($(name "$here"))" m "run-shell -b \"'$switch' '$here'\"")
items+=("Restart" r "run-shell -b \"'$switch' -f '$server'\"")
[[ $state == running ]] && items+=("Stop" s "send-keys -t '=server:' C-c")
items+=("" "Copy branch name" c "run-shell \"printf %s '$branch' | pbcopy\" ; display-message 'copied $branch'")
menu -T " Dev server · ${state:-running} " -- "${items[@]}"
