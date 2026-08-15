# Format the cached /api/oauth/usage response (raw, as returned by the API)
# into the tmux widget text, e.g. "Session: 54.0% | Reset: 4hr 21m".
#
# The reset countdown is derived at render time from the absolute resets_at,
# so it ticks down on every redraw between fetches. If resets_at has passed —
# meaning no fetch has succeeded since the 5h block rolled over — the cached
# numbers describe a dead block, so render an explicit staleness marker rather
# than a plausible-but-wrong figure; the next successful fetch replaces it.
def fmt($mins):
  if $mins < 1 then "<1m"
  else ($mins / 60 | floor) as $h
  | ($mins % 60) as $m
  | if $h == 0 then "\($m)m"
    elif $m == 0 then "\($h)hr"
    else "\($h)hr \($m)m"
    end
  end;

if .five_hour == null then
  # No active block (no usage since the last one expired).
  "Session: 0.0%"
else
  # One-decimal percent without a printf float (matches toFixed(1)).
  ((.five_hour.utilization // 0) * 10 | round) as $t
  | "Session: \($t / 10 | floor).\($t % 10)%" as $pct
  | (.five_hour.resets_at // null) as $r
  | if $r == null then $pct
    else
      # UTC ISO8601 with fractional seconds and +00:00 offset; normalize for
      # fromdateiso8601.
      ($r | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) as $reset
      | (($reset - now) / 60 | floor) as $mins
      | if $mins < 0 then "usage: stale"
        else "\($pct) | Reset: \(fmt($mins))"
        end
    end
end
