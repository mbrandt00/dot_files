#!/usr/bin/env bash
# tmux-fingers alt-action: a file opens in nvim in a new tmux window (path:line[:col] jumps to
# the line), a folder opens in Finder, anything else falls through to fingers-open.sh.
# Fingers runs this from the original pane's cwd, so relative paths resolve against it.
match=$(cat)

path=$match
# Drop sentence punctuation the path pattern swallows ("see foo/bar.txt.").
while [[ $path =~ [.,\;:\)]$ && ! -e $path ]]; do path=${path%?}; done
line=
if [[ $path =~ ^([^:]+):([0-9]+)(:[0-9]+)?$ ]]; then
  path=${BASH_REMATCH[1]} line=${BASH_REMATCH[2]}
fi
[[ $path == "~"* ]] && path=$HOME${path:1}
# Expand a leading $VAR or ${VAR} (e.g. $TMPDIR/foo, $HOME/bar).
if [[ $path =~ ^\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?(.*)$ && -n ${!BASH_REMATCH[1]} ]]; then
  base=${!BASH_REMATCH[1]}
  path=${base%/}${BASH_REMATCH[2]}
fi

if [[ -d $path ]]; then
  exec open "$path"
elif [[ -f $path ]]; then
  nvim=$(command -v nvim || echo /opt/homebrew/bin/nvim)
  exec tmux new-window -c "$PWD" -n "${path##*/}" "$nvim" ${line:++$line} "$path"
fi
exec "$HOME/.config/tmux/fingers-open.sh" <<<"$match"
