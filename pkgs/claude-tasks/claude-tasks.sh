# Live view of a Claude Code task list — the TaskCreate/TaskUpdate checklist
# Claude keeps under ~/.claude/tasks/<list>/N.json. Ctrl+T inside Claude Code
# shows at most five rows and folds finished items into "+N completed"; this
# prints every task and redraws on change, so it works as a tmux side pane.

root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tasks"
once=0
follow=0
interval=1
target="${CLAUDE_CODE_TASK_LIST_ID:-}"

usage() {
  cat <<USAGE
usage: claude-tasks [-1|--once] [-f|--follow] [-i SECS] [LIST]

LIST   session id (full or first 8 chars) or a CLAUDE_CODE_TASK_LIST_ID name.
       Default: the list with the most recently changed task, resolved once
       at startup (\$CLAUDE_CODE_TASK_LIST_ID wins when set).
-f     re-resolve to the most recently changed list on every tick
-1     print once and exit
-i     poll interval in seconds (default 1)
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -1 | --once) once=1 ;;
    -f | --follow) follow=1 ;;
    -i | --interval)
      interval="$2"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "claude-tasks: unknown option $1" >&2
      usage >&2
      exit 2
      ;;
    *) target="$1" ;;
  esac
  shift
done

resolve_dir() {
  if [ -n "$target" ]; then
    for d in "$root/$target" "$root/session-$target" "$root/session-${target:0:8}"; do
      if [ -d "$d" ]; then
        echo "$d"
        return
      fi
    done
    echo "claude-tasks: no task list '$target' under $root" >&2
    exit 1
  fi
  # Newest task file across all lists decides the active session. ls -t is
  # the only portable (BSD + GNU) mtime sort; names are always N.json.
  local newest
  # shellcheck disable=SC2012
  newest=$(ls -t "$root"/*/*.json 2>/dev/null | head -n 1 || true)
  if [ -n "$newest" ]; then
    dirname "$newest"
  fi
}

task_files() {
  local dir="$1"
  if [ -n "$dir" ]; then
    find "$dir" -maxdepth 1 -name '*.json' | sort
  fi
}

render() {
  local dir="$1" files cols
  files=$(task_files "$dir")
  if [ -z "$files" ]; then
    printf ' \033[2mno tasks\033[0m\n'
    return
  fi
  cols=$(tput cols 2>/dev/null || echo 80)
  # shellcheck disable=SC2086
  jq -rs --arg name "${dir##*/}" --arg now "$(date +%H:%M)" --argjson cols "$cols" \
    -f "$RENDER_JQ" $files
}

dir=$(resolve_dir)

if [ "$once" = 1 ]; then
  render "$dir"
  exit 0
fi

tput civis 2>/dev/null || true
trap 'tput cnorm 2>/dev/null || true; exit 0' INT TERM
last=""
while :; do
  if [ "$follow" = 1 ] || [ -z "$dir" ]; then
    dir=$(resolve_dir)
  fi
  files=$(task_files "$dir")
  # Content checksum, not mtimes: mtime granularity misses same-second edits.
  # shellcheck disable=SC2086
  sig="$dir $(cat $files 2>/dev/null | cksum)"
  if [ "$sig" != "$last" ]; then
    tput clear 2>/dev/null || printf '\033[H\033[2J'
    render "$dir"
    last=$sig
  fi
  sleep "$interval"
done
