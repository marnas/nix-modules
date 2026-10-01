# Format the cached /api/oauth/usage response (raw, as returned by the API)
# into the tmux widget text, e.g.
#   "Session: 54.0% 4h 21m | Fable: 100% 19h 5m" (countdowns dimmed)
#
# The reset countdowns are derived at render time from the absolute
# resets_at, so they tick down on every redraw between fetches. If the 5h
# resets_at has passed — meaning no fetch has succeeded since the block rolled
# over — the cached numbers describe a dead block, so render an explicit
# staleness marker rather than a plausible-but-wrong figure; the next
# successful fetch replaces it.
#
# Per-model weekly segments come from the (undocumented) limits[] array: one
# weekly_scoped entry per model with its own cap, labelled by
# scope.model.display_name. Missing or expired entries are simply omitted.
# Segments are colored by the API's severity; the caller wraps the widget in
# its base color (#EBCB8B), which segments restore after themselves.
# Countdown: "2d 4h", "4h 21m", "4h", "42m", "<1m".
def fmt($mins):
  if $mins < 1 then "<1m"
  elif $mins >= 1440 then "\($mins / 1440 | floor)d \(($mins % 1440) / 60 | floor)h"
  else ($mins / 60 | floor) as $h
  | ($mins % 60) as $m
  | if $h == 0 then "\($m)m"
    elif $m == 0 then "\($h)h"
    else "\($h)h \($m)m"
    end
  end;

# Reset-countdown suffix shared by every segment, dimmed so the percentage
# stands out while keeping the segment's hue.
def reset($mins): " #[dim]\(fmt($mins))#[nodim]";

# UTC ISO8601 with fractional seconds and +00:00 offset → minutes from now.
def mins_until:
  (sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) - now
  | . / 60 | floor;

def color($sev; $s):
  if $sev == "critical" then "#[fg=#BF616A]\($s)#[fg=#EBCB8B]"
  elif $sev == "warning" then "#[fg=#D08770]\($s)#[fg=#EBCB8B]"
  else $s
  end;

(.limits // []) as $limits

| ($limits | map(select(.kind == "session")) | first | .severity // null) as $session_sev

| (if .five_hour == null then
    # No active block (no usage since the last one expired).
    "Session: 0.0%"
  else
    # One-decimal percent without a printf float (matches toFixed(1)).
    ((.five_hour.utilization // 0) * 10 | round) as $t
    | "Session: \($t / 10 | floor).\($t % 10)%" as $pct
    | (.five_hour.resets_at // null) as $r
    | if $r == null then color($session_sev; $pct)
      else
        ($r | mins_until) as $mins
        | if $mins < 0 then "usage: stale"
          else color($session_sev; $pct + reset($mins))
          end
      end
  end) as $session

| [ $limits[]
    | select(.kind == "weekly_scoped")
    | select(.resets_at != null and .percent != null)
    | (.resets_at | mins_until) as $mins
    | select($mins >= 0)
    | (.scope.model.display_name // "Model") as $label
    | color(.severity; "\($label): \(.percent | round)%" + reset($mins))
  ] as $weekly

| [$session] + $weekly | join(" | ")
