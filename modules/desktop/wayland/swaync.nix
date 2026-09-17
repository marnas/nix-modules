{
  pkgs,
  lib,
  config,
  ...
}:
let
  hyprctl = lib.getExe' config.wayland.windowManager.hyprland.package "hyprctl";
  jq = lib.getExe pkgs.jq;
  systemctl = "${pkgs.systemd}/bin/systemctl";
  loginctl = "${pkgs.systemd}/bin/loginctl";
  notify-send = "${pkgs.libnotify}/bin/notify-send";
  swaync-client = lib.getExe' config.services.swaync.package "swaync-client";

  # Click-to-focus: raise the window of the app that sent the notification.
  # Runs from swaync's `scripts` hook with run-on=action (any click on a
  # popup or list entry). Apps that implement xdg-activation focus themselves
  # via the token swaync hands them; this covers everything else.
  # Match desktop-entry (== app_id for Wayland apps) then app-name, case-
  # insensitive, exact before substring, most recently focused window wins.
  focus = pkgs.writeShellScript "cc-focus" ''
    for needle in "''${SWAYNC_DESKTOP_ENTRY%.desktop}" "$SWAYNC_APP_NAME"; do
      [ -n "$needle" ] || continue
      addr=$(${hyprctl} clients -j | ${jq} -r --arg n "$needle" '
        ($n | ascii_downcase) as $n
        | map(select(.mapped))
        | map(. + { c: (.class | ascii_downcase), ic: (.initialClass | ascii_downcase) })
        | (map(select(.c == $n or .ic == $n))
           + map(select(.c as $c | ($c | contains($n)) or ($n | contains($c)))))
        | sort_by(.focusHistoryID)
        | .[0].address // empty')
      if [ -n "$addr" ]; then
        exec ${hyprctl} dispatch "hl.dsp.focus({ window = \"address:$addr\" })"
      fi
    done
    exit 0
  '';

  # Two-step power actions: close the panel, then ask through a notification
  # carrying a single action button. The command only runs when that button is
  # clicked; dismissing or letting it expire is a no-op. Always exits 0 so
  # swaync's script-fail-notify stays quiet on decline.
  #   usage: cc-confirm <verb> <command...>
  confirm = pkgs.writeShellScript "cc-confirm" ''
    verb=$1
    shift
    ${swaync-client} --close-panel --skip-wait
    choice=$(${notify-send} --app-name "Control Center" --urgency normal \
      --expire-time 15000 --action "yes=$verb" "$verb?" "Click to confirm")
    [ "$choice" = yes ] && exec "$@"
    exit 0
  '';
in
{
  # Notification daemon + control center (mako.nix is kept but not imported:
  # the two cannot coexist, both claim org.freedesktop.Notifications).
  # Toggled from the waybar custom/notification module (waybar.nix).
  services.swaync = {
    enable = true;
    # Upstream has no "max panel height": the sheet is a GtkScrolledWindow
    # that, with control-center-height = 0, grows to its content and is only
    # clamped by the output. Give it GTK's max-content-height so it stops
    # at roughly two thirds of a 1440p screen and scrolls from there.
    package = pkgs.swaynotificationcenter.overrideAttrs (old: {
      # Per-stream mute toggle on each per-app volume row (the daemon wrapper
      # already exposes set_sink_input_mute; upstream just never wired a
      # button to it). Mutes that one PulseAudio sink input, not the sink.
      # Main slider on a card with several sinks (USB Audio: speakers +
      # headphones + S/PDIF) set the volume of the LAST sink enumerated
      # instead of the default one; upstream stamps every device of the card
      # with each sink's name. Only stamp devices whose port the sink owns.
      patches = (old.patches or [ ]) ++ [
        ./swaync-per-app-mute.patch
        ./swaync-multi-sink-card.patch
      ];
      postPatch = (old.postPatch or "") + ''
        # Sheet: hard ceiling. List: grows to 560px, then scrolls on its own
        # so the controls above it stay put (macOS Notification Center).
        sed -i 's/^\(\s*\)overflow: hidden;$/\1overflow: hidden;\n\1max-content-height: 960;/' data/ui/control_center.blp
        sed -i 's/^\(\s*\)hscrollbar-policy: never;$/\1hscrollbar-policy: never;\n\1max-content-height: 560;/' data/ui/notifications_widget.blp
        grep -q 'max-content-height: 960' data/ui/control_center.blp
        grep -q 'max-content-height: 560' data/ui/notifications_widget.blp
      '';
    });
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "top";
      # Content-sized panel hanging below the bar, macOS style: height 0 lets
      # the window take its natural height instead of a fixed/full-height box.
      fit-to-screen = false;
      control-center-width = 400;
      control-center-height = 0;
      control-center-margin-top = 8;
      control-center-margin-right = 8;
      notification-window-width = 400;
      # App icon / image at macOS size; the app-icon badge is a third of it.
      notification-icon-size = 40;
      timeout = 15;
      timeout-low = 8;
      timeout-critical = 0;
      notification-grouping = true;
      hide-on-clear = false;
      hide-on-action = true;
      keyboard-shortcuts = true;
      # No match keys = every notification; "action" = fired on click.
      scripts.focus-source = {
        exec = "${focus}";
        run-on = "action";
      };
      widgets = [
        "menubar"
        "volume"
        "mpris"
        "dnd"
        "title"
        "notifications"
      ];
      widget-config = {
        # Top row: 󰌾 (immediate, harmless) left, ⏻ dropdown right, both as
        # identical circular icon buttons. Everything under ⏻ goes through
        # cc-confirm.
        menubar = {
          "buttons#quick" = {
            position = "left";
            actions = [
              {
                label = "󰌾";
                # swayidle handles the logind lock event (swayidle.nix), so the
                # single lock script stays defined there.
                command = "${loginctl} lock-session";
              }
            ];
          };
          "menu#power" = {
            label = "⏻";
            position = "right";
            animation-type = "slide_down";
            animation-duration = 200;
            actions = [
              {
                label = "󰤄  Sleep";
                command = "${confirm} Sleep ${systemctl} suspend";
              }
              {
                label = "󰜉  Reboot";
                command = "${confirm} Reboot ${systemctl} reboot";
              }
              {
                label = "⏻  Shut down";
                command = "${confirm} 'Shut down' ${systemctl} poweroff";
              }
              {
                label = "󰗽  Log out";
                command = "${confirm} 'Log out' ${hyprctl} dispatch 'hl.dsp.exit()'";
              }
            ];
          };
        };
        volume = {
          label = "󰕾";
          # One row per playing stream (PulseAudio sink input) under the
          # main slider: app icon, name, its own slider and mute toggle.
          show-per-app = true;
          show-per-app-icon = true;
          show-per-app-label = true;
          expand-per-app = true;
          empty-list-label = "Nothing playing";
          animation-type = "slide_down";
          animation-duration = 200;
        };
        mpris = {
          autohide = true;
          # "always": keep the art slot (placeholder when a stream sends no
          # artwork) so the tile keeps one layout.
          show-album-art = "always";
          blacklist = [ "playerctld" ];
        };
        dnd.text = "Do Not Disturb";
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear all";
        };
        # vexpand=false makes the list propagate its natural height, so the
        # panel grows with the notifications instead of scrolling a fixed
        # box; the package patch below caps the growth.
        notifications.vexpand = false;
      };
    };

    # Visual grammar borrowed from macOS Control Center: one frosted-glass
    # sheet (translucent bg, Hyprland blurs behind it — see the layer_rule in
    # hyprland/default.nix), evenly spaced rounded tiles, thick knob-less
    # sliders, circular icon buttons, hairline borders. Colours come from the
    # waybar/mako palette (#2d2a2e / #fcfcfa / #727072); on-states use the
    # waybar active-workspace blue (#285577).
    # swaync's own stylesheet is driven by the :root variables, so overriding
    # them restyles the parts we don't touch explicitly.
    style = ''
      * {
        font-family: "Helvetica Neue";
        font-size: 13px;
      }

      :root {
        --cc-bg: rgba(45, 42, 46, 0.72);
        --noti-bg: 255, 255, 255;
        --noti-bg-alpha: 0.08;
        --noti-bg-darker: rgba(0, 0, 0, 0.25);
        --noti-bg-hover: rgba(255, 255, 255, 0.14);
        --noti-bg-focus: rgba(255, 255, 255, 0.1);
        --noti-close-bg: rgba(255, 255, 255, 0.12);
        --noti-close-bg-hover: rgba(255, 255, 255, 0.22);
        --noti-border-color: transparent;
        --text-color: #fcfcfa;
        --text-color-disabled: rgba(252, 252, 250, 0.55);
        --bg-selected: #285577;
        --border-radius: 14px;
        --font-size-body: 14px;
        --font-size-summary: 14px;
        --notification-shadow: none;
        --notification-icon-size: 40px;
        --mpris-album-art-overlay: rgba(30, 28, 31, 0.6);
        --mpris-album-art-icon-size: 88px;
        --mpris-album-art-shadow: 0 4px 12px rgba(0, 0, 0, 0.45);

        --tile: rgba(255, 255, 255, 0.08);
        --tile-hover: rgba(255, 255, 255, 0.14);
        --tile-active: rgba(255, 255, 255, 0.2);
        /* opaque equivalents of --tile / --tile-hover on the sheet */
        --card: rgb(62, 59, 63);
        --card-hover: rgb(76, 73, 77);
        --card-behind: rgb(53, 50, 54);
        --hairline: rgba(255, 255, 255, 0.12);
        /* On-states use the waybar active-workspace blue */
        --accent: #285577;
        --accent-hover: #336a94;
        --muted: rgba(252, 252, 250, 0.55);
        --gap: 10px;
      }

      /* ---- Sheet ------------------------------------------------------ */
      .control-center {
        background: var(--cc-bg);
        border: 1px solid var(--hairline);
        border-radius: 18px;
        box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45);
        padding: 4px 4px;
      }
      /* Thin overlay scrollbar, only visible while scrolling/hovering */
      .control-center scrollbar {
        background: transparent;
        border: none;
        margin: 2px;
      }
      .control-center scrollbar slider {
        background: rgba(255, 255, 255, 0.28);
        border-radius: 999px;
        min-width: 4px;
        min-height: 24px;
        border: none;
      }
      .control-center scrollbar slider:hover {
        background: rgba(255, 255, 255, 0.45);
      }

      /* ---- Tiles ------------------------------------------------------ */
      .widget {
        margin: 5px var(--gap);
        padding: 10px 14px;
        background: var(--tile);
        border-radius: var(--border-radius);
        border: 1px solid rgba(255, 255, 255, 0.04);
      }
      .widget label {
        color: var(--text-color);
      }
      .widget button {
        background: rgba(255, 255, 255, 0.1);
        border: none;
        box-shadow: none;
        color: var(--text-color);
        border-radius: 999px;
        padding: 6px 14px;
        min-height: 0;
        transition: background 120ms ease-out;
      }
      .widget button:hover {
        background: var(--tile-hover);
      }
      .widget button:active {
        background: var(--tile-active);
      }

      /* ---- Session row: ( 󰌾 )                       ( ⏻ ) ------------ */
      .widget-menubar {
        padding: 8px 10px;
      }
      .widget-menubar > .menu-button-bar > .start,
      .widget-menubar > .menu-button-bar > .end {
        margin: 0;
      }
      /* 󰌾 and ⏻: identical circular icon buttons, 34px */
      .widget-menubar > .menu-button-bar > .widget-menubar-container button,
      .widget-menubar .quick button,
      .widget-menubar .power button {
        min-width: 34px;
        min-height: 34px;
        padding: 0;
        margin: 0;
        border-radius: 999px;
        font-size: 15px;
      }
      .widget-menubar .power button:checked {
        background: var(--accent);
        border-color: transparent;
        color: var(--text-color);
      }
      /* dropdown rows */
      .widget-menubar > revealer * {
        margin-top: 8px;
      }
      .widget-menubar > revealer * button {
        margin: 2px 0 0 0;
        padding: 9px 14px;
        border-radius: 10px;
        background: transparent;
      }
      .widget-menubar > revealer * button:hover {
        background: var(--tile-hover);
      }
      .widget-menubar > revealer * button:last-child {
        margin-bottom: 0;
      }

      /* ---- Sliders: thick track, white fill, no knob ------------------ */
      .widget-volume {
        padding: 8px 12px;
      }
      .widget-volume label {
        color: var(--muted);
        margin-right: 10px;
      }
      .widget-volume scale {
        padding: 0;
      }
      .widget-volume trough {
        background: rgba(255, 255, 255, 0.16);
        border: none;
        border-radius: 11px;
        min-height: 22px;
      }
      .widget-volume highlight {
        background: var(--text-color);
        border: none;
        border-radius: 11px;
        min-height: 22px;
      }
      /* Knob kept full-size for GTK's drag gesture, just painted invisible */
      .widget-volume slider {
        background: transparent;
        border: none;
        box-shadow: none;
        min-width: 22px;
        min-height: 22px;
        margin: 0;
      }

      /* Per-app rows: icon · name · slider · mute, same slider language.
         The chevron after the main slider folds the list. */
      .widget-volume > box > button {
        background: transparent;
        min-width: 22px;
        min-height: 22px;
        padding: 0;
        margin: 0 0 0 6px;
        -gtk-icon-size: 12px;
        color: var(--muted);
      }
      .widget-volume > box > button:hover {
        color: var(--text-color);
      }
      .widget-volume .per-app-volume {
        background: transparent;
        margin: 6px 0 0 0;
        border-top: 1px solid rgba(255, 255, 255, 0.06);
        padding-top: 4px;
      }
      .widget-volume .per-app-volume row {
        background: transparent;
        padding: 4px 0;
      }
      .widget-volume .per-app-volume row image {
        -gtk-icon-size: 18px;
        margin-right: 8px;
      }
      .widget-volume .per-app-volume row label {
        font-size: 12px;
        color: var(--muted);
        margin-right: 10px;
      }
      .widget-volume .per-app-volume row trough,
      .widget-volume .per-app-volume row highlight {
        min-height: 16px;
        border-radius: 8px;
      }
      .widget-volume .per-app-volume row slider {
        min-width: 16px;
        min-height: 16px;
      }
      .widget-volume .per-app-volume row button.per-app-mute {
        background: rgba(255, 255, 255, 0.1);
        min-width: 24px;
        min-height: 24px;
        padding: 0;
        margin: 0 0 0 8px;
        border-radius: 999px;
        -gtk-icon-size: 12px;
        color: var(--text-color);
      }
      .widget-volume .per-app-volume row button.per-app-mute:hover {
        background: var(--tile-hover);
      }
      .widget-volume .per-app-volume row button.per-app-mute:checked {
        background: var(--accent);
        border-color: transparent;
        color: var(--text-color);
      }
      .widget-volume .per-app-volume row.muted highlight {
        background: var(--muted);
      }

      /* ---- Now Playing ------------------------------------------------ */
      .widget-mpris {
        padding: 0;
        background: transparent;
        border: none;
      }
      .widget-mpris .widget-mpris-player {
        margin: 0;
        border: 1px solid rgba(255, 255, 255, 0.04);
        box-shadow: none;
      }
      .widget-mpris .widget-mpris-player .mpris-background {
        filter: blur(24px) saturate(1.4);
        opacity: 0.6;
      }
      .widget-mpris .widget-mpris-player .mpris-overlay {
        background-color: var(--mpris-album-art-overlay);
        padding: 14px;
      }
      .widget-mpris .widget-mpris-player .widget-mpris-album-art {
        border-radius: 10px;
      }
      .widget-mpris .widget-mpris-player .widget-mpris-title {
        font-size: 14px;
        font-weight: 600;
      }
      .widget-mpris .widget-mpris-player .widget-mpris-subtitle {
        font-size: 12px;
        color: var(--muted);
      }
      .widget-mpris .widget-mpris-player .mpris-overlay > box > button {
        background: transparent;
        padding: 6px;
        margin: 0 2px;
      }
      .widget-mpris .widget-mpris-player .mpris-overlay > box > button:hover {
        background: rgba(255, 255, 255, 0.16);
      }
      /* carousel chrome (only shown with >1 player): thin chevrons + dots */
      .widget-mpris > box > button {
        background: transparent;
        min-width: 0;
        padding: 0 2px;
        margin: 0;
        color: var(--muted);
      }
      .widget-mpris > box > button:hover {
        background: transparent;
        color: var(--text-color);
      }
      .widget-mpris carouselindicatordots {
        margin: 2px 0 0 0;
        color: var(--muted);
      }

      /* ---- Do Not Disturb -------------------------------------------- */
      .widget-dnd {
        padding: 8px 14px;
      }
      .widget-dnd label {
        font-size: 13px;
        margin: 0;
      }
      .widget-dnd switch {
        background: rgba(255, 255, 255, 0.16);
        border: none;
        box-shadow: none;
        border-radius: 999px;
        min-width: 42px;
        min-height: 24px;
        margin: 0;
      }
      .widget-dnd switch:checked {
        background: var(--accent);
      }
      .widget-dnd switch slider {
        background: #ffffff;
        border: none;
        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
        border-radius: 999px;
        min-width: 20px;
        min-height: 20px;
        margin: 2px;
      }

      /* ---- Notifications header -------------------------------------- */
      .widget-title {
        background: transparent;
        border: none;
        margin: 8px var(--gap) 0 var(--gap);
        padding: 0 6px;
      }
      .widget-title > label {
        font-size: 12px;
        font-weight: 600;
        color: var(--muted);
      }
      .widget-title > button {
        font-size: 12px;
        padding: 3px 10px;
        background: transparent;
        color: var(--muted);
      }
      .widget-title > button:hover {
        background: var(--tile-hover);
        color: var(--text-color);
      }

      /* ---- Notification list ----------------------------------------- */
      /* The list is not a tile: cards float directly on the sheet. */
      .widget-notifications {
        background: transparent;
        border: none;
        padding: 0;
        /* rows carry 6px side padding (room for the corner close button),
           so 4px here keeps the cards aligned with the tiles above */
        margin: 0 4px 6px 4px;
      }
      /* The empty state and the list are two stack pages, each sized to its
         own content; pin both to one floor so the panel never gets shorter
         with one notification than with none. It only grows from here. */
      .control-center scrolledwindow,
      .control-center .control-center-list-placeholder {
        min-height: 108px;
      }
      .control-center .control-center-list-placeholder {
        opacity: 0.3;
        margin: 0;
      }
      .control-center .control-center-list-placeholder image {
        -gtk-icon-transform: scale(0.5);
        margin: -24px 0;
      }
      .control-center .notification-row .notification-background {
        padding: 5px 6px;
      }
      /* List cards are OPAQUE (unlike the tiles above): same-app
         notifications collapse into a stack where the cards underneath are
         drawn scaled to 95% and shifted down behind the top one. A
         translucent top card would show them through it. --card is the
         tile colour as it composites on the sheet. */
      .control-center .control-center-list .notification {
        background: var(--card);
        border: 1px solid rgba(255, 255, 255, 0.04);
        border-radius: 12px;
        box-shadow: none;
      }
      .control-center .control-center-list .notification:hover {
        background: var(--card-hover);
      }
      /* Every non-expanded group is ".collapsed"; stock CSS repaints those
         cards with --noti-bg at alpha 1 and outranks the rule above, so
         pin the colours at higher specificity. Cards behind the top of a
         stack go a shade darker so the peeking edge reads as depth. */
      .control-center .notification-group.collapsed .notification-row .notification {
        background: var(--card);
      }
      .control-center .notification-group.collapsed .notification-row:not(:last-child) .notification {
        background: var(--card-behind);
        border-color: transparent;
      }
      .control-center .notification-group.collapsed .notification-row:last-child .notification:hover,
      .control-center .notification-group.collapsed:hover .notification-row:not(:only-child):last-child .notification {
        background: var(--card-hover);
      }
      .control-center .control-center-list .notification .notification-default-action {
        padding: 8px 10px;
      }
      .control-center .control-center-list .notification .notification-default-action:hover {
        background: transparent;
      }
      /* App icon: rounded square like a macOS app tile, snug to the text */
      .notification .notification-content .image {
        border-radius: 9px;
        margin: 0 10px 0 0;
      }
      .notification .notification-content .app-icon {
        margin: 0 4px 0 0;
      }
      .notification .summary {
        font-weight: 600;
      }
      /* Timestamp flush right (stock CSS indents it 30px to dodge the close
         button; the button now hangs on the corner instead, see below).
         Selector mirrors the stock one so it wins on specificity. */
      .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .time {
        font-weight: normal;
        font-size: 11px;
        color: var(--muted);
        margin-right: 0;
      }
      /* The first row is selected/focused when the panel opens; neither
         GTK's row:selected nor swaync's row focus should paint a band
         outside the rounded card. Hover on the card is enough. */
      .control-center-list row,
      .control-center-list row:selected,
      .control-center-list row:hover,
      .control-center-list row:focus,
      .control-center-list row:active,
      .notification-row:focus,
      .notification-group:focus {
        background: transparent;
        box-shadow: none;
        outline: none;
      }
      .notification .body {
        color: var(--muted);
      }
      .notification-row .notification-background .notification .notification-action > button {
        border-radius: 10px;
        background: rgba(255, 255, 255, 0.1);
      }
      .notification-row .notification-background .notification .notification-action > button:hover {
        background: var(--tile-hover);
      }
      /* Hover-only close button, macOS style: hangs on the card's top-right
         corner instead of sitting inside it, so it never meets the
         timestamp. Negative margins push it into the row padding (which is
         >= 5px on every row, see .notification-background rules).
         Also has GTK's .circular class (min 34px); out-rank it. */
      button.close-button.circular {
        min-width: 16px;
        min-height: 16px;
        padding: 0;
        margin: -5px -5px 0 0;
        -gtk-icon-size: 9px;
        background: #4a464b;
        color: var(--text-color);
        border: 1px solid rgba(255, 255, 255, 0.12);
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
      }
      button.close-button.circular:hover {
        background: #605c61;
      }
      /* Expanded stack: app icon + name header row and its buttons, sized
         like the section header instead of the stock title-1 */
      .notification-group .notification-group-headers,
      .notification-group .notification-group-buttons {
        margin: 4px 6px;
      }
      .notification-group .notification-group-headers .notification-group-icon {
        -gtk-icon-size: 18px;
        margin-right: 6px;
      }
      .notification-group .notification-group-headers .notification-group-header {
        font-size: 12px;
        font-weight: 600;
        color: var(--muted);
      }
      .notification-group .notification-group-buttons button {
        background: rgba(255, 255, 255, 0.1);
        border: none;
        box-shadow: none;
        color: var(--text-color);
        min-width: 22px;
        min-height: 22px;
        padding: 0;
        margin: 0 2px;
        -gtk-icon-size: 12px;
      }
      .notification-group .notification-group-buttons button:hover {
        background: var(--tile-hover);
      }

      /* Breathing room inside every card: mako ran padding 10 at 11pt */
      .notification .notification-default-action {
        padding: 10px 12px;
      }
      .notification .notification-content .text-box {
        margin: 2px 4px;
      }
      .notification .notification-content .summary {
        margin-bottom: 2px;
      }
      .notification .notification-alt-actions {
        padding: 0 8px 8px 8px;
      }
      .notification .notification-action > button {
        padding: 6px 12px;
        margin: 4px;
      }

      /* ---- Floating popups ------------------------------------------- */
      .floating-notifications .notification-row .notification-background {
        padding: 6px 12px;
      }
      .floating-notifications .notification {
        /* solid, like mako: no compositor blur behind popups */
        background: rgba(45, 42, 46, 0.96);
        border: 1px solid var(--hairline);
        border-radius: 16px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
      }
    '';
  };
}
