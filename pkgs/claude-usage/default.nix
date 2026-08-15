{
  writeShellApplication,
  jq,
  curl,
}:
# The entire Claude-usage tmux widget in one script. tmux invokes it from
# status-right's #(...) on every status redraw (status-interval), and it does
# two things:
#
#   1. Render: format the cached usage-API response with jq and print it.
#   2. Refresh: if the cache is older than 4 min, kick off a *background*
#      fetch of api.anthropic.com/api/oauth/usage so the redraw never blocks
#      on the network. tmux's redraw cadence is the only scheduler — no
#      systemd timer, no launchd agent — and fetches stop entirely when no
#      tmux status line is being drawn.
#
# The endpoint is rate-limited per account (and shared with every live Claude
# session's own polling), so failures are expected under heavy agent use: on
# anything but a 200 the script backs off 5 min and keeps serving the last
# good numbers. Max traffic is ~15 req/h while tmux is visible.
#
# OAuth token: ~/.claude/.credentials.json on Linux, the "Claude
# Code-credentials" keychain item on macOS (security(1) comes from the system
# PATH there).
writeShellApplication {
  name = "claude-usage";
  runtimeInputs = [
    jq
    curl
  ];
  text = ''
    dir="$HOME/.cache/claude-usage"
    cache="$dir/usage.json"
    cooldown="$dir/cooldown"

    refresh_due=1
    if [ -n "$(find "$cache" -mmin -4 2>/dev/null)" ]; then
      refresh_due=0
    fi
    now=$(date +%s)
    if [ -r "$cooldown" ]; then
      until=$(cat "$cooldown" 2>/dev/null || echo 0)
      case "$until" in "" | *[!0-9]*) until=0 ;; esac
      if [ "$now" -lt "$until" ]; then
        refresh_due=0
      fi
    fi

    if [ "$refresh_due" = 1 ]; then
      mkdir -p "$dir"
      # Claim the slot before forking so overlapping redraws (multiple tmux
      # clients) don't stack fetches; success clears it, failure extends it.
      echo $((now + 60)) > "$cooldown"
      (
        if [ "$(uname)" = "Darwin" ]; then
          creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)
        else
          creds=$(cat "$HOME/.claude/.credentials.json" 2>/dev/null || true)
        fi
        token=$(printf '%s' "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null || true)
        if [ -n "$token" ]; then
          tmp="$cache.tmp.$$"
          code=$(curl -sS -m 5 -o "$tmp" -w '%{http_code}' \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            https://api.anthropic.com/api/oauth/usage || echo 000)
          if [ "$code" = 200 ] && jq -e 'has("five_hour")' "$tmp" >/dev/null 2>&1; then
            mv -f "$tmp" "$cache"
            rm -f "$cooldown"
          else
            rm -f "$tmp"
            echo $(( $(date +%s) + 300 )) > "$cooldown"
          fi
        fi
      ) >/dev/null 2>&1 &
    fi

    if [ -r "$cache" ]; then
      jq -rf ${./format.jq} "$cache" 2>/dev/null || true
    fi
  '';
}
