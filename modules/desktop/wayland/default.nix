{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Variables the whole graphical session needs, not only shells.
  # home.sessionVariables is only sourced by interactive shells; GDM starts
  # Hyprland from the bare PAM environment, so apps launched from a Hyprland
  # bind (tofi, terminal keybind) miss them unless Hyprland exports them via
  # `env`. Symptom: a Qt app without QT_QPA_PLATFORM falls back to xcb, runs
  # under XWayland and never reaches fcitx5.
  # IM variables follow https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland
  # (wlroots/Sway section): Qt6 prefers the compositor's text-input with the
  # fcitx module as fallback, Qt5 uses the fcitx module, XMODIFIERS covers
  # XWayland clients.
  sessionVars = {
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    QT_IM_MODULES = "wayland;fcitx";
    XMODIFIERS = "@im=fcitx";
  };
in
{
  imports = [
    ./hyprland
    ./waybar.nix
    ./tofi.nix
    ./mako.nix
    ./swayidle.nix

  ];

  xdg = {
    portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
      # Hyprland session: screencast/shortcuts via the Hyprland backend, file
      # chooser & the rest via GTK. Don't use "*": with the GNOME session also
      # installed it picks xdg-desktop-portal-gnome for FileChooser, which (v50+)
      # delegates to Nautilus and silently fails when Nautilus isn't installed.
      config.hyprland.default = [
        "hyprland"
        "gtk"
      ];
    };

    configFile."mimeapps.list".force = true;

    # fcitx5 writes its own ~/.config/fcitx5/config; force-manage just two
    # things, everything else keeps its compiled default:
    # - trigger keys: drop the default Control+space (handled by the Hyprland
    #   keybind so the waybar indicator updates event-driven, see
    #   hyprland/binds.nix).
    # - ShareInputState=All: one global active-IM state instead of fcitx5's
    #   default per-window state, so a Ctrl+space toggle (and the waybar
    #   indicator) applies to every app, not only the window that was focused.
    configFile."fcitx5/config" = {
      force = true;
      text = ''
        [Hotkey/TriggerKeys]
        0=Zenkaku_Hankaku
        1=Hangul

        [Behavior]
        ShareInputState=All
      '';
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "image/png" = "org.gnome.eog.desktop";
        "image/jpeg" = "org.gnome.eog.desktop";

        "text/html" = "firefox.desktop";
        "text/xml" = [ "firefox.desktop" ];
        "application/pdf" = "firefox.desktop";
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];

        # TradingView signs in via a tradingview:// browser callback; register
        # the handler so the token comes back over the deep link instead of the
        # clipboard-polling fallback (which hangs the sign-in).
        "x-scheme-handler/tradingview" = "tradingview.desktop";

        "audio/flac" = "vlc.desktop";
      };
      associations.added = {
        # others...
      };
    };
  };

  home = {
    packages = with pkgs; [
      # grim
      gtk3
      imv
      libnotify
      qt5.qtwayland
      mimeo
      meson
      qt6.qtwayland
      # slurp
      wayland
      wayland-protocols
      wayland-utils
      stable.waypipe # 2026-08: unstable waypipe 0.11.0 fails to build against ffmpeg 9 (Vulkan hwcontext API removed); drop `stable.` once fixed
      wl-clipboard
      wl-mirror
      stable.wf-recorder # 2026-08: unstable wf-recorder 0.6.0 fails to build against ffmpeg 8 (AVCodec.sample_fmts removed); drop `stable.` once fixed
      wlroots
      xwayland
      ydotool
    ];

    sessionVariables = sessionVars // {
      LIBSEAT_BACKEND = "logind";
      NIX_PROFILES = "${config.home.homeDirectory}/.nix-profile /nix/var/nix/profiles/default";
    };
  };

  wayland.windowManager.hyprland.settings.env = lib.mapAttrsToList (name: value: {
    _args = [
      name
      value
    ];
  }) sessionVars;
}
