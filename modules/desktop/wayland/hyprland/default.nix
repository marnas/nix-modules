{
  pkgs,
  lib,
  nixModulesInputs,
  config,
  ...
}:
let
  inherit (lib.generators) mkLuaInline;
  # Pure-Lua split-monitor-workspaces library (upstream deprecated the C++
  # plugin); required and set up in extraConfig below.
  smwSrc = nixModulesInputs.split-monitor-workspaces;
in
{
  imports = [ ./binds.nix ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    configType = "lua";
    package = nixModulesInputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      nixModulesInputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    settings = {
      env = [
        {
          _args = [
            "XDG_CURRENT_DESKTOP"
            "Hyprland"
          ];
        }
        {
          _args = [
            "XDG_SESSION_TYPE"
            "wayland"
          ];
        }
        {
          _args = [
            "XDG_SESSION_DESKTOP"
            "Hyprland"
          ];
        }
      ];

      monitor = [
        {
          output = "DP-1";
          mode = "2560x1440@359.98";
          position = "0x0";
          scale = 1;
        }
        {
          output = "DP-2";
          mode = "2560x1440@359.98";
          position = "2560x0";
          scale = 1;
        }
        {
          output = "HDMI-A-1";
          disabled = true;
        }
      ];

      config = {
        # See https://wiki.hypr.land/Configuring/Basics/Variables/ for more
        general = {
          gaps_in = 5;
          gaps_out = 20;
          border_size = 2;
          col = {
            active_border = {
              colors = [
                "rgba(33ccffee)"
                "rgba(00ff99ee)"
              ];
              angle = 45;
            };
            inactive_border = "rgba(595959aa)";
          };
          # Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
          allow_tearing = false;
        };

        decoration = {
          active_opacity = 0.97;
          inactive_opacity = 0.97;
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

        animations.enabled = true;

        misc = {
          focus_on_activate = true;
          force_default_wallpaper = 0;
        };

        dwindle = {
          preserve_split = true;
          force_split = 2;
        };

        input = {
          kb_layout = "us";
          kb_variant = "altgr-intl";
          follow_mouse = 1;
          touchpad = {
            natural_scroll = true;
          };
          sensitivity = -0.8;
          accel_profile = "adaptive";
        };
      };

      curve = [
        {
          _args = [
            "myBezier"
            {
              type = "bezier";
              points = [
                [
                  0.05
                  0.9
                ]
                [
                  0.1
                  1.05
                ]
              ];
            }
          ];
        }
      ];
      animation = [
        {
          leaf = "windows";
          enabled = true;
          speed = 7;
          bezier = "myBezier";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 7;
          bezier = "default";
          style = "popin 80%";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 10;
          bezier = "default";
        }
        {
          leaf = "borderangle";
          enabled = true;
          speed = 8;
          bezier = "default";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 7;
          bezier = "default";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 6;
          bezier = "default";
        }
      ];

      window_rule = [
        # Don't let swayidle lock/dpms while any window is fullscreen
        {
          match.class = ".*";
          idle_inhibit = "fullscreen";
        }
        # Hide ghost XWayland window created by xembedsniproxy
        {
          match = {
            xwayland = true;
            class = "^$";
            title = "^$";
          };
          opacity = "0.0 override";
          no_blur = true;
          float = true;
        }
      ];

      layer_rule = [
        {
          match.namespace = "notifications";
          blur = true;
          ignore_alpha = 0;
        }
      ];

      gesture = [
        {
          fingers = 3;
          direction = "horizontal";
          action = "workspace";
        }
      ];

      # Everything in the start hook: top-level hl.exec_cmd runs at config
      # parse time, which at boot is before the compositor is up (spawned
      # clients die without a Wayland socket).
      on = [
        {
          _args = [
            "hyprland.start"
            (mkLuaInline ''
              function()
                hl.exec_cmd("1password --silent")
                hl.exec_cmd("fcitx5 --replace -d --disable classicui")
                hl.exec_cmd("${pkgs.swaybg}/bin/swaybg -o DP-1 -i ${config.home.homeDirectory}/Pictures/wallpapers/Ocean_Spray_-_MacBook_Wallpaper.jpg --mode fill")
                hl.exec_cmd("${pkgs.swaybg}/bin/swaybg -o DP-2 -i ${config.home.homeDirectory}/Pictures/wallpapers/Wallpaper2.jpg --mode fill")
                hl.exec_cmd("hyprctl setcursor ${config.gtk.cursorTheme.name} ${toString config.gtk.cursorTheme.size}")
              end'')
          ];
        }
      ];
    };

    extraConfig = ''
      package.path = package.path .. ";${smwSrc}/lua/?.lua"
      local smw = require("split-monitor-workspaces")
      smw.setup({
        workspace_count = 5,
        enable_persistent_workspaces = false,
        monitor_priority = { "DP-1", "DP-2" },
      })

      for i = 1, smw.get_amount_of_workspaces() do
        local n = tostring(i)
        hl.bind("SUPER + " .. n, smw.workspace(n))
        hl.bind("SUPER + SHIFT + " .. n, smw.move_to_workspace(n))
      end
    '';
  };
}
