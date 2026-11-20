#!/bin/bash
config_file="$HOME/.claude/statusline-config.txt"
if [ -f "$config_file" ]; then
  source "$config_file"
  show_worktree=${SHOW_WORKTREE:-1}
  show_dir=${SHOW_DIRECTORY:-0}
  show_branch=${SHOW_BRANCH:-1}
  show_context=${SHOW_CONTEXT:-1}
  show_context_bar=${SHOW_CONTEXT_BAR:-1}
  show_usage=${SHOW_USAGE:-0}
  show_bar=${SHOW_PROGRESS_BAR:-1}
  show_reset=${SHOW_RESET_TIME:-0}
else
  show_worktree=1
  show_dir=0
  show_branch=1
  show_context=1
  show_context_bar=1
  show_usage=0
  show_bar=1
  show_reset=0
fi

input=$(cat)
current_dir_path=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | sed 's/"current_dir":"//;s/"$//')
current_dir=$(basename "$current_dir_path")
# Run git from the session's working directory so worktree/branch resolve correctly.
[ -n "$current_dir_path" ] && cd "$current_dir_path" 2>/dev/null

BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
GREEN=$'\033[0;32m'
GRAY=$'\033[0;90m'
YELLOW=$'\033[0;33m'
RESET=$'\033[0m'

# 10-level gradient: dark green (low) → deep red (high)
LEVEL_1=$'\033[38;5;22m'   # dark green
LEVEL_2=$'\033[38;5;28m'   # soft green
LEVEL_3=$'\033[38;5;34m'   # medium green
LEVEL_4=$'\033[38;5;100m'  # green-yellowish dark
LEVEL_5=$'\033[38;5;142m'  # olive/yellow-green dark
LEVEL_6=$'\033[38;5;178m'  # muted yellow
LEVEL_7=$'\033[38;5;172m'  # muted yellow-orange
LEVEL_8=$'\033[38;5;166m'  # darker orange
LEVEL_9=$'\033[38;5;160m'  # dark red
LEVEL_10=$'\033[38;5;124m' # deep red

# gradient_color <pct> -> echoes the ANSI color for that 0-100 level
gradient_color() {
  local pct=$1
  if   [ "$pct" -le 10 ]; then printf '%s' "$LEVEL_1"
  elif [ "$pct" -le 20 ]; then printf '%s' "$LEVEL_2"
  elif [ "$pct" -le 30 ]; then printf '%s' "$LEVEL_3"
  elif [ "$pct" -le 40 ]; then printf '%s' "$LEVEL_4"
  elif [ "$pct" -le 50 ]; then printf '%s' "$LEVEL_5"
  elif [ "$pct" -le 60 ]; then printf '%s' "$LEVEL_6"
  elif [ "$pct" -le 70 ]; then printf '%s' "$LEVEL_7"
  elif [ "$pct" -le 80 ]; then printf '%s' "$LEVEL_8"
  elif [ "$pct" -le 90 ]; then printf '%s' "$LEVEL_9"
  else printf '%s' "$LEVEL_10"
  fi
}

# progress_bar <pct> -> echoes a leading-space 10-block ▓/░ bar
make_bar() {
  local pct=$1 filled empty i bar=" "
  if   [ "$pct" -le 0 ];   then filled=0
  elif [ "$pct" -ge 100 ]; then filled=10
  else filled=$(( (pct * 10 + 50) / 100 )); fi
  [ "$filled" -lt 0 ]  && filled=0
  [ "$filled" -gt 10 ] && filled=10
  empty=$((10 - filled))
  i=0; while [ $i -lt $filled ]; do bar="${bar}▓"; i=$((i + 1)); done
  i=0; while [ $i -lt $empty ];  do bar="${bar}░"; i=$((i + 1)); done
  printf '%s' "$bar"
}

# --- Work tree (root of the git worktree, not the nested cwd) ---
worktree_text=""
if [ "$show_worktree" = "1" ]; then
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$toplevel" ]; then
    worktree_text="${CYAN}$(basename "$toplevel")${RESET}"
  elif [ -n "$current_dir" ]; then
    worktree_text="${CYAN}${current_dir}${RESET}"
  fi
fi

# --- Working directory basename (off by default; the nested cwd) ---
dir_text=""
if [ "$show_dir" = "1" ] && [ -n "$current_dir" ]; then
  dir_text="${BLUE}${current_dir}${RESET}"
fi

# --- Git branch ---
branch_text=""
if [ "$show_branch" = "1" ]; then
  if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    [ -n "$branch" ] && branch_text="${GREEN}⎇ ${branch}${RESET}"
  fi
fi

# --- Context window used % (from the JSON Claude Code pipes in via stdin) ---
context_text=""
if [ "$show_context" = "1" ]; then
  ctx_pct=$(echo "$input" | jq -r '(.context_window.used_percentage // empty) | floor' 2>/dev/null)
  if [ -n "$ctx_pct" ]; then
    ctx_color=$(gradient_color "$ctx_pct")
    if [ "$show_context_bar" = "1" ]; then
      ctx_bar=$(make_bar "$ctx_pct")
    else
      ctx_bar=""
    fi
    context_text="${ctx_color}Ctx: ${ctx_pct}%${ctx_bar}${RESET}"
  else
    context_text="${GRAY}Ctx: --${RESET}"
  fi
fi

# --- 5-hour quota usage (off by default; hits Claude usage API via Swift) ---
usage_text=""
if [ "$show_usage" = "1" ]; then
  swift_result=$(swift "$HOME/.claude/fetch-claude-usage.swift" 2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$swift_result" ]; then
    utilization=$(echo "$swift_result" | cut -d'|' -f1)
    resets_at=$(echo "$swift_result" | cut -d'|' -f2)

    if [ -n "$utilization" ] && [ "$utilization" != "ERROR" ]; then
      usage_color=$(gradient_color "$utilization")

      if [ "$show_bar" = "1" ]; then
        progress_bar=$(make_bar "$utilization")
      else
        progress_bar=""
      fi

      reset_time_display=""
      if [ "$show_reset" = "1" ] && [ -n "$resets_at" ] && [ "$resets_at" != "null" ]; then
        iso_time=$(echo "$resets_at" | sed 's/\.[0-9]*Z$//')
        epoch=$(date -ju -f "%Y-%m-%dT%H:%M:%S" "$iso_time" "+%s" 2>/dev/null)

        if [ -n "$epoch" ]; then
          time_format=$(defaults read -g AppleICUForce24HourTime 2>/dev/null)
          if [ "$time_format" = "1" ]; then
            reset_time=$(date -r "$epoch" "+%H:%M" 2>/dev/null)
          else
            reset_time=$(date -r "$epoch" "+%I:%M %p" 2>/dev/null)
          fi
          [ -n "$reset_time" ] && reset_time_display=$(printf " → Reset: %s" "$reset_time")
        fi
      fi

      usage_text="${usage_color}Usage: ${utilization}%${progress_bar}${reset_time_display}${RESET}"
    else
      usage_text="${YELLOW}Usage: ~${RESET}"
    fi
  else
    usage_text="${YELLOW}Usage: ~${RESET}"
  fi
fi

# --- Assemble, inserting a separator only between non-empty components ---
output=""
separator="${GRAY} │ ${RESET}"
append() {
  [ -z "$1" ] && return
  [ -n "$output" ] && output="${output}${separator}"
  output="${output}$1"
}

append "${YELLOW}work${RESET}"
append "$worktree_text"
append "$dir_text"
append "$branch_text"
append "$context_text"
append "$usage_text"

printf "%s\n" "$output"
