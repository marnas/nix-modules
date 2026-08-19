{
  pkgs,
  nixModulesInputs,
  config,
  ...
}:
{
  imports = [ ./binds.nix ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    configType = "hyprlang";
    # package = nixModulesInputs.hyprland.packages.${pkgs.system}.hyprland;
    package = nixModulesInputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      nixModulesInputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    plugins = [
      nixModulesInputs.split-monitor-workspaces.packages.${pkgs.stdenv.hostPlatform.system}.split-monitor-workspaces
      # nixModulesInputs.hyprsplit.packages.${pkgs.stdenv.hostPlatform.system}.hyprsplit
    ];

    settings = {
      env = [
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"
      ];

      plugin = {
        split-monitor-workspaces = {
          count = 5;
          enable_persistent_workspaces = 0;
        };
        # hyprsplit = { num_workspaces = 5; };
      };

      monitor = [
        "DP-1,2560x1440@359.98,0x0,1"
        "DP-2,2560x1440@359.98,2560x0,1"
        "HDMI-A-1, disable"
        # "HDMI-A-1,4096x2160@120,5120x0,1"
      ];
      general = {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more
        gaps_in = 5;
        gaps_out = 20;
        border_size = 2;
        # layout = dwindle;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
        allow_tearing = false;
      };

      # master = {
      #   new_is_master = false;
      # };

      windowrule = [
        # Don't let swayidle lock/dpms while any window is fullscreen
        "idle_inhibit fullscreen, match:class .*"
        # Hide ghost XWayland window created by xembedsniproxy
        "opacity 0.0 override, match:xwayland 1, match:class ^$, match:title ^$"
        "no_blur on, match:xwayland 1, match:class ^$, match:title ^$"
        "float on, match:xwayland 1, match:class ^$, match:title ^$"
      ];

      input = {
        kb_layout = "us";
        kb_variant = "altgr-intl";
        follow_mouse = true;
        touchpad = {
          natural_scroll = true;
        };
        sensitivity = "-0.8";
        accel_profile = "adaptive";
      };
      gestures = {
        workspace = true;
      };

      decoration = {
        active_opacity = 0.97;
        inactive_opacity = 0.97;
        # inactive_opacity = 0.77;
        fullscreen_opacity = 1.0;
        rounding = 2;
        blur = {
          enabled = true;
          size = 5;
          passes = 3;
          new_optimizations = true;
          ignore_opacity = true;
        };
        shadow = {
          enabled = true;
          range = 12;
          color = "0x44000000";
          color_inactive = "0x66000000";
          offset = "3 3";
        };
      };

      # layerrule = [ "blur, notifications" "ignorezero, notifications" ];
      layerrule = [ "blur on, ignore_alpha 0, match:namespace notifications" ];

      animations = {
        enabled = true;
        bezier = [ "myBezier, 0.05, 0.9, 0.1, 1.05" ];
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      misc = {
        focus_on_activate = true;
        force_default_wallpaper = 0;
      };

      dwindle = {
        preserve_split = true;
        force_split = 2;
      };

      exec-once = [
        "1password --silent"
        "fcitx5 --replace -d --disable classicui"
      ];
      exec = [
        "${pkgs.swaybg}/bin/swaybg -o DP-1 -i ${config.home.homeDirectory}/Pictures/wallpapers/Ocean_Spray_-_MacBook_Wallpaper.jpg --mode fill"
        "${pkgs.swaybg}/bin/swaybg -o DP-2 -i ${config.home.homeDirectory}/Pictures/wallpapers/Wallpaper2.jpg --mode fill"
        "hyprctl setcursor ${config.gtk.cursorTheme.name} ${toString config.gtk.cursorTheme.size}"
      ];
    };
  };
}
