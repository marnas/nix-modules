{
  writeShellApplication,
  tailscale,
  jq,
  tofi,
  procps,
}:
# Exit-node control for the waybar custom/tailscale module (and any keybind).
#
#   status   waybar JSON: text / class / tooltip from `tailscale status --json`
#            ("direct" placeholder when no exit node, so the width stays put)
#   toggle   exit node off, or back on (last used, else `exit-node suggest`)
#   pick     tofi picker over every online exit node, one entry per
#            country/city (highest-Priority node wins), plus Direct/Suggested
#   updown   tailscale down / bare `tailscale up` (keeps current prefs)
#
# Needs the operator pref (`tailscale set --operator=$USER`): every write goes
# through the local socket with no sudo. After a change the bar is refreshed
# through SIGRTMIN+9 (waybar module `signal = 9`), the interval only catches
# changes made elsewhere.
writeShellApplication {
  name = "tailscale-exit";
  runtimeInputs = [
    tailscale
    jq
    tofi
    procps
  ];
  text = ''
    # nf-md-vpn. Pinned to the proportional nerd-font variant: through plain
    # fontconfig fallback the glyph lands in "FiraCode Nerd Font", whose
    # Material icons are drawn wider than their advance and run into the next
    # word (padding spaces don't help). Propo has true advances. Without that
    # font installed fontconfig just falls back and the overlap returns.
    icon='<span font_family="FiraCode Nerd Font Propo">󰖂</span>'
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/tailscale-exit"
    last="$state_dir/last-exit-node"

    refresh() { pkill -RTMIN+9 waybar || true; }

    # Current exit node's DNSName (empty when none is set).
    current() {
      tailscale status --json 2>/dev/null \
        | jq -r '(.ExitNodeStatus.ID // "") as $id
                 | if $id == "" then "" else (.Peer[] | select(.ID == $id) | .DNSName) end'
    }

    suggest() {
      tailscale exit-node suggest 2>/dev/null \
        | sed -n 's/^Suggested exit node: \([^ ]*\)\.$/\1/p'
    }

    set_exit() {
      tailscale set --exit-node="$1"
      refresh
    }

    case "''${1:-status}" in
      status)
        if ! st=$(tailscale status --json 2>/dev/null); then
          jq -cn --arg i "$icon" '{text: "\($i) ?", class: "down", tooltip: "tailscaled unreachable"}'
          exit 0
        fi
        jq -c --arg i "$icon" '
          .BackendState as $b
          | (.ExitNodeStatus.ID // "") as $id
          | ([.Peer // {} | .[] | select(.ID == $id)] | first) as $n
          | if $b != "Running" then
              {text: "\($i) \(if $b == "Stopped" then "off" else ($b | ascii_downcase) end)",
               class: "down", tooltip: "Tailscale: \($b)"}
            elif $id == "" then
              {text: "\($i) direct", class: "direct", tooltip: "Tailscale: connected, no exit node"}
            else
              {text: ("\($i) \($n.Location.CountryCode // "") \($n.Location.City // $n.HostName)" | gsub("  "; " ")),
               class: (if .ExitNodeStatus.Online then "exit" else "exit-offline" end),
               tooltip: "Exit node: \($n.DNSName | rtrimstr("."))\(if .ExitNodeStatus.Online then "" else " (offline)" end)"}
            end
          | .tooltip += "\nleft: toggle · right: pick · middle: up/down"
        ' <<<"$st"
        ;;

      toggle)
        cur=$(current)
        if [ -n "$cur" ]; then
          mkdir -p "$state_dir"
          printf '%s\n' "$cur" >"$last"
          set_exit ""
        else
          node=""
          if [ -r "$last" ]; then
            node=$(cat "$last")
            # Only reuse it if it is still an online exit-node option.
            tailscale status --json | jq -e --arg n "$node" \
              '.Peer[] | select(.DNSName == $n and .ExitNodeOption and .Online)' >/dev/null \
              || node=""
          fi
          [ -n "$node" ] || node=$(suggest)
          [ -n "$node" ] || exit 1
          set_exit "$node"
        fi
        ;;

      pick)
        # label<TAB>dnsname; one row per country/city, best Priority first.
        rows=$(tailscale status --json | jq -r '
          [.Peer[] | select(.ExitNodeOption and .Online)]
          | map({
              label: (if .Location then "\(.Location.Country) / \(.Location.City)" else .HostName end),
              dns: .DNSName,
              prio: (.Location.Priority // 0)
            })
          | group_by(.label)
          | map(max_by(.prio))
          | sort_by(.label)[]
          | "\(.label)\t\(.dns)"')
        cur=$(current)
        choice=$( {
          printf 'Direct (no exit node)\nSuggested\n'
          cut -f1 <<<"$rows"
        } | tofi --prompt-text "exit node ''${cur:+[''${cur%%.*}]} " --num-results 12) || exit 0
        case "$choice" in
          "") exit 0 ;;
          "Direct (no exit node)") set_exit "" ;;
          "Suggested") node=$(suggest); [ -n "$node" ] && set_exit "$node" ;;
          *) node=$(awk -F'\t' -v l="$choice" '$1 == l { print $2; exit }' <<<"$rows")
             [ -n "$node" ] && set_exit "$node" ;;
        esac
        ;;

      updown)
        if [ "$(tailscale status --json 2>/dev/null | jq -r .BackendState)" = "Running" ]; then
          tailscale down
        else
          tailscale up
        fi
        refresh
        ;;

      *)
        echo "usage: tailscale-exit {status|toggle|pick|updown}" >&2
        exit 2
        ;;
    esac
  '';
}
