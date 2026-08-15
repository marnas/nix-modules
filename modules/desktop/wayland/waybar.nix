{ ... }:
{

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = [
      {
        height = 24;
        modules-left = [ "hyprland/workspaces" ];
        modules-right = [
          "tray"
          "custom/fcitx5"
          "custom/separator"
          "pulseaudio"
          "custom/separator"
          "clock"
        ];
        "hyprland/workspaces" = {
          format = "{icon}";
          disable-scroll = true;
          format-icons = {
            "6" = "1";
            "7" = "2";
            "8" = "3";
            "9" = "4";
            "10" = "5";
            "11" = "1";
            "12" = "2";
            "13" = "3";
            "14" = "4";
            "15" = "5";
          };
        };
        "custom/fcitx5" = {
          # Event-driven: refreshed on demand via SIGRTMIN+8, fired by the
          # input-method toggle keybind (see hyprland/binds.nix). No polling.
          exec = "fcitx5-remote -n | awk '/keyboard/{print \"<b>en</b>\"} /mozc/{print \"<b>あ</b>\"}'";
          signal = 8;
          tooltip = false;
        };
        "custom/separator" = {
          format = "|";
          interval = "once";
          tooltip = "false";
        };
        pulseaudio = {
          format = "{icon} {volume}%";
          format-bluetooth = "{icon} {volume}% {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = "婢";
          format-icons = {
            headphone = "";
            default = [
              ""
              " "
              "  "
            ];
          };
          # on-click = pavucontrol;
          tooltip = false;
        };
        clock = {
          # tooltip-format = "<big>{:%B %Y}</big>\n<tt><small>{calendar}</small></tt>";
          format = "{:%a , %d %b %H:%M}";
          interval = 1;
          tooltip = false;
        };
        tray = {
          icon-size = 18;
          spacing = 7;
          reverse-direction = true;
        };
      }
    ];

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: Helvetica Neue;
      	/* Roboto */
        font-size: 14px;
        min-height: 0;
      }

      window#waybar {
        background: #2d2a2e;
        color: #fcfcfa;
      }

      tooltip {
        background: rgba(43, 48, 59, 0.5);
        border: 1px solid rgba(100, 114, 125, 0.5);
      }

      tooltip label {
        color: white;
      }

      #workspaces button {
        box-shadow: none;
        min-height: 20px;
        border-radius: 0;
        text-shadow: none;
        border: none;
        padding: 1px;
        margin: 0;
        color: #fcfcfa;
      }

      window .modules-left #workspaces button.active:hover,
      window .modules-left #workspaces button.active {
        color: #fcfcfa;
        background-color: #285577;
      }

      window .modules-left #workspaces button:hover  {
        background: rgba(255, 255, 255, 0.00);
        color: #dddddd;
      }

      window .modules-right #pulseaudio,
      window .modules-right #clock{
        border: none;
        padding: 0 0;
        margin: 0 4px;
      }

      window #custom-separator {
        color: #727072;
      }

      window #tray {
        margin: 0 5px;
      }

      window #custom-fcitx5 {
        margin: 0 4px;
        min-width: 18px;
        font-size: 12px;
      }
    '';
  };
}
