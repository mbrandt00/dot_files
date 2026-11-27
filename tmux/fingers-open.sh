#!/usr/bin/env bash
# tmux-fingers ctrl-action: URLs picked in a pane under ~/work open in Brave's Work profile;
# everything else goes to macOS open, like the built-in :open:.
match=$(cat)
dir=$(tmux display -p '#{pane_current_path}')
if [[ $match == http*://* && $dir == "$HOME/work"* ]]; then
  exec "$HOME/.config/tmux/brave-work.sh" "$match"
fi
exec open "$match"
