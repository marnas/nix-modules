{ pkgs, config, ... }:
{
  wayland.windowManager.hyprland.settings = {
    bindm = [
      "SUPER,mouse:272,movewindow"
      "SUPER,mouse:273,resizewindow"
    ];
    bind =
      let
        browser = "firefox";
        grim = "${pkgs.grim}/bin/grim";
        menu = "tofi-drun --drun-launch=true";
        mod = "SUPER";
        passmanager = "1password";
        slurp = "${pkgs.slurp}/bin/slurp";
        terminal = config.home.sessionVariables.TERMINAL or "ghostty";
        # editor = defaultApp "text/plain";
      in
      [
        # Program bindings
        "${mod},Return,exec,${terminal}"
        "${mod},b,exec,${browser}"
        "${mod},o,exec,${passmanager}"
        "${mod}, Q, killactive,"
        "${mod}, V, togglefloating,"
        "${mod}, SPACE, exec, ${menu}"
        "${mod} CTRL, E, exit,"
        "${mod}, P, pseudo," # dwindle
        "${mod}, J, layoutmsg, togglesplit" # dwindle
        "${mod}, F, fullscreen, 0"

        # Input method toggle (en <-> mozc): flip IM, then refresh the waybar
        # custom/fcitx5 module via SIGRTMIN+8. Replaces fcitx's internal
        # Control+space trigger so the indicator updates event-driven.
        "CTRL, space, exec, fcitx5-remote -t && pkill -RTMIN+8 waybar"
        "${mod}, E, focusmonitor, +1"
        "${mod} SHIFT, E, movewindow, mon:+1"

        # Volume
        ",XF86AudioRaiseVolume,exec,wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume,exec,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute,exec,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

        # MPD Controls
        ",XF86AudioPlay,exec,${pkgs.mpc}/bin/mpc toggle"
        ",XF86AudioPause,exec,${pkgs.mpc}/bin/mpc toggle"
        ",XF86AudioNext,exec,${pkgs.mpc}/bin/mpc next"
        ",XF86AudioPrev,exec,${pkgs.mpc}/bin/mpc prev"
        ",XF86AudioStop,exec,${pkgs.mpc}/bin/mpc stop"
        # # Screenshotting
        ''
          ${mod} CTRL, p, exec, ${grim} -g "$(${slurp} -d)" - | wl-copy -t image/png
        ''

        # Move focus with mod + arrow keys
        "${mod}, left, movefocus, l"
        "${mod}, right, movefocus, r"
        "${mod}, up, movefocus, u"
        "${mod}, down, movefocus, d"
        # Colemak support
        "${mod}, m, movefocus, l"
        "${mod}, i, movefocus, r"
        "${mod}, e, movefocus, u"
        "${mod}, n, movefocus, d"

        # Example special workspace (scratchpad)col.sha
        "${mod}, S, togglespecialworkspace, magic"
        "${mod} SHIFT, S, movetoworkspace, special:magic"

        # Workspaces
        "${mod}, 1, split-workspace, 1"
        "${mod}, 2, split-workspace, 2"
        "${mod}, 3, split-workspace, 3"
        "${mod}, 4, split-workspace, 4"
        "${mod}, 5, split-workspace, 5"

        "${mod} SHIFT, 1, split-movetoworkspace, 1"
        "${mod} SHIFT, 2, split-movetoworkspace, 2"
        "${mod} SHIFT, 3, split-movetoworkspace, 3"
        "${mod} SHIFT, 4, split-movetoworkspace, 4"
        "${mod} SHIFT, 5, split-movetoworkspace, 5"
      ];
  };
}
