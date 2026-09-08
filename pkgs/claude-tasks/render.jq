# Render a Claude Code task list (slurped array of ~/.claude/tasks/<list>/N.json)
# as ANSI-colored lines. Args: $name (list dir basename), $now (HH:MM of the last
# change), $cols (terminal width).
def esc: "\u001b[";
def reset: esc + "0m";
def bold: esc + "1m";
def dim: esc + "2m";
def strike: esc + "9m";
def green: esc + "32m";
def yellow: esc + "33m";
def trunc($n): if length > $n then .[:($n - 1)] + "…" else . end;

sort_by(.id | tonumber) as $tasks
| ($tasks | map(select(.status == "completed")) | length) as $done
| ($tasks | length) as $total
| ($tasks | map({ key: .id, value: .status }) | from_entries) as $status
| ($cols - 4) as $w
| [
    " " + bold + "tasks" + reset + dim + " · " + $name + " · " + reset
      + "\($done)/\($total) done" + dim + " · " + $now + reset,
    ""
  ]
  + ($tasks | map(
      ((.blockedBy // []) | map(select($status[.] != null and $status[.] != "completed"))) as $open
      | (if ($open | length) > 0
         then dim + "  ⇠ blocked by " + ($open | map("#" + .) | join(", ")) + reset
         else "" end) as $blocked
      | if .status == "completed" then
          " " + green + "✓" + reset + " " + dim + strike + (.subject | trunc($w)) + reset
        elif .status == "in_progress" then
          " " + yellow + "▶" + reset + " " + bold + (.subject | trunc($w)) + reset
            + (if (.activeForm // "") != "" then dim + "  " + .activeForm + reset else "" end)
        else
          " ○ " + (.subject | trunc($w)) + $blocked
        end))
| .[]
