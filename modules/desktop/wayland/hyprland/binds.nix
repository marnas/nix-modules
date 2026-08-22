{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib.generators) mkLuaInline;
  # Dispatcher helpers rendered as raw Lua expressions
  exec = cmd: mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON cmd})";
  dsp = expr: mkLuaInline "hl.dsp.${expr}";
  bind = keys: dispatcher: {
    _args = [
      keys
      dispatcher
    ];
  };
  mouseBind = keys: dispatcher: {
    _args = [
      keys
      dispatcher
      { mouse = true; }
    ];
  };
  focusDir = key: direction: bind "SUPER + ${key}" (dsp ''focus({ direction = "${direction}" })'');

  browser = "firefox";
  grim = "${pkgs.grim}/bin/grim";
  menu = "tofi-drun --drun-launch=true";
  mpc = "${pkgs.mpc}/bin/mpc";
  passmanager = "1password";
  slurp = "${pkgs.slurp}/bin/slurp";
  terminal = config.home.sessionVariables.TERMINAL or "ghostty";
in
{
  wayland.windowManager.hyprland.settings.bind = [
    # Mouse binds
    (mouseBind "SUPER + mouse:272" (dsp "window.drag()"))
    (mouseBind "SUPER + mouse:273" (dsp "window.resize()"))

    # Program bindings
    (bind "SUPER + Return" (exec terminal))
    (bind "SUPER + b" (exec browser))
    (bind "SUPER + o" (exec passmanager))
    (bind "SUPER + Q" (dsp "window.close()"))
    (bind "SUPER + V" (dsp "window.float()"))
    (bind "SUPER + SPACE" (exec menu))
    (bind "SUPER + CTRL + E" (dsp "exit()"))
    (bind "SUPER + P" (dsp "window.pseudo()")) # dwindle
    (bind "SUPER + J" (dsp ''layout("togglesplit")'')) # dwindle
    (bind "SUPER + F" (dsp ''window.fullscreen({ mode = "fullscreen" })''))

    # Input method toggle (en <-> mozc): flip IM, then refresh the waybar
    # custom/fcitx5 module via SIGRTMIN+8. Replaces fcitx's internal
    # Control+space trigger so the indicator updates event-driven.
    (bind "CTRL + space" (exec "fcitx5-remote -t && pkill -RTMIN+8 waybar"))
    (bind "SUPER + E" (dsp ''focus({ monitor = "+1" })''))
    (bind "SUPER + SHIFT + E" (dsp ''window.move({ monitor = "+1" })''))

    # Volume
    (bind "XF86AudioRaiseVolume" (exec "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"))
    (bind "XF86AudioLowerVolume" (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
    (bind "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

    # MPD Controls
    (bind "XF86AudioPlay" (exec "${mpc} toggle"))
    (bind "XF86AudioPause" (exec "${mpc} toggle"))
    (bind "XF86AudioNext" (exec "${mpc} next"))
    (bind "XF86AudioPrev" (exec "${mpc} prev"))
    (bind "XF86AudioStop" (exec "${mpc} stop"))

    # Screenshotting
    (bind "SUPER + CTRL + p" (exec ''${grim} -g "$(${slurp} -d)" - | wl-copy -t image/png''))

    # Move focus with mod + arrow keys
    (focusDir "left" "left")
    (focusDir "right" "right")
    (focusDir "up" "up")
    (focusDir "down" "down")
    # Colemak support
    (focusDir "m" "left")
    (focusDir "i" "right")
    (focusDir "e" "up")
    (focusDir "n" "down")

    # Example special workspace (scratchpad)
    (bind "SUPER + S" (dsp ''workspace.toggle_special("magic")''))
    (bind "SUPER + SHIFT + S" (dsp ''window.move({ workspace = "special:magic" })''))

    # Per-monitor workspace binds (SUPER + [1-5], SUPER + SHIFT + [1-5]) are
    # defined in extraConfig (default.nix) via the split-monitor-workspaces
    # Lua library.
  ];
}
